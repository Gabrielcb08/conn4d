unit Conn4D.Test.EngineSwap;

{
  Prova de LSP (spec §11, §14): a MESMA suíte de comportamento do Core passa com
  dois engines diferentes (aqui, dois TMockEngine com EngineIDs distintos). O
  pool opera sobre IConnEngine sem saber a implementação — trocar o engine não
  altera o comportamento observável.
}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEngineSwapTests = class
  private
    procedure RunCoreContract(const AEngineID: string);
  public
    [Test] procedure CoreContract_HoldsForEngineA;
    [Test] procedure CoreContract_HoldsForEngineB;
    [Test] procedure EngineId_FlowsThroughToStats;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Core.Config,
  Conn4D.Core,
  Conn4D.Shared.Types,
  Conn4D.Core.Engine,
  Conn4D.Core.Pool,
  Conn4D.Core.Base,
  Conn4D.Core.Factory,
  Conn4D.Mock.Engine,
  Conn4D.Mock.Clock;

procedure TEngineSwapTests.RunCoreContract(const AEngineID: string);
var
  Mock:   TMockEngine;
  Engine: IConnEngine;
  Pool:   IConnPool;
  Cfg:    IConnConfig;
  N1, N2: TObject;
begin
  Mock := TMockEngine.Create(AEngineID);
  Engine := Mock;
  Cfg := TConnConfig.New.MaxSize(2);
  Pool := TConn4DCoreFactory.CreateManager(Engine, Cfg, TMockClock.Create(0));

  // Mesmo contrato, independente do engine:
  N1 := Pool.Acquire(1000);
  Assert.AreEqual(1, Pool.ActiveCount, AEngineID + ': active=1');
  Pool.ReturnToPool(N1);
  Assert.AreEqual(1, Pool.IdleCount, AEngineID + ': idle=1');
  N2 := Pool.Acquire(1000);
  Assert.AreSame(N1, N2, AEngineID + ': reuse idle');
  Pool.ReturnToPool(N2);
  Assert.AreEqual(1, Mock.CreatedCount, AEngineID + ': single physical conn created');
end;

procedure TEngineSwapTests.CoreContract_HoldsForEngineA;
begin
  RunCoreContract('mock-A');
end;

procedure TEngineSwapTests.CoreContract_HoldsForEngineB;
begin
  RunCoreContract('mock-B');
end;

procedure TEngineSwapTests.EngineId_FlowsThroughToStats;
var
  Mock:   TMockEngine;
  Engine: IConnEngine;
  Pool:   IConnPool;
  Base:   IConn4DBase;
  Cfg:    IConnConfig;
begin
  Mock := TMockEngine.Create('weirdsql');
  Engine := Mock;
  Cfg := TConnConfig.New;
  Pool := TConn4DCoreFactory.CreateManager(Engine, Cfg, TMockClock.Create(0));
  Assert.IsTrue(TConn4DCoreFactory.TryGetBase(Pool, Base), 'base recoverable');
  Assert.AreEqual('weirdsql', Base.Stats.EngineID, 'engine id flows into stats');
  Assert.AreEqual('weirdsql', Base.EngineID, 'engine id on base');
end;

initialization
  TDUnitX.RegisterTestFixture(TEngineSwapTests);

end.
