unit Conn4D.Core.Pool;

{
  Conn4D — Core / Abstractions / Pool

  IConnPool: contrato do gerenciador de pool (ver spec §4.3). Implementado pelo
  TConnPoolManager. O GC opera sobre esta interface para evictar idle/zombies.
}

interface

type
  /// <summary>
  /// Gerenciador de pool de conexões nativas. Acquire/ReturnToPool formam o
  /// par de empréstimo; EvictIdle/EvictZombies são acionados pelo GC.
  /// </summary>
  IConnPool = interface
    ['{D1A4F0E1-0000-0000-0000-000000000003}']
    /// <summary>
    /// Empresta uma conexão nativa do pool, criando se necessário e dentro do
    /// MaxSize. Bloqueia até ATimeoutMs; ao estourar lança
    /// EConn4DTimeoutException. Nunca bloqueia indefinidamente.
    /// </summary>
    function Acquire(const ATimeoutMs: Cardinal): TObject;
    /// <summary>Devolve ao pool uma conexão previamente emprestada.</summary>
    procedure ReturnToPool(const ANative: TObject);
    /// <summary>Quantidade de conexões atualmente emprestadas (InUse).</summary>
    function ActiveCount: Integer;
    /// <summary>Quantidade de conexões ociosas disponíveis (Available).</summary>
    function IdleCount: Integer;
    /// <summary>Evicta conexões Available ociosas além de AIdleTimeoutMs.</summary>
    procedure EvictIdle(const AIdleTimeoutMs: Cardinal);
    /// <summary>Mata conexões InUse vazadas além de AMaxLeaseMs (zombies).</summary>
    procedure EvictZombies(const AMaxLeaseMs: Cardinal);
    /// <summary>Encerra e remove todas as conexões do pool.</summary>
    procedure DrainAll;
  end;

implementation

end.
