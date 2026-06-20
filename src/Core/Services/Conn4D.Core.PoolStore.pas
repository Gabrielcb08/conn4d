unit Conn4D.Core.PoolStore;

{
  Conn4D — Core / Services / PoolStore

  TConnPoolStore: ÚNICO ponto de mutação do estado do pool (ver spec §7.1 e
  references/threading-rules.md). Mantém a lista de conexões Available e o mapa
  de conexões InUse, ambos protegidos por TCriticalSection encapsulada — nada
  fora desta classe altera as listas diretamente.

  O store NÃO conhece o engine: trabalha sobre TObject (a conexão nativa) e
  sobre TConnEntry (metadados de ciclo de vida). Criar/abrir/destruir o objeto
  nativo é responsabilidade do manager/GC, que detêm o IConnEngine; o store só
  rastreia. Toda lógica de tempo recebe ANowMs de fora (IConnClock injetado no
  chamador), nunca chama Now diretamente.

  Concorrência: cada método é autossincronizado. O semáforo do manager (lock
  mais externo da ordem fixa) é sempre adquirido ANTES de qualquer chamada aqui,
  e o lock deste store nunca é aninhado com o do ThreadContext — logo não há
  ciclo de espera possível.
}

interface

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Shared.Types;

type
  /// <summary>Metadados de ciclo de vida de uma conexão. Propriedade do store.</summary>
  TConnEntry = class
  public
    Native:           TObject;     // conexão nativa (não destruída pelo store)
    Id:               TGUID;
    EngineID:         string;
    State:            TConnState;
    CreatedAtMs:      Int64;
    AcquiredAtMs:     Int64;       // válido quando InUse
    LastReleasedAtMs: Int64;       // válido quando Available
    OwnerThreadId:    TThreadID;   // quem segura, quando InUse
  end;

  /// <summary>
  /// Cópia imutável dos campos de uma entry, para o GC avaliar idle/zombie
  /// SEM segurar lock e sem risco de a entry ser liberada sob seus pés.
  /// </summary>
  TConnSnapshotItem = record
    Native:           TObject;
    Id:               TGUID;
    State:            TConnState;
    AcquiredAtMs:     Int64;
    LastReleasedAtMs: Int64;
    OwnerThreadId:    TThreadID;
  end;

  TConnPoolStore = class
  private
    FLock:         TCriticalSection;
    FEngineID:     string;
    FMaxSize:      Integer;
    FAvailable:    TQueue<TConnEntry>;             // FIFO de ociosas
    FInUse:        TDictionary<TObject, TConnEntry>;
    FAll:          TObjectList<TConnEntry>;        // dono de todas as entries
    FCreatedTotal: Int64;
    FEvictedTotal: Int64;
    function RemoveEntryNoLock(const ANative: TObject): Boolean;
  public
    constructor Create(const AEngineID: string; const AMaxSize: Integer);
    destructor Destroy; override;

    /// <summary>
    /// Tenta retirar uma conexão Available e marcá-la InUse para a thread dada.
    /// Retorna False se não há ociosa (o manager então cria uma nova).
    /// </summary>
    function TryTakeAvailable(const ANowMs: Int64; const AThreadId: TThreadID;
      out ANative: TObject): Boolean;

    /// <summary>
    /// Registra uma conexão recém-criada já como InUse (o manager acabou de
    /// abri-la para o chamador corrente). Devolve a entry criada.
    /// </summary>
    function RegisterInUse(const ANative: TObject; const AId: TGUID;
      const ANowMs: Int64; const AThreadId: TThreadID): TConnEntry;

    /// <summary>
    /// Devolve uma conexão InUse ao pool (vira Available). Retorna False se a
    /// conexão não pertencia ao InUse (devolução dupla / desconhecida).
    /// </summary>
    function ReturnToAvailable(const ANative: TObject; const ANowMs: Int64): Boolean;

    /// <summary>Cópia de todas as entries, para avaliação fora de lock (GC).</summary>
    function SnapshotAll: TArray<TConnSnapshotItem>;

    /// <summary>
    /// Projeção de monitoramento: todas as conexões com idades calculadas a
    /// partir de ANowMs (fornecido pelo IConnClock do chamador).
    /// </summary>
    function SnapshotLeases(const ANowMs: Int64): TArray<TConnLeaseInfo>;

    /// <summary>
    /// Remove do rastreamento as conexões nativas informadas (idle/zombie já
    /// decididas pelo GC). Não destrói o objeto nativo — isso é feito FORA do
    /// lock pelo chamador via IConnEngine.DestroyNative.
    /// </summary>
    procedure RemoveNatives(const ANatives: array of TObject);

    /// <summary>
    /// Esvazia o pool: retorna todas as conexões nativas rastreadas e limpa o
    /// estado. O chamador as destrói fora do lock.
    /// </summary>
    function DrainAll: TArray<TObject>;

    function ActiveCount: Integer;
    function IdleCount: Integer;
    function TotalCount: Integer;
    function Stats: TConnPoolStats;

    property EngineID: string read FEngineID;
    property MaxSize: Integer read FMaxSize;
  end;

