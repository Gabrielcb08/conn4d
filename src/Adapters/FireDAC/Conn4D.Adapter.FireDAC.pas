unit Conn4D.Adapter.FireDAC;

{
  Conn4D — Adapter / FireDAC

  Ergonomia tipada do engine FireDAC (ver spec §5 e references/add-engine.md):
   - IFDConn4D: interface-marcador que estende a fluente agnóstica IConn4D (GUID
     próprio) para tipar variáveis "FireDAC". O acessor da conexão (Connection)
     já vem de IConn4D, devolvendo o handle universal TConnRef
     (Conn4D.Adapter.ConnRef), cujos operadores implícitos convertem p/ o tipo nativo
     do destino — permitindo `FDQuery.Connection := Conn4D.Connection;` sem cast.
   - TFDConn4D.Acquire: factory pública.

  Lazy open (spec §6): Acquire cria a fachada e a registra no global; o manager
  genérico do Core e a conexão física só nascem no primeiro uso real
  (.Connection / .BeginTransaction / .Open), depois da config fluente.

  Multi-thread: uma mesma IFDConn4D pode ser compartilhada entre threads. Cada
  thread recebe SUA conexão emprestada do pool (rastreio por ThreadID aqui);
  chamadas repetidas a .Connection na mesma thread devolvem a mesma conexão até
  Release. A capacidade é garantida pelo semáforo do manager.
}

interface

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Core.Base,
  Conn4D.Core.Pool,
  Conn4D.Core.Monitor,
  Conn4D.Core,
  Conn4D.Core.Engine,
  Conn4D.Core.Transaction,
  Conn4D.Adapter.ConnRef,
  Conn4D.Shared.Types;

type
  /// <summary>
  /// Interface-marcador para tipar variáveis "FireDAC". Estende a agnóstica
  /// IConn4DNative (porta IConn4D + Connection) com GUID próprio para
  /// Supports/QueryInterface. O acessor Connection já vem de IConn4DNative.
  /// </summary>
  IFDConn4D = interface(IConn4DNative)
    ['{D1A4F0E1-FD00-0000-0000-000000000001}']
  end;

  /// <summary>Factory pública do adapter FireDAC.</summary>
  TFDConn4D = record
    /// <summary>Cria a fachada fluente (lazy). Configure e use em seguida.</summary>
    class function Acquire: IFDConn4D; static;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Shared.Logger,
  Conn4D.Core.Clock,
  Conn4D.Core.Observer,
  Conn4D.Core.Config,
  Conn4D.Core.Factory,
  Conn4D.Core.Registry,
  Conn4D.Core.TransactionMgr,
  Conn4D.Core.GC,
  Conn4D.Core.GarbageCollector,
  Conn4D.Adapter.Engines,
  Conn4D.Engine.FireDAC
{$IFNDEF CONN4D_NOAUTOLINK}
  // Auto-link (apps): wait-cursor VCL + drivers FireDAC.Phys.* + VendorLib.
  // O pacote runtime e os testes definem CONN4D_NOAUTOLINK p/ ficarem enxutos.
  , Conn4D.Adapter.FireDAC.VCL
{$ENDIF}
  ;

type
  /// Implementação concreta da fachada. Não exposta — só via IFDConn4D.
  TFDConn4DImpl = class(TInterfacedObject, IFDConn4D, IConn4DNative, IConn4D, IConn4DBase)
  private
    FEngine:     IConnEngine;
    FConfig:     IConnConfig;      // config como interface (DIP)
    FPool:       IConnPool;        // manager genérico do Core, criado lazy
    FBase:       IConn4DBase;      // mesma instância do manager
    FGC:         IConnGC;          // coletor idle/zombie desta conexão (lazy)
    FId:         TGUID;            // id estável, válido mesmo antes do manager
    FLock:       TCriticalSection; // protege FThreadConn e a criação lazy
    FThreadConn: TDictionary<TThreadID, TObject>; // conexão emprestada por thread

    procedure EnsureManager;
    function EnsureNativeForThread: TObject;
  public
    constructor Create;
    destructor Destroy; override;

    { IConn4D — fachada agnóstica }
    function Configure(const ACfg: IConnConfig): IConn4D; overload;
    function Configure: IConnConfig; overload;
    function Open: IConn4D;
    function BeginTransaction: IConnTransaction;
    function LiveConnections: TArray<TConnLeaseInfo>;

    { IConn4DNative — acessor da conexão nativa (handle universal) }
    function Connection: TConnRef;

    { IConn4DBase — delegado ao manager lazy }
    function Id: TGUID;
    function EngineID: string;
    function Stats: TConnPoolStats;
    function State: TConnState;
    procedure Release;
    procedure Shutdown;
  end;

{ TFDConn4D }

class function TFDConn4D.Acquire: IFDConn4D;
begin
  Result := TFDConn4DImpl.Create;
end;

{ TFDConn4DImpl }

constructor TFDConn4DImpl.Create;
begin
  inherited Create;
  FEngine     := TFireDACEngine.New;
  FConfig     := TConnConfig.New;
  FLock       := TCriticalSection.Create;
  FThreadConn := TDictionary<TThreadID, TObject>.Create;
  CreateGUID(FId);
  // Registro no global acontece em EnsureManager (quando há config e manager).
