unit Conn4D.Core.ThreadSafeQueue;

{
  Conn4D — Core / Services / ThreadSafeQueue

  TConnThreadSafeQueue<T>: fila FIFO de espera, thread-safe, SEM busy-wait
  (ver references/threading-rules.md). Combina TCriticalSection (exclusão) com
  TEvent manual-reset (sinalização de "há item"). Dequeue bloqueia até o item
  chegar ou o timeout estourar, sem consumir CPU enquanto espera.
}

interface

uses
  System.Generics.Collections,
  System.SyncObjs;

const
  cInfinite = Cardinal($FFFFFFFF);

type
  TConnThreadSafeQueue<T> = class
  private
    FLock:     TCriticalSection;
    FItems:    TQueue<T>;
    FNotEmpty: TEvent;  // manual-reset: sinalizado enquanto houver itens
    procedure RefreshSignal; // chamado sob FLock
  public
    constructor Create;
    destructor Destroy; override;

    procedure Enqueue(const AItem: T);
    /// <summary>
    /// Remove o primeiro item esperando até ATimeoutMs. Retorna True e
    /// preenche AItem se obteve; False em timeout. Não faz busy-wait.
    /// </summary>
    function Dequeue(const ATimeoutMs: Cardinal; out AItem: T): Boolean;
    function Count: Integer;
    procedure Clear;
  end;

implementation

uses
  System.Diagnostics;

{ TConnThreadSafeQueue<T> }

constructor TConnThreadSafeQueue<T>.Create;
begin
  inherited Create;
  FLock     := TCriticalSection.Create;
  FItems    := TQueue<T>.Create;
  FNotEmpty := TEvent.Create(nil, True {ManualReset}, False {InitialState}, '');
end;

destructor TConnThreadSafeQueue<T>.Destroy;
begin
  FNotEmpty.Free;
  FItems.Free;
  FLock.Free;
  inherited;
end;

procedure TConnThreadSafeQueue<T>.RefreshSignal;
begin
  if FItems.Count > 0 then
    FNotEmpty.SetEvent
  else
    FNotEmpty.ResetEvent;
end;

procedure TConnThreadSafeQueue<T>.Enqueue(const AItem: T);
begin
  FLock.Enter;
  try
    FItems.Enqueue(AItem);
    RefreshSignal;
  finally
    FLock.Leave;
  end;
end;

function TConnThreadSafeQueue<T>.Dequeue(const ATimeoutMs: Cardinal; out AItem: T): Boolean;
var
  SW:        TStopwatch;
  Remaining: Int64;
  WaitRes:   TWaitResult;
begin
  SW := TStopwatch.StartNew;
  repeat
    FLock.Enter;
    try
      if FItems.Count > 0 then
      begin
        AItem := FItems.Dequeue;
        RefreshSignal;
        Exit(True);
      end;
    finally
      FLock.Leave;
    end;

    if ATimeoutMs = cInfinite then
      Remaining := cInfinite
    else
    begin
      Remaining := Int64(ATimeoutMs) - SW.ElapsedMilliseconds;
      if Remaining <= 0 then
        Exit(False);
    end;

    WaitRes := FNotEmpty.WaitFor(Cardinal(Remaining));
    if WaitRes = wrTimeout then
      Exit(False);
    // wrSignaled: outro thread pode ter tirado o item antes; o laço revalida.
  until False;
end;

function TConnThreadSafeQueue<T>.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FItems.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TConnThreadSafeQueue<T>.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
    RefreshSignal;
  finally
    FLock.Leave;
  end;
end;

end.
