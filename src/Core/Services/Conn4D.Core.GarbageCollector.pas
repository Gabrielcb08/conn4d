unit Conn4D.Core.GarbageCollector;

{
  Conn4D — Core / Services / GarbageCollector

  TConnGarbageCollector: implementa IConnGC. Acorda a cada `gcInterval`
  (padrão 30s) numa TThread PRÓPRIA e, para cada pool registrado, evicta
  conexões Idle (além de IdleTimeout) e mata Zombies (InUse além de
  MaxLeaseTime). Ver spec §8 e references/threading-rules.md.

  Determinismo de teste: RunOnce executa um ciclo SINCRONAMENTE; o tempo vem de
  IConnClock injetado (mock avança o relógio sem Sleep). A thread só dorme via
  TEvent.WaitFor, acordando imediatamente em Stop — sem busy-wait.

  Não-deadlock: o GC nunca segura lock de pool enquanto destrói conexões — isso
  é responsabilidade do próprio pool (EvictIdle/EvictZombies fazem snapshot sob
  lock curto e destroem fora dele). O GC apenas dispara essas operações.
}

interface

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Shared.Config,
  Conn4D.Shared.Logger,
  Conn4D.Core.GC,
  Conn4D.Core.Pool,
  Conn4D.Core.Clock;

type
  TConnGarbageCollector = class;

  /// Thread interna de coleta. Referencia o dono SEM refcount (o dono garante
  /// que a thread é parada antes de ser destruído).
  TConnGCThread = class(TThread)
  private
    FOwner:     TConnGarbageCollector;
    FInterval:  Cardinal;
    FWakeEvent: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(const AOwner: TConnGarbageCollector; const AIntervalMs: Cardinal;
      const AWakeEvent: TEvent);
  end;

  TConnGarbageCollector = class(TInterfacedObject, IConnGC)
  private
    FClock:         IConnClock;
    FLogger:        IConnLogger;
    FIntervalMs:    Cardinal;
    FIdleTimeoutMs: Cardinal;
    FMaxLeaseMs:    Cardinal;
    FPools:         TList<IConnPool>;
    FPoolsLock:     TCriticalSection;
    FRunLock:       TCriticalSection;  // serializa ciclos (RunOnce vs thread)
    FThread:        TConnGCThread;
    FWakeEvent:     TEvent;
    function SnapshotPools: TArray<IConnPool>;
  public
    constructor Create(const AGC: TConnGCConfig; const AIdleTimeoutMs, AMaxLeaseMs: Cardinal;
      const AClock: IConnClock = nil; const ALogger: IConnLogger = nil);
    destructor Destroy; override;

    { IConnGC }
    procedure Start;
    procedure Stop;
    procedure RunOnce;
    procedure Register(const APool: IConnPool);
    procedure Unregister(const APool: IConnPool);

    class function New(const AGC: TConnGCConfig; const AIdleTimeoutMs, AMaxLeaseMs: Cardinal;
      const AClock: IConnClock = nil; const ALogger: IConnLogger = nil): IConnGC; static;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Core.SystemClock;

{ TConnGCThread }

constructor TConnGCThread.Create(const AOwner: TConnGarbageCollector; const AIntervalMs: Cardinal;
  const AWakeEvent: TEvent);
begin
  FOwner     := AOwner;
  FInterval  := AIntervalMs;
  FWakeEvent := AWakeEvent;
  inherited Create(False {não suspensa});
end;

procedure TConnGCThread.Execute;
begin
  while not Terminated do
  begin
    // Dorme até o intervalo OU até ser acordada (Stop sinaliza o evento).
    if FWakeEvent.WaitFor(FInterval) = wrSignaled then
      Break;  // acordada para parar
    if Terminated then
      Break;
    FOwner.RunOnce;
  end;
end;

{ TConnGarbageCollector }

class function TConnGarbageCollector.New(const AGC: TConnGCConfig;
  const AIdleTimeoutMs, AMaxLeaseMs: Cardinal; const AClock: IConnClock;
  const ALogger: IConnLogger): IConnGC;
begin
  Result := TConnGarbageCollector.Create(AGC, AIdleTimeoutMs, AMaxLeaseMs, AClock, ALogger);
end;

constructor TConnGarbageCollector.Create(const AGC: TConnGCConfig;
  const AIdleTimeoutMs, AMaxLeaseMs: Cardinal; const AClock: IConnClock; const ALogger: IConnLogger);
begin
  inherited Create;
  if AClock <> nil then FClock := AClock else FClock := TConnSystemClock.New;
  if ALogger <> nil then FLogger := ALogger else FLogger := TNullLogger.New;
  FIntervalMs    := AGC.Interval;
  FIdleTimeoutMs := AIdleTimeoutMs;
  FMaxLeaseMs    := AMaxLeaseMs;
  FPools         := TList<IConnPool>.Create;
  FPoolsLock     := TCriticalSection.Create;
  FRunLock       := TCriticalSection.Create;
  FWakeEvent     := TEvent.Create(nil, False {AutoReset}, False, '');
end;

destructor TConnGarbageCollector.Destroy;
begin
  Stop;  // garante thread parada antes de liberar
  FWakeEvent.Free;
  FRunLock.Free;
  FPoolsLock.Free;
  FPools.Free;
  inherited;
end;

procedure TConnGarbageCollector.Start;
begin
  if FThread <> nil then
    Exit;  // já rodando
  if FIntervalMs = 0 then
    FIntervalMs := 30000;
  FWakeEvent.ResetEvent;
  FThread := TConnGCThread.Create(Self, FIntervalMs, FWakeEvent);
  FLogger.Info(Format('GC started (interval=%d ms)', [FIntervalMs]));
end;

procedure TConnGarbageCollector.Stop;
begin
  if FThread = nil then
    Exit;
  FThread.Terminate;
  FWakeEvent.SetEvent;   // acorda a thread imediatamente
  FThread.WaitFor;
  FThread.Free;
  FThread := nil;
  FLogger.Info('GC stopped');
end;

function TConnGarbageCollector.SnapshotPools: TArray<IConnPool>;
begin
  FPoolsLock.Enter;
  try
    Result := FPools.ToArray;
  finally
    FPoolsLock.Leave;
  end;
end;

procedure TConnGarbageCollector.RunOnce;
var
  Pools: TArray<IConnPool>;
  Pool:  IConnPool;
begin
  // Serializa para que um RunOnce manual (teste) não colida com o da thread.
  FRunLock.Enter;
  try
    Pools := SnapshotPools;
    for Pool in Pools do
    begin
      try
        Pool.EvictZombies(FMaxLeaseMs);  // mata vazamentos primeiro
        Pool.EvictIdle(FIdleTimeoutMs);  // depois evicta ociosas
      except
        on E: Exception do
          FLogger.Error(Format('GC cycle error on a pool: %s', [E.Message]));
      end;
    end;
  finally
    FRunLock.Leave;
  end;
end;

procedure TConnGarbageCollector.Register(const APool: IConnPool);
begin
  if APool = nil then
    Exit;
  FPoolsLock.Enter;
  try
    if not FPools.Contains(APool) then
      FPools.Add(APool);
  finally
    FPoolsLock.Leave;
  end;
end;

procedure TConnGarbageCollector.Unregister(const APool: IConnPool);
begin
  FPoolsLock.Enter;
  try
    FPools.Remove(APool);
  finally
    FPoolsLock.Leave;
  end;
end;

end.
