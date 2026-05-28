unit Conn4D.Tests.Core.Handle;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  THandleTest = class
  public
    [Test] procedure Connection_Generic_ReturnsNativeObject;
    [Test] procedure Connection_Generic_Raises_WhenTypeMismatch;
    [Test] procedure Handle_ReleasesPool_WhenLastCopyOutOfScope;
    [Test] procedure Handle_BeginTransaction_ReturnsActiveTransaction;
    [Test] procedure Handle_IsValid_False_WhenUninitialized;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Domain.PoolConfig,
  Conn4D.Domain.Exceptions,
  Conn4D.Domain.Types,
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Contracts.IPool,
  Conn4D.Application.Pool,
  Conn4D.Application.Handle,
  Conn4D.Application.Transaction,
  Conn4D.Tests.Support.Fakes;

function MakeConfig: TConn4DPoolConfig;
begin
  Result := Default(TConn4DPoolConfig);
  Result.PoolName       := 'test';
  Result.Database       := 'TEST.FDB';
  Result.DriverID       := 'FB';
  Result.MaxPoolSize    := 3;
  Result.AcquireTimeout := 500;
  Result.IdleTimeout    := 60000;
  Result.SweepInterval  := 60000;
end;

procedure THandleTest.Connection_Generic_ReturnsNativeObject;
var
  Provider : TFakeProvider;
  Pool     : IConn4DPool;
  Conn     : IConn4DNativeConnection;
  Guard    : IConn4DLeaseGuard;
  Handle   : TConn4DHandle;
  FakeConn : TFakeNativeConnection;
begin
  Provider := TFakeProvider.Create;
  Pool     := TConn4DPool.Create(MakeConfig, Provider);
  Conn     := Pool.Acquire;
  Guard    := TConn4DLeaseGuardImpl.Create(Pool, Conn);
  Handle   := TConn4DHandle._Create(Guard);

  FakeConn := Handle.Connection<TFakeNativeConnection>;
  Assert.IsNotNull(FakeConn);
  Assert.IsTrue(FakeConn is TFakeNativeConnection);
end;

procedure THandleTest.Connection_Generic_Raises_WhenTypeMismatch;
var
  Provider : TFakeProvider;
  Pool     : IConn4DPool;
  Conn     : IConn4DNativeConnection;
  Guard    : IConn4DLeaseGuard;
  Handle   : TConn4DHandle;
begin
  Provider := TFakeProvider.Create;
  Pool     := TConn4DPool.Create(MakeConfig, Provider);
  Conn     := Pool.Acquire;
  Guard    := TConn4DLeaseGuardImpl.Create(Pool, Conn);
  Handle   := TConn4DHandle._Create(Guard);

  // TObject is not TFakeNativeTransaction — runtime cast must raise
  Assert.WillRaise(
    procedure begin Handle.Connection<TFakeNativeTransaction>; end,
    EConn4DCastException);
end;

procedure THandleTest.Handle_ReleasesPool_WhenLastCopyOutOfScope;
var
  Provider : TFakeProvider;
  Pool     : IConn4DPool;
begin
  Provider := TFakeProvider.Create;
  Pool     := TConn4DPool.Create(MakeConfig, Provider);

  begin
    var Conn  := Pool.Acquire;
    var Guard := TConn4DLeaseGuardImpl.Create(Pool, Conn);
    var H     := TConn4DHandle._Create(Guard);
    Guard := nil;
    // When this block ends, H goes out of scope → guard refcount → 0 → Pool.Release fires
  end;

  // After release, we should be able to acquire again (slot is idle)
  var Conn2 := Pool.Acquire;
  Assert.AreEqual(1, Provider.CreateCount, 'No new connection should be created');
  Pool.Release(Conn2);
end;

procedure THandleTest.Handle_BeginTransaction_ReturnsActiveTransaction;
var
  Provider: TFakeProvider;
  Pool    : IConn4DPool;
  Conn    : IConn4DNativeConnection;
  Guard   : IConn4DLeaseGuard;
  Handle  : TConn4DHandle;
  Tx      : TConn4DTransaction;
begin
  Provider := TFakeProvider.Create;
  Pool     := TConn4DPool.Create(MakeConfig, Provider);
  Conn     := Pool.Acquire;
  Guard    := TConn4DLeaseGuardImpl.Create(Pool, Conn);
  Handle   := TConn4DHandle._Create(Guard);

  Tx := Handle.BeginTransaction;
  Assert.IsTrue(Tx.IsActive);
  Tx.Rollback;
end;

procedure THandleTest.Handle_IsValid_False_WhenUninitialized;
var
  H: TConn4DHandle;
begin
  H := Default(TConn4DHandle);
  Assert.IsFalse(H.IsValid);
end;

initialization
  TDUnitX.RegisterTestFixture(THandleTest);

end.
