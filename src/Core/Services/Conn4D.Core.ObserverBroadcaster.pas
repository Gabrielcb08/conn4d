unit Conn4D.Core.ObserverBroadcaster;

{
  Conn4D — Core / Services / ObserverBroadcaster

  TConnObserverBroadcaster: implementa IConnObserverBroadcaster. Pool e GC
  publicam eventos de ciclo de vida aqui; assinantes IConnObserver os recebem.
  Thread-safe: Publish copia a lista de assinantes sob lock curto e invoca os
  callbacks FORA do lock, para que um observador lento não bloqueie o pool nem
  cause reentrância sob lock.
}

interface

uses
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Core.Observer;

type
  TConnObserverBroadcaster = class(TInterfacedObject, IConnObserverBroadcaster)
  private
    FLock:      TCriticalSection;
    FObservers: TList<IConnObserver>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Subscribe(const AObserver: IConnObserver);
    procedure Unsubscribe(const AObserver: IConnObserver);
    procedure Publish(const AEvent: TConnEvent);

    class function New: IConnObserverBroadcaster; static;
  end;

implementation

{ TConnObserverBroadcaster }

class function TConnObserverBroadcaster.New: IConnObserverBroadcaster;
begin
  Result := TConnObserverBroadcaster.Create;
end;

constructor TConnObserverBroadcaster.Create;
begin
  inherited Create;
  FLock      := TCriticalSection.Create;
  FObservers := TList<IConnObserver>.Create;
end;

destructor TConnObserverBroadcaster.Destroy;
begin
  FObservers.Free;
  FLock.Free;
  inherited;
end;

procedure TConnObserverBroadcaster.Subscribe(const AObserver: IConnObserver);
begin
  if AObserver = nil then
    Exit;
  FLock.Enter;
  try
    if not FObservers.Contains(AObserver) then
      FObservers.Add(AObserver);
  finally
    FLock.Leave;
  end;
end;

procedure TConnObserverBroadcaster.Unsubscribe(const AObserver: IConnObserver);
begin
  FLock.Enter;
  try
    FObservers.Remove(AObserver);
  finally
    FLock.Leave;
  end;
end;

procedure TConnObserverBroadcaster.Publish(const AEvent: TConnEvent);
var
  Snapshot: TArray<IConnObserver>;
  Obs: IConnObserver;
begin
  FLock.Enter;
  try
    Snapshot := FObservers.ToArray;
  finally
    FLock.Leave;
  end;

  for Obs in Snapshot do
    Obs.OnConnEvent(AEvent);  // invocação FORA do lock
end;

end.
