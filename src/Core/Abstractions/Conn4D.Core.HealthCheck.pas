unit Conn4D.Core.HealthCheck;

{
  Conn4D — Core / Abstractions / HealthCheck

  IConnHealthCheck: contrato focado (ISP) para avaliar a saúde de uma conexão
  nativa antes de entregá-la ao consumidor (ver spec §4.5).
}

interface

type
  /// <summary>Verifica se uma conexão nativa está saudável e utilizável.</summary>
  IConnHealthCheck = interface
    ['{D1A4F0E1-0000-0000-0000-000000000005}']
    function IsHealthy(const ANative: TObject): Boolean;
  end;

implementation

end.
