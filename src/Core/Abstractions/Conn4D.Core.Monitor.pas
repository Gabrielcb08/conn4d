unit Conn4D.Core.Monitor;

{
  Conn4D — Core / Abstractions / Monitor

  IConnMonitor: contrato focado (ISP) para inspeção somente-leitura do pool —
  usado por ferramentas de monitoramento e pelo componente de paleta para
  mostrar "quais conexões existem e há quanto tempo estão abertas". Não muta
  estado e é agnóstico de engine (devolve TConnLeaseInfo, em Shared).
}

interface

uses
  Conn4D.Shared.Types;

type
  IConnMonitor = interface
    ['{D1A4F0E1-0000-0000-0000-00000000000A}']
    /// <summary>Instantâneo das conexões vivas com suas idades.</summary>
    function LiveConnections: TArray<TConnLeaseInfo>;
  end;

implementation

end.
