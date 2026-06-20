unit Conn4D.Test.PoolManager;

interface

uses
  DUnitX.TestFramework,
  Conn4D.Core.Engine,
  Conn4D.Core.Pool,
  Conn4D.Mock.Engine;

type
  [TestFixture]
  TPoolManagerTests = class
  private
    FMock:   TMockEngine;   // ponteiro tipado (não-dono)
    FEngine: IConnEngine;   // dono via refcount; mantém FMock vivo
    function Mock: TMockEngine;
    function MakePool(const AMaxSize: Integer): IConnPool;
  public
    [TearDown] procedure TearDown;
    [Test] procedure Acquire_CreatesAndOpensNative;
    [Test] procedure ReturnThenAcquire_ReusesSameNative;
    [Test] procedure Acquire_BeyondMaxSize_TimesOut;
    [Test] procedure Return_ReleasesCapacity;
    [Test] procedure UnhealthyIdle_IsReplacedOnReacquire;
    [Test] procedure OpenFailure_ReleasesPermit;
    [Test] procedure Counts_TrackActiveAndIdle;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Core.Config,
  Conn4D.Core,
  Conn4D.Shared.Exceptions,
  Conn4D.Core.Clock,
  Conn4D.Core.Factory,
  Conn4D.Mock.Clock;

function TPoolManagerTests.Mock: TMockEngine;
begin
  Result := FMock;
end;

function TPoolManagerTests.MakePool(const AMaxSize: Integer): IConnPool;
var
  Cfg:   IConnConfig;
  Clock: IConnClock;
begin
  FMock := TMockEngine.Create;
  FEngine := FMock;
  Clock := TMockClock.Create(0);
  Cfg := TConnConfig.New.MaxSize(AMaxSize);
  Result := TConn4DCoreFactory.CreateManager(FEngine, Cfg, Clock);
end;

procedure TPoolManagerTests.TearDown;
begin
  FEngine := nil;
  FMock   := nil;
end;

procedure TPoolManagerTests.Acquire_CreatesAndOpensNative;
var
  Pool:   IConnPool;
  Native: TObject;
begin
  Pool := MakePool(4);
  Native := Pool.Acquire(1000);
  Assert.IsNotNull(Native, 'native returned');
  Assert.IsTrue(TMockNative(Native).Opened, 'native opened');
  Assert.AreEqual(1, Mock.CreatedCount, 'one created');
  Assert.AreEqual(1, Pool.ActiveCount, 'one active');
end;

procedure TPoolManagerTests.ReturnThenAcquire_ReusesSameNative;
var
  Pool: IConnPool;
  N1, N2: TObject;
begin
  Pool := MakePool(4);
  N1 := Pool.Acquire(1000);
  Pool.ReturnToPool(N1);
  Assert.AreEqual(1, Pool.IdleCount, 'one idle after return');
  N2 := Pool.Acquire(1000);
  Assert.AreSame(N1, N2, 'idle connection reused');
  Assert.AreEqual(1, Mock.CreatedCount, 'no extra created');
end;

procedure TPoolManagerTests.Acquire_BeyondMaxSize_TimesOut;
var
  Pool: IConnPool;
begin
  Pool := MakePool(1);
  Pool.Acquire(1000);  // consome o único permit (não devolve)
  Assert.WillRaise(
    procedure begin Pool.Acquire(100); end,
    EConn4DTimeoutException,
    'second acquire must time out when pool exhausted');
end;

procedure TPoolManagerTests.Return_ReleasesCapacity;
var
  Pool: IConnPool;
  N: TObject;
begin
  Pool := MakePool(1);
  N := Pool.Acquire(1000);
  Pool.ReturnToPool(N);
  Assert.IsNotNull(Pool.Acquire(1000), 'capacity reclaimed after return');
end;

procedure TPoolManagerTests.UnhealthyIdle_IsReplacedOnReacquire;
var
  Pool: IConnPool;
  N1, N2: TObject;
  S1, S2: Integer;
begin
  Pool := MakePool(2);
  N1 := Pool.Acquire(1000);
  S1 := TMockNative(N1).Serial;       // captura ANTES de qualquer free
  TMockNative(N1).Healthy := False;   // apodrece enquanto emprestada
  Pool.ReturnToPool(N1);              // volta como idle, mas doente
  N2 := Pool.Acquire(1000);           // health check deve descartá-la
  S2 := TMockNative(N2).Serial;
  // Identidade por serial (o ponteiro pode ser reciclado pela heap após free).
  Assert.AreNotEqual(S1, S2, 'unhealthy idle replaced by a fresh native');
  Assert.AreEqual(2, Mock.CreatedCount, 'a second native was created');
  Assert.IsTrue(Mock.DestroyedCount >= 1, 'old native destroyed');
end;

procedure TPoolManagerTests.OpenFailure_ReleasesPermit;
var
  Pool: IConnPool;
begin
  Pool := MakePool(1);
  Mock.SetFailOpen(True);
  Assert.WillRaise(
    procedure begin Pool.Acquire(1000); end,
    EConn4DEngineException);
  Mock.SetFailOpen(False);
  Assert.IsNotNull(Pool.Acquire(1000), 'permit released after failed open');
end;

procedure TPoolManagerTests.Counts_TrackActiveAndIdle;
var
  Pool: IConnPool;
  N: TObject;
begin
  Pool := MakePool(4);
  N := Pool.Acquire(1000);
  Assert.AreEqual(1, Pool.ActiveCount, 'active=1');
  Assert.AreEqual(0, Pool.IdleCount, 'idle=0');
  Pool.ReturnToPool(N);
  Assert.AreEqual(0, Pool.ActiveCount, 'active=0 after return');
  Assert.AreEqual(1, Pool.IdleCount, 'idle=1 after return');
end;

initialization
  TDUnitX.RegisterTestFixture(TPoolManagerTests);

end.
