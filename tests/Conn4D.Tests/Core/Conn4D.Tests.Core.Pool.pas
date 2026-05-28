unit Conn4D.Tests.Core.Pool;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPoolTest = class
  public
    [Test] procedure Acquire_ReturnsConnection;
    [Test] procedure Acquire_ReusesIdleConnection;
    [Test] procedure Acquire_CreatesNew_WhenAllBusy_AndBelowMax;
    [Test] procedure Acquire_Raises_WhenTimeout;
    [Test] procedure Release_MarksSlotAsIdle;
    [Test] procedure Sweep_DestroysIdleConnections;
    [Test] procedure Sweep_DestroysUnhealthyConnections;
    [Test] procedure Pool_IsolatedBetweenInstances;
    [Test] procedure ConcurrentAcquire_IsSafe;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.SyncObjs,
  Conn4D.Domain.Types,
  Conn4D.Domain.PoolConfig,
  Conn4D.Domain.Exceptions,
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Contracts.IPool,
  Conn4D.Application.Pool,
  Conn4D.Tests.Support.Fakes;

function MakeConfig(const AName: string; AMax: Integer = 3;
  ATimeout: Integer = 200): TConn4DPoolConfig;
begin
  Result := Default(TConn4DPoolConfig);
  Result.PoolName       := AName;
  Result.Database       := 'TEST.FDB';
  Result.DriverID       := 'FB';
  Result.MaxPoolSize    := AMax;
  Result.AcquireTimeout := ATimeout;
  Result.IdleTimeout    := 60000;
  Result.SweepInterval  := 60000;
end;

procedure TPoolTest.Acquire_ReturnsConnection;
var
  Provider: TFakeProvider;
  Pool    : IConn4DPool;
  Conn    : IConn4DNativeConnection;
begin
  Provider := TFakeProvider.Create;
  Pool     := TConn4DPool.Create(MakeConfig('p'), Provider);
  Conn     := Pool.Acquire;
  Assert.IsNotNull(Conn);
  Assert.AreEqual(1, Provider.CreateCount);
end;

procedure TPoolTest.Acquire_ReusesIdleConnection;
var
  Provider: TFakeProvider;
  Pool    : IConn4DPool;
  C1, C2  : IConn4DNativeConnection;
begin
  Provider := TFakeProvider.Create;
  Pool     := TConn4DPool.Create(MakeConfig('p'), Provider);
  C1 := Pool.Acquire;
  Pool.Release(C1);
  C2 := Pool.Acquire;
  Assert.AreEqual(1, Provider.CreateCount, 'Should reuse existing slot');
  Assert.AreEqual(Pointer(C1), Pointer(C2));
  Pool.Release(C2);
end;

procedure TPoolTest.Acquire_CreatesNew_WhenAllBusy_AndBelowMax;
var
  Provider   : TFakeProvider;
  Pool       : IConn4DPool;
  C1, C2, C3 : IConn4DNativeConnection;
begin
  Provider := TFakeProvider.Create;
  Pool := TConn4DPool.Create(MakeConfig('p', 3), Provider);
  C1 := Pool.Acquire;
  C2 := Pool.Acquire;
  C3 := Pool.Acquire;
  Assert.AreEqual(3, Provider.CreateCount);
  Pool.Release(C1);
  Pool.Release(C2);
  Pool.Release(C3);
end;

procedure TPoolTest.Acquire_Raises_WhenTimeout;
var
  Provider: TFakeProvider;
  Pool    : IConn4DPool;
  C1      : IConn4DNativeConnection;
begin
  Provider := TFakeProvider.Create;
  Pool := TConn4DPool.Create(MakeConfig('p', 1, 100), Provider); // max=1, timeout=100ms
  C1 := Pool.Acquire;
  Assert.WillRaise(
    procedure begin Pool.Acquire; end,
    EConn4DPoolExhaustedException);
  Pool.Release(C1);
end;

procedure TPoolTest.Release_MarksSlotAsIdle;
var
  Provider: TFakeProvider;
  Pool    : IConn4DPool;
  C1, C2  : IConn4DNativeConnection;
begin
  Provider := TFakeProvider.Create;
  Pool := TConn4DPool.Create(MakeConfig('p', 1, 200), Provider);
  C1 := Pool.Acquire;
  Pool.Release(C1);
  C2 := Pool.Acquire; // must not raise
  Assert.AreEqual(1, Provider.CreateCount);
  Pool.Release(C2);
end;

procedure TPoolTest.Sweep_DestroysIdleConnections;
var
  Provider: TFakeProvider;
  Pool    : IConn4DPool;
  Conn    : IConn4DNativeConnection;
  Cfg     : TConn4DPoolConfig;
  Removed : Integer;
begin
  Provider := TFakeProvider.Create;
  Cfg := MakeConfig('p');
  Cfg.IdleTimeout := 1; // 1 ms — immediately idle
  Pool := TConn4DPool.Create(Cfg, Provider);
  Conn := Pool.Acquire;
  Pool.Release(Conn);
  Conn := nil;
  Sleep(10);
  Removed := Pool.Sweep;
  Assert.IsTrue(Removed >= 1);
  Assert.AreEqual(1, Provider.DestroyCount);
end;

procedure TPoolTest.Sweep_DestroysUnhealthyConnections;
var
  Provider: TFakeProvider;
  Pool    : IConn4DPool;
  Conn    : IConn4DNativeConnection;
  FakeConn: TFakeNativeConnection;
  Removed : Integer;
begin
  Provider := TFakeProvider.Create;
  Pool := TConn4DPool.Create(MakeConfig('p'), Provider);
  Conn := Pool.Acquire;
  FakeConn := TFakeNativeConnection(Conn.NativeObject);
  FakeConn.SetHealthy(False);
  Pool.Release(Conn);
  Conn := nil;
  Removed := Pool.Sweep;
  Assert.IsTrue(Removed >= 1);
end;

procedure TPoolTest.Pool_IsolatedBetweenInstances;
var
  Provider: TFakeProvider;
  PoolA, PoolB: IConn4DPool;
  CA, CB: IConn4DNativeConnection;
begin
  Provider := TFakeProvider.Create;
  PoolA := TConn4DPool.Create(MakeConfig('a', 1), Provider);
  PoolB := TConn4DPool.Create(MakeConfig('b', 1), Provider);
  CA := PoolA.Acquire;
  CB := PoolB.Acquire;
  Assert.AreNotEqual(Pointer(CA), Pointer(CB));
  Assert.AreEqual(2, Provider.CreateCount);
  PoolA.Release(CA);
  PoolB.Release(CB);
end;

procedure TPoolTest.ConcurrentAcquire_IsSafe;
const
  N = 5;
var
  Provider : TFakeProvider;
  Pool     : IConn4DPool;
  Errors   : Integer;
  Done     : TCountdownEvent;
  I        : Integer;
begin
  Provider := TFakeProvider.Create;
  Pool     := TConn4DPool.Create(MakeConfig('p', N, 5000), Provider);
  Errors   := 0;
  Done     := TCountdownEvent.Create(N);
  try
    for I := 1 to N do
    begin
      TThread.CreateAnonymousThread(
        procedure
        var Conn: IConn4DNativeConnection;
        begin
          try
            Conn := Pool.Acquire;
            Sleep(10);
            Pool.Release(Conn);
          except
            TInterlocked.Increment(Errors);
          end;
          Done.Signal;
        end).Start;
    end;
    Done.WaitFor(10000);
  finally
    Done.Free;
  end;
  Assert.AreEqual(0, Errors);
end;

initialization
  TDUnitX.RegisterTestFixture(TPoolTest);

end.
