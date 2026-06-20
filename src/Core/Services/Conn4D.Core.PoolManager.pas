unit Conn4D.Core.PoolManager;

{
  Conn4D — Core / Services / PoolManager

  TConnPoolManager: orquestra o empréstimo de conexões. É o ÚNICO lugar que
  compõe semáforo + pool store + contexto de thread, respeitando a ordem fixa
  de aquisição de locks (ver references/threading-rules.md):

      1. FSemaphore.WaitFor   (limita a poolSize threads simultâneas)
      2. FStore (autossincronizado)
      3. FContext (autossincronizado)

  O semáforo é o controle de capacidade: um permit é adquirido em Acquire e só
  é devolvido quando a conexão SAI do estado InUse — seja por ReturnToPool
  (normal) ou por EvictZombies (vazamento). Idle eviction NÃO devolve permit,
  pois conexões Available já o devolveram ao serem retornadas.

  Implementa IConnPool (empréstimo) e IConn4DBase (controle agnóstico para o
  registry/GC). Não conhece engine concreto — só IConnEngine.
}

interface

uses
  System.Classes,
  Conn4D.Shared.Types,
  Conn4D.Shared.Config,
  Conn4D.Shared.Logger,
  Conn4D.Core.Base,
  Conn4D.Core.Pool,
  Conn4D.Core,
  Conn4D.Core.Monitor,
  Conn4D.Core.Engine,
  Conn4D.Core.Clock,
  Conn4D.Core.HealthCheck,
  Conn4D.Core.Observer,
  Conn4D.Core.Semaphore,
  Conn4D.Core.PoolStore,
  Conn4D.Core.ThreadContext;

type
  TConnPoolManager = class(TInterfacedObject, IConnPool, IConn4DBase, IConnMonitor)
  private
    FEngine:      IConnEngine;
    FConfig:      IConnConfig;
    FClock:       IConnClock;
    FLogger:      IConnLogger;
    FBroadcaster: IConnObserverBroadcaster;
    FHealth:      IConnHealthCheck;     // opcional; nil = sem health check
    FStore:       TConnPoolStore;
    FSemaphore:   TConnSemaphore;
    FContext:     TConnThreadContextStore;
    FId:          TGUID;
    FState:       TConnState;

    function CreateAndRegister(const ANowMs: Int64; const AThreadId: TThreadID): TObject;
    procedure PublishEvent(const AType: TConnEventType; const AConnId: TGUID;
      const ADetail: string = '');
  public
    constructor Create(const AEngine: IConnEngine; const AConfig: IConnConfig;
      const AClock: IConnClock = nil; const ALogger: IConnLogger = nil;
      const ABroadcaster: IConnObserverBroadcaster = nil;
      const AHealth: IConnHealthCheck = nil);
    destructor Destroy; override;

    { IConnPool }
    function Acquire(const ATimeoutMs: Cardinal): TObject;
    procedure ReturnToPool(const ANative: TObject);
    function ActiveCount: Integer;
    function IdleCount: Integer;
    procedure EvictIdle(const AIdleTimeoutMs: Cardinal);
    procedure EvictZombies(const AMaxLeaseMs: Cardinal);
    procedure DrainAll;

    { IConn4DBase }
    function Id: TGUID;
    function EngineID: string;
    function Stats: TConnPoolStats;
    function State: TConnState;
    procedure Release;
    procedure Shutdown;

    { IConnMonitor }
    function LiveConnections: TArray<TConnLeaseInfo>;

    property Config: IConnConfig read FConfig;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Conn4D.Shared.Exceptions,
  Conn4D.Core.SystemClock,
  Conn4D.Core.ObserverBroadcaster;

{ TConnPoolManager }

constructor TConnPoolManager.Create(const AEngine: IConnEngine; const AConfig: IConnConfig;
  const AClock: IConnClock; const ALogger: IConnLogger;
  const ABroadcaster: IConnObserverBroadcaster; const AHealth: IConnHealthCheck);
begin
  inherited Create;
  if AEngine = nil then
    raise EConn4DConfigException.Create('TConnPoolManager: engine is nil');
  if AConfig = nil then
    raise EConn4DConfigException.Create('TConnPoolManager: config is nil');
  if AConfig.Pool.MaxSize < 1 then
    raise EConn4DConfigException.Create('TConnPoolManager: Pool.MaxSize must be >= 1');

  FEngine := AEngine;
  FConfig := AConfig;

  if AClock <> nil then FClock := AClock else FClock := TConnSystemClock.New;
  if ALogger <> nil then FLogger := ALogger else FLogger := TNullLogger.New;
  if ABroadcaster <> nil then FBroadcaster := ABroadcaster
                          else FBroadcaster := TConnObserverBroadcaster.New;
  FHealth := AHealth;  // pode ficar nil

  CreateGUID(FId);
  FStore     := TConnPoolStore.Create(AEngine.EngineID, AConfig.Pool.MaxSize);
  FSemaphore := TConnSemaphore.Create(AConfig.Pool.MaxSize);
  FContext   := TConnThreadContextStore.Create;
  FState     := csCreated;  // lazy: nenhuma conexão física aberta ainda
