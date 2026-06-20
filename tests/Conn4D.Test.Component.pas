unit Conn4D.Test.Component;

{
  Valida o contrato público TConn4D.Acquire: sem engine → FireDAC por default.
  Só checa EngineID (não abre conexão), então não precisa de banco real.
}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TComponentTests = class
  public
    [Test] procedure Acquire_NoEngine_DefaultsToFireDAC;
    [Test] procedure Acquire_ExplicitFireDAC;
    [Test] procedure Acquire_ReturnsFluentAgnostic;
    [Test] procedure ConfigureBuilder_EndConfig_ReturnsFacade;
  end;

implementation

uses
  Conn4D;   // fachada: TConn4D, IConn4D, IConnConfig, TConnConfig, enFireDAC

procedure TComponentTests.Acquire_NoEngine_DefaultsToFireDAC;
var
  C: IConn4D;
begin
  C := TConn4D.Acquire;                       // sem engine
  Assert.AreEqual('firedac', C.EngineID, 'default engine deve ser FireDAC');
end;

procedure TComponentTests.Acquire_ExplicitFireDAC;
var
  C: IConn4D;
begin
  C := TConn4D.Acquire(enFireDAC);
  Assert.AreEqual('firedac', C.EngineID);
end;

procedure TComponentTests.Acquire_ReturnsFluentAgnostic;
var
  C: IConn4D;
begin
  // Config fluente no TConnConfig; a fachada recebe pronta via Configure.
  C := TConn4D.Acquire.Configure(
    TConnConfig.New.Provider('Firebird').Host('localhost').Port(3050));
  Assert.IsNotNull(C, 'Configure devolve IConn4D');
  Assert.AreEqual('firedac', C.EngineID);
end;

procedure TComponentTests.ConfigureBuilder_EndConfig_ReturnsFacade;
var
  C, Back: IConn4D;
begin
  // Builder vinculado sem parâmetro: encadeia config e EndConfig volta ao IConn4D.
  C := TConn4D.Acquire;
  Back := C.Configure.Provider('Firebird').Port(3050).EndConfig;
  Assert.IsNotNull(Back, 'EndConfig deve devolver o IConn4D');
  Assert.AreEqual('firedac', Back.EngineID, 'mesma fachada (FireDAC)');
end;

initialization
  TDUnitX.RegisterTestFixture(TComponentTests);

end.
