unit Conn4D.Core.GC;

{
  Conn4D — Core / Abstractions / GC

  IConnGC: contrato do garbage collector de conexões (ver spec §4.5). RunOnce
  permite execução síncrona de um ciclo para testes determinísticos.
}

interface

uses
  Conn4D.Core.Pool;

type
  /// <summary>
  /// Coletor de conexões idle/zombie. Roda em thread própria entre Start/Stop;
  /// RunOnce executa um único ciclo sincronamente (usado em testes com relógio
  /// mockado). Gerencia o conjunto de pools registrados.
  /// </summary>
  IConnGC = interface
    ['{D1A4F0E1-0000-0000-0000-000000000006}']
    /// <summary>Inicia a thread de coleta periódica.</summary>
    procedure Start;
    /// <summary>Para a thread de coleta e aguarda seu término.</summary>
    procedure Stop;
    /// <summary>Executa um ciclo de coleta sincronamente (determinístico).</summary>
    procedure RunOnce;
    /// <summary>Passa um pool a ser coletado.</summary>
    procedure Register(const APool: IConnPool);
    /// <summary>Remove um pool da coleta.</summary>
    procedure Unregister(const APool: IConnPool);
  end;

implementation

end.