end;

destructor TConnPoolManager.Destroy;
begin
  // Garante que recursos nativos sejam encerrados antes de soltar os objetos.
  if FState <> csDestroyed then
    DrainAll;
  FContext.Free;
  FSemaphore.Free;
  FStore.Free;
  inherited;
end;

procedure TConnPoolManager.PublishEvent(const AType: TConnEventType; const AConnId: TGUID;
  const ADetail: string);
var
  Ev: TConnEvent;
begin
  if FBroadcaster = nil then
    Exit;
  Ev.EventType := AType;
  Ev.ConnId    := AConnId;
  Ev.EngineID  := FEngine.EngineID;
  Ev.Timestamp := Now;
  Ev.Detail    := ADetail;
  FBroadcaster.Publish(Ev);
end;

function TConnPoolManager.CreateAndRegister(const ANowMs: Int64; const AThreadId: TThreadID): TObject;
var
  Native: TObject;
  NewId:  TGUID;
begin
  Native := FEngine.CreateNative(FConfig);
  try
    FEngine.OpenNative(Native);
  except
    on E: Exception do
    begin
      FEngine.DestroyNative(Native);
      FLogger.Error(Format('Failed to open native connection: %s', [E.Message]));
      raise;
    end;
  end;
  CreateGUID(NewId);
  FStore.RegisterInUse(Native, NewId, ANowMs, AThreadId);
  PublishEvent(ceCreated, NewId);
  Result := Native;
end;

function TConnPoolManager.Acquire(const ATimeoutMs: Cardinal): TObject;
var
  NowMs:  Int64;
  Tid:    TThreadID;
  Native: TObject;
begin
  // (1) Semáforo — lock mais externo. Bloqueia se poolSize threads já entraram.
  if not FSemaphore.WaitFor(ATimeoutMs) then
    raise EConn4DTimeoutException.CreateFmt(
      'Acquire timeout after %d ms (pool exhausted, MaxSize=%d)',
      [ATimeoutMs, FConfig.Pool.MaxSize]);

  try
    NowMs := FClock.NowMs;
    Tid   := TThread.CurrentThread.ThreadID;

    // (2) Pool store — reusa uma ociosa ou cria nova dentro da capacidade.
    if FStore.TryTakeAvailable(NowMs, Tid, Native) then
    begin
      if (FHealth <> nil) and (not FHealth.IsHealthy(Native)) then
      begin
        // Conexão ociosa apodreceu: descarta e cria uma fresca no mesmo permit.
        FStore.RemoveNatives([Native]);
        FEngine.DestroyNative(Native);
        PublishEvent(ceHealthFail, TGUID.Empty);
        Native := CreateAndRegister(NowMs, Tid);
      end;
    end
    else
      Native := CreateAndRegister(NowMs, Tid);

    // (3) Contexto por thread — lock mais interno.
    FContext.Bind(Tid, Native);

    if FState = csCreated then
      FState := csAvailable;  // primeira conexão física aberta (saiu do lazy)

    PublishEvent(ceAcquired, TGUID.Empty);
    Result := Native;
  except
    FSemaphore.Release;  // devolve o permit se algo falhou após o Wait
    raise;
  end;
end;

procedure TConnPoolManager.ReturnToPool(const ANative: TObject);
var
  NowMs: Int64;
begin
  if ANative = nil then
    Exit;
  NowMs := FClock.NowMs;
  if FStore.ReturnToAvailable(ANative, NowMs) then
  begin
    FContext.RemoveNative(ANative);
    PublishEvent(ceReleased, TGUID.Empty);
    FSemaphore.Release;  // saiu de InUse: devolve o permit
  end
  else
    // Devolução de algo não emprestado por aqui: não libera permit (evita
    // over-release que furaria a capacidade). Apenas registra.
    FLogger.Warn('ReturnToPool called for an unknown/already-returned connection');
end;

function TConnPoolManager.ActiveCount: Integer;
begin
  Result := FStore.ActiveCount;
end;

