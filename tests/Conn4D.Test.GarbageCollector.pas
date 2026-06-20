unit Conn4D.Test.GarbageCollector;

interface

uses
  DUnitX.TestFramework,
  Conn4D.Core.Engine,
  Conn4D.Core.Clock,
  Conn4D.Shared.Logger,
  Conn4D.Core.Pool,
  Conn4D.Core.GC,
  Conn4D.Mock.Engine,
  Conn4D.Mock.Clock,
  Conn4D.Mock.Logger;

type
  [TestFixture]
  TGarbageCollectorTests = class
  private
    FMock:    TMockEngine;
    FEngine:  IConnEngine;
    FClock:   TMockClock;
    FClockI:  IConnClock;
    FLogObj:  TMockLogger;
    FLogI:    IConnLogger;
    FPool:    IConnPool;
    FGC:      IConnGC;
    procedure Build(const AMaxSize: Integer; const AIdleTimeoutMs, AMaxLeaseMs: Cardinal);
  public
    [TearDown] procedure TearDown;
    [Test] procedure RunOnce_EvictsIdleAfterTimeout;
    [Test] procedure RunOnce_KeepsIdleBeforeTimeout;
    [Test] procedure RunOnce_KillsZombieAfterMaxLease;
    [Test] procedure RunOnce_ReclaimsZombieCapacity;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Shared.Config,
  Conn4D.Core.Config,
  Conn4D.Core,
  Conn4D.Shared.Exceptions,
  Conn4D.Core.Factory,
  Conn4D.Core.GarbageCollector;

procedure TGarbageCollectorTests.Build(const AMaxSize: Integer;
  const AIdleTimeoutMs, AMaxLeaseMs: Cardinal);
var
  Cfg: IConnConfig;
  GCCfg: TConnGCConfig;
begin
  FMock   := TMockEngine.Create;
  FEngine := FMock;
  FClock  := TMockClock.Create(0);
  FClockI := FClock;
  FLogObj := TMockLogger.Create;
  FLogI   := FLogObj;

  Cfg := TConnConfig.New.MaxSize(AMaxSize);
  FPool := TConn4DCoreFactory.CreateManager(FEngine, Cfg, FClockI, FLogI);

  GCCfg := Cfg.GC;
  FGC := TConnGarbageCollector.New(GCCfg, AIdleTimeoutMs, AMaxLeaseMs, FClockI, FLogI);
  FGC.Register(FPool);
end;

procedure TGarbageCollectorTests.TearDown;
begin
  FGC := nil;
  FPool := nil;
  FEngine := nil; FMock := nil;
  FClockI := nil; FClock := nil;
  FLogI := nil; FLogObj := nil;
end;

procedure TGarbageCollectorTests.RunOnce_EvictsIdleAfterTimeout;
var
  N: TObject;
begin
  Build(4, {idle}1000, {lease}60000);
  N := FPool.Acquire(1000);
  FPool.ReturnToPool(N);              // vira idle em t=0
  Assert.AreEqual(1, FPool.IdleCount, 'idle present before GC');

  FClock.Advance(1500);               // passa do idleTimeout
  FGC.RunOnce;

  Assert.AreEqual(0, FPool.IdleCount, 'idle evicted after timeout');
  Assert.IsTrue(FMock.DestroyedCount >= 1, 'native destroyed');
end;

procedure TGarbageCollectorTests.RunOnce_KeepsIdleBeforeTimeout;
var
  N: TObject;
begin
  Build(4, {idle}5000, {lease}60000);
  N := FPool.Acquire(1000);
  FPool.ReturnToPool(N);

  FClock.Advance(1000);               // ainda dentro do idleTimeout
  FGC.RunOnce;

  Assert.AreEqual(1, FPool.IdleCount, 'idle kept before timeout');
  Assert.AreEqual(0, FMock.DestroyedCount, 'nothing destroyed');
end;

procedure TGarbageCollectorTests.RunOnce_KillsZombieAfterMaxLease;
begin
  Build(4, {idle}120000, {lease}1000);
  FPool.Acquire(1000);                // emprestada e NUNCA devolvida (vazamento)
  Assert.AreEqual(1, FPool.ActiveCount, 'active before GC');

  FClock.Advance(1500);               // passa do maxLease
  FGC.RunOnce;

  Assert.AreEqual(0, FPool.ActiveCount, 'zombie killed after maxLease');
  Assert.IsTrue(FMock.DestroyedCount >= 1, 'zombie native destroyed');
  Assert.IsTrue(FLogObj.Contains('Zombie'), 'zombie reclaim logged');
end;

procedure TGarbageCollectorTests.RunOnce_ReclaimsZombieCapacity;
begin
  Build(1, {idle}120000, {lease}1000);
  FPool.Acquire(1000);                // ocupa o único permit e vaza
  FClock.Advance(2000);
  FGC.RunOnce;                        // mata o zombie e devolve o permit
  // Capacidade recuperada: novo acquire não deve dar timeout.
  Assert.IsNotNull(FPool.Acquire(1000), 'capacity reclaimed after zombie kill');
end;

initialization
  TDUnitX.RegisterTestFixture(TGarbageCollectorTests);

end.
