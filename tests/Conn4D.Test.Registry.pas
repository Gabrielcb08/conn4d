unit Conn4D.Test.Registry;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRegistryTests = class
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure RegisterUnregister_TracksCount;
    [Test] procedure NoDuplicateRegistration;
    [Test] procedure ShutdownAll_ShutsEveryManagerAndClears;
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
  Conn4D.Core.Registry,
  Conn4D.Mock.Engine,
  Conn4D.Mock.Clock;

function MakeManagerBase: IConn4DBase;
var
  Eng:  IConnEngine;
  Pool: IConnPool;
  Cfg:  IConnConfig;
begin
  Eng := TMockEngine.Create;
  Cfg := TConnConfig.New;
  Pool := TConn4DCoreFactory.CreateManager(Eng, Cfg, TMockClock.Create(0));
  if not TConn4DCoreFactory.TryGetBase(Pool, Result) then
    Result := nil;
end;

procedure TRegistryTests.Setup;
begin
  // Garante estado limpo entre testes.
  TConn4DRegistry.Instance.ShutdownAll;
end;

procedure TRegistryTests.TearDown;
begin
  TConn4DRegistry.Instance.ShutdownAll;
end;

procedure TRegistryTests.RegisterUnregister_TracksCount;
var
  A, B: IConn4DBase;
begin
  A := MakeManagerBase;
  B := MakeManagerBase;
  Assert.AreEqual(0, TConn4DRegistry.Instance.Count, 'starts empty');

  TConn4DRegistry.Instance.Register(A);
  TConn4DRegistry.Instance.Register(B);
  Assert.AreEqual(2, TConn4DRegistry.Instance.Count, 'two registered');

  TConn4DRegistry.Instance.Unregister(A);
  Assert.AreEqual(1, TConn4DRegistry.Instance.Count, 'one after unregister');
end;

procedure TRegistryTests.NoDuplicateRegistration;
var
  A: IConn4DBase;
begin
  A := MakeManagerBase;
  TConn4DRegistry.Instance.Register(A);
  TConn4DRegistry.Instance.Register(A);  // mesma instância
  Assert.AreEqual(1, TConn4DRegistry.Instance.Count, 'no duplicate');
end;

procedure TRegistryTests.ShutdownAll_ShutsEveryManagerAndClears;
var
  A, B: IConn4DBase;
begin
  A := MakeManagerBase;
  B := MakeManagerBase;
  TConn4DRegistry.Instance.Register(A);
  TConn4DRegistry.Instance.Register(B);

  TConn4DRegistry.Instance.ShutdownAll;

  Assert.AreEqual(0, TConn4DRegistry.Instance.Count, 'registry cleared');
  Assert.AreEqual(Ord(csDestroyed), Ord(A.State), 'A shut down');
  Assert.AreEqual(Ord(csDestroyed), Ord(B.State), 'B shut down');
end;

initialization
  TDUnitX.RegisterTestFixture(TRegistryTests);

end.
