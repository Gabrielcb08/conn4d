unit Conn4D.Adapter.UniDAC;

{$I Conn4D.inc}

{
  Conn4D — Adapter / UniDAC

  Ergonomia do engine UniDAC: IUniConn4D (interface-marcador que estende IConn4D,
  GUID próprio) e a factory TUniConn4D.Acquire. O acessor Connection devolve o
  handle universal TConnRef (Conn4D.Adapter.ConnRef), cujo operador implícito para
  TUniConnection (sob CONN4D_UNIDAC) faz a conversão. Espelha o adapter FireDAC.

  ATENÇÃO: requer UniDAC no caminho de compilação. Não compilado no ambiente
  atual; validar ao integrar.
}

interface

{$IFDEF CONN4D_UNIDAC}

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Core.Base,
  Conn4D.Core.Pool,
  Conn4D.Core,
  Conn4D.Core.Engine,
  Conn4D.Core.Transaction,
  Conn4D.Adapter.ConnRef,
  Conn4D.Shared.Types;

type
  // Interface-marcador para tipar variáveis "UniDAC". Estende a agnóstica
  // IConn4DNative (porta IConn4D + Connection) com GUID próprio para
  // Supports/QueryInterface. O acessor Connection já vem de IConn4DNative.
  IUniConn4D = interface(IConn4DNative)
    ['{D1A4F0E1-0411-0000-0000-000000000001}']
  end;

  TUniConn4D = record
    class function Acquire: IUniConn4D; static;
  end;

{$ENDIF}

implementation

{$IFDEF CONN4D_UNIDAC}

uses
  System.SysUtils,
  Conn4D.Core.Monitor,
  Conn4D.Core.Config,
  Conn4D.Core.Factory,
  Conn4D.Core.Registry,
  Conn4D.Core.TransactionMgr,
  Conn4D.Adapter.Engines,
  Conn4D.Engine.UniDAC;

type
  TUniConn4DImpl = class(TInterfacedObject, IUniConn4D, IConn4DNative, IConn4D, IConn4DBase)
  private
    FEngine:     IConnEngine;
    FConfig:     IConnConfig;
    FPool:       IConnPool;
    FBase:       IConn4DBase;
    FId:         TGUID;
    FLock:       TCriticalSection;
    FThreadConn: TDictionary<TThreadID, TObject>;
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

    function Id: TGUID;
    function EngineID: string;
    function Stats: TConnPoolStats;
    function State: TConnState;
    procedure Release;
    procedure Shutdown;
  end;

{ TUniConn4D }

class function TUniConn4D.Acquire: IUniConn4D;
begin
  Result := TUniConn4DImpl.Create;
end;

{ TUniConn4DImpl }

constructor TUniConn4DImpl.Create;
begin
  inherited Create;
  FEngine     := TUniDACEngine.New;
  FConfig     := TConnConfig.New;
  FLock       := TCriticalSection.Create;
  FThreadConn := TDictionary<TThreadID, TObject>.Create;
  CreateGUID(FId);
end;

destructor TUniConn4DImpl.Destroy;
begin
  if FBase <> nil then
    TConn4DRegistry.Instance.Unregister(FBase);
  FThreadConn.Free;
  FLock.Free;
  inherited;
end;

procedure TUniConn4DImpl.EnsureManager;
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
    end;
  finally
    FLock.Leave;
  end;
end;

function TUniConn4DImpl.EnsureNativeForThread: TObject;
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

  Result := FPool.Acquire(FConfig.Pool.AcquireTimeout);

  FLock.Enter;
  try
    FThreadConn.AddOrSetValue(Tid, Result);
  finally
    FLock.Leave;
  end;
end;

function TUniConn4DImpl.Configure(const ACfg: IConnConfig): IConn4D;
begin
  if ACfg <> nil then
    FConfig := ACfg.Clone;
  Result := Self;
end;

function TUniConn4DImpl.Configure: IConnConfig;
begin
  Result := FConfig.BindTo(Self);
end;

function TUniConn4DImpl.Open: IConn4D;
begin
  EnsureNativeForThread;
  Result := Self;
end;

function TUniConn4DImpl.Connection: TConnRef;
begin
  Result := TConnRef.Wrap(EnsureNativeForThread);
end;

function TUniConn4DImpl.BeginTransaction: IConnTransaction;
begin
  Result := TConnTransaction.BeginOn(FEngine, EnsureNativeForThread, ciReadCommitted, nil);
end;

function TUniConn4DImpl.LiveConnections: TArray<TConnLeaseInfo>;
var
  Mon: IConnMonitor;
begin
  if (FPool <> nil) and Supports(FPool, IConnMonitor, Mon) then
    Result := Mon.LiveConnections
  else
    Result := nil;
end;

function TUniConn4DImpl.Id: TGUID;
begin
  if FBase <> nil then Result := FBase.Id else Result := FId;
end;

function TUniConn4DImpl.EngineID: string;
begin
  Result := FEngine.EngineID;
end;

function TUniConn4DImpl.Stats: TConnPoolStats;
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

function TUniConn4DImpl.State: TConnState;
begin
  if FBase <> nil then Result := FBase.State else Result := csCreated;
end;

procedure TUniConn4DImpl.Release;
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
  FPool.ReturnToPool(Native);
end;

procedure TUniConn4DImpl.Shutdown;
begin
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
  TConn4DEngines.Register('unidac',
    function: IConn4DNative
    begin
      Result := TUniConn4D.Acquire;
    end);

{$ENDIF}

end.