function TConnPoolManager.IdleCount: Integer;
begin
  Result := FStore.IdleCount;
end;

procedure TConnPoolManager.EvictIdle(const AIdleTimeoutMs: Cardinal);
var
  Snapshot: TArray<TConnSnapshotItem>;
  Victims:  TList<TObject>;
  Item:     TConnSnapshotItem;
  NowMs:    Int64;
  Native:   TObject;
begin
  NowMs    := FClock.NowMs;
  Snapshot := FStore.SnapshotAll;               // lock curto, copiado
  Victims  := TList<TObject>.Create;
  try
    for Item in Snapshot do                     // avaliação SEM lock
      if (Item.State = csAvailable) and
         (NowMs - Item.LastReleasedAtMs > Int64(AIdleTimeoutMs)) then
        Victims.Add(Item.Native);

    if Victims.Count = 0 then
      Exit;

    FStore.RemoveNatives(Victims.ToArray);      // remoção sob lock curto

    for Native in Victims do                     // destruição FORA do lock
    begin
      FEngine.DestroyNative(Native);
      PublishEvent(ceEvictedIdle, TGUID.Empty);
    end;
    // Idle não devolve permit: a conexão já o devolvera ao ser retornada.
  finally
    Victims.Free;
  end;
end;

procedure TConnPoolManager.EvictZombies(const AMaxLeaseMs: Cardinal);
var
  Snapshot: TArray<TConnSnapshotItem>;
  Victims:  TList<TObject>;
  Item:     TConnSnapshotItem;
  NowMs:    Int64;
  Native:   TObject;
begin
  NowMs    := FClock.NowMs;
  Snapshot := FStore.SnapshotAll;
  Victims  := TList<TObject>.Create;
  try
    for Item in Snapshot do
      if (Item.State = csInUse) and
         (NowMs - Item.AcquiredAtMs > Int64(AMaxLeaseMs)) then
      begin
        Victims.Add(Item.Native);
        FLogger.Warn(Format(
          'Zombie connection reclaimed: id=%s heldByTID=%d leaseMs=%d',
          [GUIDToString(Item.Id), Int64(Item.OwnerThreadId), NowMs - Item.AcquiredAtMs]));
      end;

    if Victims.Count = 0 then
      Exit;

    // Desfaz transação pendente do vazamento ANTES de destruir (fora de lock).
    for Native in Victims do
      try
        if FEngine.InTx(Native) then
          FEngine.RollbackTx(Native);
      except
        on E: Exception do
          FLogger.Error(Format('Rollback during zombie reclaim failed: %s', [E.Message]));
      end;

    FStore.RemoveNatives(Victims.ToArray);

    for Native in Victims do
    begin
      FContext.RemoveNative(Native);
      FEngine.DestroyNative(Native);
      PublishEvent(ceEvictedZombie, TGUID.Empty);
      FSemaphore.Release;  // recupera o permit que o thread vazado nunca devolveu
    end;
  finally
    Victims.Free;
  end;
end;

procedure TConnPoolManager.DrainAll;
var
  Natives: TArray<TObject>;
  Native:  TObject;
begin
  Natives := FStore.DrainAll;
  for Native in Natives do
  begin
    try
      if FEngine.InTx(Native) then
        FEngine.RollbackTx(Native);
      FEngine.CloseNative(Native);
    except
      on E: Exception do
        FLogger.Error(Format('Error closing connection during drain: %s', [E.Message]));
    end;
    FEngine.DestroyNative(Native);
  end;
  FContext.Clear;
end;

function TConnPoolManager.Id: TGUID;
begin
  Result := FId;
end;

function TConnPoolManager.EngineID: string;
begin
  Result := FEngine.EngineID;
end;

function TConnPoolManager.Stats: TConnPoolStats;
begin
  Result := FStore.Stats;
end;

function TConnPoolManager.State: TConnState;
begin
  Result := FState;
end;

procedure TConnPoolManager.Release;
var
  Native: TObject;
begin
  // Devolve a conexão corrente desta thread, se houver.
  if FContext.TryGetCurrent(TThread.CurrentThread.ThreadID, Native) then
    ReturnToPool(Native);
end;

function TConnPoolManager.LiveConnections: TArray<TConnLeaseInfo>;
begin
  Result := FStore.SnapshotLeases(FClock.NowMs);
end;

procedure TConnPoolManager.Shutdown;
begin
  if FState = csDestroyed then
    Exit;
  DrainAll;
  FState := csDestroyed;
  PublishEvent(ceShutdown, FId);
  FLogger.Info(Format('Pool manager %s shut down', [GUIDToString(FId)]));
end;

end.
