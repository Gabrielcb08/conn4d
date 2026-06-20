unit Conn4D.Test.Config;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TConfigTests = class
  public
    [Test] procedure Default_AppliesSpecDefaults;
    [Test] procedure SetExtra_AddsAndUpdates;
    [Test] procedure GetExtra_ReturnsDefaultWhenAbsent;
  end;

implementation

uses
  Conn4D.Core.Config,
  Conn4D.Core;

procedure TConfigTests.Default_AppliesSpecDefaults;
var
  Cfg: IConnConfig;
begin
  Cfg := TConnConfig.New;
  Assert.AreEqual(1, Cfg.Pool.MinSize, 'MinSize');
  Assert.AreEqual(10, Cfg.Pool.MaxSize, 'MaxSize');
  Assert.AreEqual(Cardinal(5000), Cfg.Pool.AcquireTimeout, 'AcquireTimeout');
  Assert.AreEqual(Cardinal(60000), Cfg.Pool.MaxLeaseTime, 'MaxLeaseTime');
  Assert.AreEqual(Cardinal(120000), Cfg.Pool.IdleTimeout, 'IdleTimeout');
  Assert.IsTrue(Cfg.GC.Enabled, 'GC.Enabled');
  Assert.AreEqual(Cardinal(30000), Cfg.GC.Interval, 'GC.Interval');
end;

procedure TConfigTests.SetExtra_AddsAndUpdates;
var
  Cfg: IConnConfig;
begin
  Cfg := TConnConfig.New.Extra('CharacterSet', 'UTF8');
  Assert.AreEqual('UTF8', Cfg.GetExtra('CharacterSet'));
  Cfg := Cfg.Extra('CharacterSet', 'WIN1252');     // last-write-wins
  Assert.AreEqual('WIN1252', Cfg.GetExtra('CharacterSet'));
  Assert.AreEqual(1, Length(Cfg.Extra), 'should update in place, not duplicate');
end;

procedure TConfigTests.GetExtra_ReturnsDefaultWhenAbsent;
var
  Cfg: IConnConfig;
begin
  Cfg := TConnConfig.New;
  Assert.AreEqual('fallback', Cfg.GetExtra('missing', 'fallback'));
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigTests);

end.