end;

destructor TFDConn4DImpl.Destroy;
begin
  // Para a thread do GC ANTES de soltar o pool: o GC referencia FPool e não pode
  // rodar um ciclo enquanto o manager é destruído.
  if FGC <> nil then
  begin
    FGC.Stop;
    FGC := nil;
  end;
  if FBase <> nil then
    TConn4DRegistry.Instance.Unregister(FBase);
  FThreadConn.Free;
  FLock.Free;
  inherited;
end;

procedure TFDConn4DImpl.EnsureManager;
begin
  if FPool <> nil then
    Exit;
  FLock.Enter;
  try
    if FPool = nil then
    begin
      FPool := TConn4DCoreFactory.CreateManager(FEngine, FConfig);
      if TConn4DCoreFactory.TryGetBase(FPool, FBase) then
        TConn4DRegistry.Instance.Register(FBase);

      // Liga o garbage collector desta conexão (honra GCEnabled/GCInterval e os
      // timeouts do pool). É ele que, numa thread própria, evicta conexões Idle
      // e mata Zombies (InUse além de MaxLeaseTime) — sem isso esses ajustes da
      // config ficariam inertes e vazamentos jamais seriam recuperados.
      if FConfig.GC.Enabled then
      begin
        FGC := TConnGarbageCollector.New(FConfig.GC,
          FConfig.Pool.IdleTimeout, FConfig.Pool.MaxLeaseTime);
        FGC.Register(FPool);
        FGC.Start;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFDConn4DImpl.EnsureNativeForThread: TObject;
var
  Tid: TThreadID;
begin
  EnsureManager;
  Tid := TThread.CurrentThread.ThreadID;
  FLock.Enter;
  try
    if FThreadConn.TryGetValue(Tid, Result) then
      Exit;
  finally
    FLock.Leave;
  end;

  // Acquire fora do FLock: pode bloquear no semáforo do pool; não deve travar
  // a fachada para outras threads. Honra o AcquireTimeout configurado.
  Result := FPool.Acquire(FConfig.Pool.AcquireTimeout);

  FLock.Enter;
  try
    FThreadConn.AddOrSetValue(Tid, Result);
  finally
    FLock.Leave;
  end;
end;

function TFDConn4DImpl.Configure(const ACfg: IConnConfig): IConn4D;
begin
  if ACfg <> nil then
    FConfig := ACfg.Clone;   // cópia independente (não compartilha referência)
  Result := Self;
end;

function TFDConn4DImpl.Configure: IConnConfig;
begin
  // Builder vinculado: muta a config desta conexão; EndConfig devolve Self.
  Result := FConfig.BindTo(Self);
end;


function TFDConn4DImpl.Open: IConn4D;
begin
  EnsureNativeForThread;
  Result := Self;
end;

function TFDConn4DImpl.Connection: TConnRef;
begin
  Result := TConnRef.Wrap(EnsureNativeForThread);
end;

function TFDConn4DImpl.BeginTransaction: IConnTransaction;
var
  Native: TObject;
begin
  Native := EnsureNativeForThread;
  Result := TConnTransaction.BeginOn(FEngine, Native, ciReadCommitted, nil);
end;

function TFDConn4DImpl.LiveConnections: TArray<TConnLeaseInfo>;
var
  Mon: IConnMonitor;
begin
  if (FPool <> nil) and Supports(FPool, IConnMonitor, Mon) then
    Result := Mon.LiveConnections
  else
    Result := nil;
end;

function TFDConn4DImpl.Id: TGUID;
begin
  if FBase <> nil then
    Result := FBase.Id
  else
    Result := FId;
end;

function TFDConn4DImpl.EngineID: string;
begin
  Result := FEngine.EngineID;
end;

function TFDConn4DImpl.Stats: TConnPoolStats;
begin
  if FBase <> nil then
    Result := FBase.Stats
  else
  begin
    Result := Default(TConnPoolStats);
    Result.EngineID := FEngine.EngineID;
    Result.MaxSize  := FConfig.Pool.MaxSize;
  end;
end;

function TFDConn4DImpl.State: TConnState;
begin
  if FBase <> nil then
    Result := FBase.State
  else
    Result := csCreated;  // lazy: ainda não aberto
end;

procedure TFDConn4DImpl.Release;
var
  Tid:    TThreadID;
  Native: TObject;
begin
  if FPool = nil then
    Exit;
  Tid := TThread.CurrentThread.ThreadID;
  FLock.Enter;
  try
    if not FThreadConn.TryGetValue(Tid, Native) then
      Exit;
    FThreadConn.Remove(Tid);
  finally
    FLock.Leave;
  end;
  FPool.ReturnToPool(Native);  // devolução fora do FLock
end;

procedure TFDConn4DImpl.Shutdown;
begin
  if FGC <> nil then
    FGC.Stop;  // para a coleta antes de drenar o pool
  if FBase <> nil then
    FBase.Shutdown;
  FLock.Enter;
  try
    FThreadConn.Clear;
  finally
    FLock.Leave;
  end;
end;

initialization
  // Auto-registro: o componente resolve 'firedac' sem conhecer este adapter.
  TConn4DEngines.Register('firedac',
    function: IConn4DNative
    begin
      Result := TFDConn4D.Acquire;
    end);

end.
