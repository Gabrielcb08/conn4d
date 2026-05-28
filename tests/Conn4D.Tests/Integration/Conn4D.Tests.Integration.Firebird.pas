unit Conn4D.Tests.Integration.Firebird;

// Integration tests — skipped when CONN4D_FIREBIRD_DATABASE is unset.

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TFirebirdIntegrationTest = class
  private
    function EnvVar(const AName: string): string;
    function CanRunIntegration: Boolean;
  public
    [Test] procedure Acquire_ConnectsToRealFirebird;
    [Test] procedure Transaction_CommitAndRollback;
    [Test] procedure Pool_ReusesConnection;
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  Conn4D,
  Conn4D.Application.PoolRegistry,
  Conn4D.Infrastructure.FireDAC.Provider;

function TFirebirdIntegrationTest.EnvVar(const AName: string): string;
begin
  Result := GetEnvironmentVariable(AName);
end;

function TFirebirdIntegrationTest.CanRunIntegration: Boolean;
begin
  Result := EnvVar('CONN4D_FIREBIRD_DATABASE') <> '';
end;

procedure TFirebirdIntegrationTest.Acquire_ConnectsToRealFirebird;
var
  Handle: TConn4DHandle;
  Conn  : TFDConnection;
begin
  if not CanRunIntegration then
  begin
    Assert.Pass('CONN4D_FIREBIRD_DATABASE not set — skipping');
    Exit;
  end;

  TConn4DPoolRegistry.Instance.Clear;
  TConn4DPoolRegistry.Instance.RegisterProvider(TConn4DFireDACProvider.Create);
  TConn4D.Configure
    .Pool('fb-test')
      .Host(EnvVar('CONN4D_FIREBIRD_HOST'))
      .Database(EnvVar('CONN4D_FIREBIRD_DATABASE'))
      .UserName(EnvVar('CONN4D_FIREBIRD_USER'))
      .Password(EnvVar('CONN4D_FIREBIRD_PASSWORD'))
      .AddParam('Protocol', 'TCPIP')
    .Apply;

  Handle := TConn4D.Acquire('fb-test');
  Conn   := Handle.Connection<TFDConnection>;
  Assert.IsTrue(Conn.Connected);
end;

procedure TFirebirdIntegrationTest.Transaction_CommitAndRollback;
var
  Handle: TConn4DHandle;
  Tx    : TConn4DTransaction;
begin
  if not CanRunIntegration then
  begin
    Assert.Pass('CONN4D_FIREBIRD_DATABASE not set — skipping');
    Exit;
  end;

  Handle := TConn4D.Acquire('fb-test');
  Tx     := Handle.BeginTransaction;
  Assert.IsTrue(Tx.IsActive);

  Tx.Rollback;
  Assert.IsFalse(Tx.IsActive);
end;

procedure TFirebirdIntegrationTest.Pool_ReusesConnection;
var
  H1, H2 : TConn4DHandle;
  C1, C2  : TFDConnection;
begin
  if not CanRunIntegration then
  begin
    Assert.Pass('CONN4D_FIREBIRD_DATABASE not set — skipping');
    Exit;
  end;

  H1 := TConn4D.Acquire('fb-test');
  C1 := H1.Connection<TFDConnection>;
  H1 := Default(TConn4DHandle); // release — returns to pool

  H2 := TConn4D.Acquire('fb-test');
  C2 := H2.Connection<TFDConnection>;
  Assert.AreEqual(Pointer(C1), Pointer(C2), 'Same physical connection must be reused');
end;

initialization
  TDUnitX.RegisterTestFixture(TFirebirdIntegrationTest);
  // Ensure clean registry state at test startup.
  TConn4DPoolRegistry.Instance.Clear;

end.