implementation

{ TConnPoolStore }

constructor TConnPoolStore.Create(const AEngineID: string; const AMaxSize: Integer);
begin
  inherited Create;
  FLock      := TCriticalSection.Create;
  FEngineID  := AEngineID;
  FMaxSize   := AMaxSize;
  FAvailable := TQueue<TConnEntry>.Create;
  FInUse     := TDictionary<TObject, TConnEntry>.Create;
  FAll       := TObjectList<TConnEntry>.Create(True {OwnsObjects});
end;

destructor TConnPoolStore.Destroy;
begin
  FInUse.Free;
  FAvailable.Free;
  FAll.Free;        // libera todas as TConnEntry
  FLock.Free;
  inherited;
end;

function TConnPoolStore.TryTakeAvailable(const ANowMs: Int64; const AThreadId: TThreadID;
  out ANative: TObject): Boolean;
var
  Entry: TConnEntry;
begin
  ANative := nil;
  FLock.Enter;
  try
    if FAvailable.Count = 0 then
      Exit(False);
    Entry := FAvailable.Dequeue;
    Entry.State         := csInUse;
    Entry.AcquiredAtMs  := ANowMs;
    Entry.OwnerThreadId := AThreadId;
    FInUse.Add(Entry.Native, Entry);
    ANative := Entry.Native;
    Result  := True;
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.RegisterInUse(const ANative: TObject; const AId: TGUID;
  const ANowMs: Int64; const AThreadId: TThreadID): TConnEntry;
begin
  FLock.Enter;
  try
    Result := TConnEntry.Create;
    Result.Native        := ANative;
    Result.Id            := AId;
    Result.EngineID      := FEngineID;
    Result.State         := csInUse;
    Result.CreatedAtMs   := ANowMs;
    Result.AcquiredAtMs  := ANowMs;
    Result.OwnerThreadId := AThreadId;
    FAll.Add(Result);
    FInUse.Add(ANative, Result);
    Inc(FCreatedTotal);
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.ReturnToAvailable(const ANative: TObject; const ANowMs: Int64): Boolean;
var
  Entry: TConnEntry;
begin
  FLock.Enter;
  try
    if not FInUse.TryGetValue(ANative, Entry) then
      Exit(False);
    FInUse.Remove(ANative);
    Entry.State            := csAvailable;
    Entry.LastReleasedAtMs := ANowMs;
    Entry.OwnerThreadId    := 0;
    FAvailable.Enqueue(Entry);
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.SnapshotAll: TArray<TConnSnapshotItem>;
var
  I: Integer;
  Entry: TConnEntry;
begin
  FLock.Enter;
  try
    SetLength(Result, FAll.Count);
    for I := 0 to FAll.Count - 1 do
    begin
      Entry := FAll[I];
      Result[I].Native           := Entry.Native;
      Result[I].Id               := Entry.Id;
      Result[I].State            := Entry.State;
      Result[I].AcquiredAtMs     := Entry.AcquiredAtMs;
      Result[I].LastReleasedAtMs := Entry.LastReleasedAtMs;
      Result[I].OwnerThreadId    := Entry.OwnerThreadId;
    end;
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.SnapshotLeases(const ANowMs: Int64): TArray<TConnLeaseInfo>;
var
  I: Integer;
  Entry: TConnEntry;
