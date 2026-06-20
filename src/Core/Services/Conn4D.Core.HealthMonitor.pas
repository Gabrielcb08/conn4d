unit Conn4D.Core.HealthMonitor;

{
  Conn4D — Core / Services / HealthMonitor

  TConnHealthMonitor: implementa IConnHealthCheck delegando ao Ping do engine.
  Mantido separado do pool (SRP/ISP): o pool decide QUANDO checar; o monitor
  sabe COMO checar, sem conhecer o driver — só o contrato IConnEngine.
}

interface

uses
  Conn4D.Core.HealthCheck,
  Conn4D.Core.Engine;

type
  TConnHealthMonitor = class(TInterfacedObject, IConnHealthCheck)
  private
    FEngine: IConnEngine;
  public
    constructor Create(const AEngine: IConnEngine);
    function IsHealthy(const ANative: TObject): Boolean;
    class function New(const AEngine: IConnEngine): IConnHealthCheck; static;
  end;

implementation

{ TConnHealthMonitor }

class function TConnHealthMonitor.New(const AEngine: IConnEngine): IConnHealthCheck;
begin
  Result := TConnHealthMonitor.Create(AEngine);
end;

constructor TConnHealthMonitor.Create(const AEngine: IConnEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

function TConnHealthMonitor.IsHealthy(const ANative: TObject): Boolean;
begin
  if (FEngine = nil) or (ANative = nil) then
    Exit(False);
  try
    Result := FEngine.Ping(ANative);
  except
    Result := False;  // qualquer exceção do driver = conexão não saudável
  end;
end;

end.
