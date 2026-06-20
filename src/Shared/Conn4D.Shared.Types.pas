unit Conn4D.Shared.Types;

{
  Conn4D — Shared / Types

  Tipos transversais usados por todas as camadas. Esta unit NÃO depende de
  nenhuma camada do projeto e jamais referencia um engine concreto.

  Contém:
    - TConnState        estados do ciclo de vida de uma conexão
    - TConnIsolation    níveis de isolamento de transação (agnóstico de driver)
    - TConnPoolStats    instantâneo numérico do pool
    - TConnResult<T>    resultado encapsulado (sucesso/erro) sem exceção
}

interface

type
  /// <summary>
  /// Estados do ciclo de vida de uma conexão gerenciada (ver spec §6).
  /// Created -> Available -> InUse -> Available; ramos Idle/Zombie levam a
  /// Destroyed via garbage collector.
  /// </summary>
  TConnState = (
    csCreated,    // manager criado, conexão física ainda não aberta (lazy)
    csAvailable,  // aberta e ociosa no pool, pronta para Acquire
    csInUse,      // emprestada a uma thread
    csIdle,       // Available além de IdleTimeout — candidata a evicção
    csZombie,     // InUse além de MaxLeaseTime — vazamento, candidata a kill
    csDestroyed   // encerrada definitivamente
  );

  /// <summary>
  /// Nível de isolamento de transação, agnóstico de engine. Cada engine mapeia
  /// estes valores para os do seu driver dentro do respectivo adapter.
  /// </summary>
  TConnIsolation = (
    ciReadUncommitted,
    ciReadCommitted,
    ciRepeatableRead,
    ciSerializable,
    ciSnapshot
  );

  /// <summary>
  /// Instantâneo numérico do estado de um pool. Apenas dados — sem comportamento.
  /// </summary>
  TConnPoolStats = record
    EngineID:     string;   // engine dono do pool ('firedac' | 'zeos' | ...)
    Active:       Integer;  // conexões atualmente InUse
    Idle:         Integer;  // conexões Available no momento
    Total:        Integer;  // Active + Idle (conexões físicas existentes)
    MaxSize:      Integer;  // teto configurado do pool
    Waiting:      Integer;  // threads enfileiradas aguardando conexão
    CreatedTotal: Int64;    // total histórico de conexões criadas
    EvictedTotal: Int64;    // total histórico evictado (idle + zombie)
  end;

  /// <summary>
  /// Projeção somente-leitura de uma conexão do pool, para monitoramento
  /// (ver conn4d-packaging-spec §4). Idades calculadas a partir do IConnClock
  /// injetado no manager. Apenas dados, agnóstico de engine.
  /// </summary>
  TConnLeaseInfo = record
    Id:               TGUID;
    EngineID:         string;
    State:            TConnState;
    OwnerThreadId:    NativeUInt;
    CreatedAtMs:      Int64;
    AcquiredAtMs:     Int64;
    LastReleasedAtMs: Int64;
    AgeMs:            Int64;   // Now - CreatedAt (tempo de vida total)
    InUseForMs:       Int64;   // se InUse: Now - AcquiredAt; senão 0
    IdleForMs:        Int64;   // se Available: Now - LastReleasedAt; senão 0
  end;

  /// <summary>
  /// Resultado encapsulado de uma operação que pode falhar de forma esperada,
  /// sem recorrer a exceção (ver spec §10). Use Ok/Fail para construir e
  /// IsSuccess/Value/ErrorMessage para consumir.
  /// </summary>
  TConnResult<T> = record
  private
    FSuccess: Boolean;
    FValue:   T;
    FError:   string;
  public
    class function Ok(const AValue: T): TConnResult<T>; static; inline;
    class function Fail(const AError: string): TConnResult<T>; static; inline;

    function IsSuccess: Boolean; inline;
    function IsFailure: Boolean; inline;
    /// <summary>Valor produzido. Indefinido quando IsFailure.</summary>
    function Value: T; inline;
    /// <summary>Descrição do erro. Vazia quando IsSuccess.</summary>
    function ErrorMessage: string; inline;
    /// <summary>Retorna Value se sucesso, senão ADefault.</summary>
    function ValueOr(const ADefault: T): T; inline;
  end;

implementation

{ TConnResult<T> }

class function TConnResult<T>.Ok(const AValue: T): TConnResult<T>;
begin
  Result.FSuccess := True;
  Result.FValue   := AValue;
  Result.FError   := '';
end;

class function TConnResult<T>.Fail(const AError: string): TConnResult<T>;
begin
  Result.FSuccess := False;
  Result.FValue   := Default(T);
  Result.FError   := AError;
end;

function TConnResult<T>.IsSuccess: Boolean;
begin
  Result := FSuccess;
end;

function TConnResult<T>.IsFailure: Boolean;
begin
  Result := not FSuccess;
end;

function TConnResult<T>.Value: T;
begin
  Result := FValue;
end;

function TConnResult<T>.ErrorMessage: string;
begin
  Result := FError;
end;

function TConnResult<T>.ValueOr(const ADefault: T): T;
begin
  if FSuccess then
    Result := FValue
  else
    Result := ADefault;
end;

end.