begin
  FLock.Enter;
  try
    SetLength(Result, FAll.Count);
    for I := 0 to FAll.Count - 1 do
    begin
      Entry := FAll[I];
      Result[I].Id               := Entry.Id;
      Result[I].EngineID         := Entry.EngineID;
      Result[I].State            := Entry.State;
      Result[I].OwnerThreadId    := NativeUInt(Entry.OwnerThreadId);
      Result[I].CreatedAtMs      := Entry.CreatedAtMs;
      Result[I].AcquiredAtMs     := Entry.AcquiredAtMs;
      Result[I].LastReleasedAtMs := Entry.LastReleasedAtMs;
      Result[I].AgeMs            := ANowMs - Entry.CreatedAtMs;
      if Entry.State = csInUse then
        Result[I].InUseForMs := ANowMs - Entry.AcquiredAtMs
      else
        Result[I].InUseForMs := 0;
      if Entry.State = csAvailable then
        Result[I].IdleForMs := ANowMs - Entry.LastReleasedAtMs
      else
        Result[I].IdleForMs := 0;
    end;
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.RemoveEntryNoLock(const ANative: TObject): Boolean;
var
  Entry: TConnEntry;
  I: Integer;
begin
  Result := False;
  FInUse.Remove(ANative);

  // Remover da fila de Available (TQueue não permite remoção arbitrária:
  // reconstrói sem o alvo).
  if FAvailable.Count > 0 then
  begin
    var Tmp := TQueue<TConnEntry>.Create;
    try
      while FAvailable.Count > 0 do
      begin
        Entry := FAvailable.Dequeue;
        if Entry.Native <> ANative then
          Tmp.Enqueue(Entry);
      end;
      while Tmp.Count > 0 do
        FAvailable.Enqueue(Tmp.Dequeue);
    finally
      Tmp.Free;
    end;
  end;

  for I := FAll.Count - 1 downto 0 do
    if FAll[I].Native = ANative then
    begin
      FAll.Delete(I);   // OwnsObjects libera a TConnEntry
      Result := True;
      Inc(FEvictedTotal);
      Break;
    end;
end;

procedure TConnPoolStore.RemoveNatives(const ANatives: array of TObject);
var
  Native: TObject;
begin
  FLock.Enter;
  try
    for Native in ANatives do
      RemoveEntryNoLock(Native);
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.DrainAll: TArray<TObject>;
var
  I: Integer;
begin
  FLock.Enter;
  try
    SetLength(Result, FAll.Count);
    for I := 0 to FAll.Count - 1 do
      Result[I] := FAll[I].Native;
    FAvailable.Clear;
    FInUse.Clear;
    FAll.Clear;  // libera as entries; natives já copiados para Result
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.ActiveCount: Integer;
begin
  FLock.Enter;
  try
    Result := FInUse.Count;
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.IdleCount: Integer;
begin
  FLock.Enter;
  try
    Result := FAvailable.Count;
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.TotalCount: Integer;
begin
  FLock.Enter;
  try
    Result := FAll.Count;
  finally
    FLock.Leave;
  end;
end;

function TConnPoolStore.Stats: TConnPoolStats;
begin
  FLock.Enter;
  try
    Result := Default(TConnPoolStats);
    Result.EngineID     := FEngineID;
    Result.Active       := FInUse.Count;
    Result.Idle         := FAvailable.Count;
    Result.Total        := FAll.Count;
    Result.MaxSize      := FMaxSize;
    Result.Waiting      := 0;  // preenchido pelo manager, que conhece a fila de espera
    Result.CreatedTotal := FCreatedTotal;
    Result.EvictedTotal := FEvictedTotal;
  finally
    FLock.Leave;
  end;
end;

end.
