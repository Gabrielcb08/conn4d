unit Conn4D.Core.Base;

{
  Conn4D — Core / Abstractions / Base

  IConn4DBase: a parte engine-agnóstica de todo manager de conexão. É o
  contrato que o registry global guarda e que o GC manipula sem jamais saber
  qual engine está por baixo (ver spec §4.1).
}

interface

uses
  Conn4D.Shared.Types;

type
  /// <summary>
  /// Contrato base, agnóstico de engine, de um manager de conexão. Tudo que o
  /// TConn4DRegistry e o garbage collector precisam manipular vive aqui.
  /// </summary>
  IConn4DBase = interface
    ['{D1A4F0E1-0000-0000-0000-000000000001}']
    /// <summary>Identidade estável deste manager.</summary>
    function Id: TGUID;
    /// <summary>Engine dono ('firedac' | 'zeos' | 'unidac').</summary>
    function EngineID: string;
    /// <summary>Instantâneo numérico do pool deste manager.</summary>
    function Stats: TConnPoolStats;
    /// <summary>Estado agregado atual.</summary>
    function State: TConnState;
    /// <summary>Devolve a(s) conexão(ões) ao pool / encerra o empréstimo.</summary>
    procedure Release;
    /// <summary>Encerra definitivamente este manager e suas conexões.</summary>
    procedure Shutdown;
  end;

implementation

end.
