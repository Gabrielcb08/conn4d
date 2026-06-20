unit Conn4D.Core.Engine;

{
  Conn4D — Core / Abstractions / Engine

  IConnEngine: a Strategy do driver (ver spec §4.2). É o ponto de extensão que
  torna o engine substituível. Toda operação trabalha sobre TObject para NUNCA
  vazar um tipo concreto (TFDCustomConnection, TZConnection, ...) ao Core. O
  cast de TObject para o tipo nativo acontece só dentro do adapter do engine.
}

interface

uses
  Conn4D.Shared.Types,
  Conn4D.Core;

type
  /// <summary>
  /// Contrato do driver de banco. Cada engine (FireDAC, Zeos, UniDAC) o
  /// implementa em sua própria unit de adapter. O Core só conhece esta
  /// interface — trocar de engine é trocar a implementação registrada.
  /// </summary>
  IConnEngine = interface
    ['{D1A4F0E1-0000-0000-0000-000000000002}']
    /// <summary>Identificador único e estável do engine (usado em logs/registry).</summary>
    function EngineID: string;
    /// <summary>Cria a conexão nativa configurada, ainda fechada.</summary>
    function CreateNative(const ACfg: IConnConfig): TObject;
    /// <summary>Abre fisicamente a conexão nativa.</summary>
    procedure OpenNative(const ANative: TObject);
    /// <summary>Fecha a conexão nativa, mantendo o objeto.</summary>
    procedure CloseNative(const ANative: TObject);
    /// <summary>Destrói o objeto nativo, liberando recursos do driver.</summary>
    procedure DestroyNative(const ANative: TObject);
    /// <summary>Verifica vivacidade da conexão (health check leve).</summary>
    function Ping(const ANative: TObject): Boolean;
    /// <summary>Inicia transação no nível de isolamento dado.</summary>
    procedure BeginTx(const ANative: TObject; const AIsolation: TConnIsolation);
    /// <summary>Confirma a transação corrente.</summary>
    procedure CommitTx(const ANative: TObject);
    /// <summary>Desfaz a transação corrente.</summary>
    procedure RollbackTx(const ANative: TObject);
    /// <summary>Indica se há transação aberta na conexão nativa.</summary>
    function InTx(const ANative: TObject): Boolean;
  end;

implementation

end.
