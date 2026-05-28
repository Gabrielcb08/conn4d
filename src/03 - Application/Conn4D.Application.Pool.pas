unit Conn4D.Application.Pool;

interface

uses
  System.Generics.Collections,
  Conn4D.Domain.PoolConfig,
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Contracts.IPool;

type
  TConn4DPool = class(TInterfacedObject, IConn4DPool)
  private type
    TSlot = record
      Conn : IConn4DNativeConnection;
      InUse : Boolean;
      LastActivity : TDateTime;
      UseCount : Integer;
    end;

  private
    FConfig    : TConn4DPoolConfig;
    FProvider  : IConn4DProvider;
    FSlots     : TList<TSlot>;
    FLock      : TObject;
    FNextSweep : TDateTime;

    function CalcRemainingMs(const AStartTick : UInt64) : Cardinal;
    function FindIdleSlot : Integer;
    function CreateAndAddSlot : Integer;
    procedure DiscardSlot(AIndex : Integer);
    function EnsureSlotReady(AIndex : Integer) : Boolean;
    function ExhaustedMessage : string;
  public
    constructor Create(const AConfig : TConn4DPoolConfig; const AProvider : IConn4DProvider);
    destructor Destroy; override;

    function Acquire : IConn4DNativeConnection;
    procedure Release(const AConn : IConn4DNativeConnection);
    function Sweep : Integer;
    function SweepIfDue : Integer;
    function PoolName : string;
    function Config : TConn4DPoolConfig;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  Winapi.Windows,
  Conn4D.Domain.Exceptions;

{ TConn4DPool }

constructor TConn4DPool.Create(const AConfig : TConn4DPoolConfig; const AProvider : IConn4DProvider);
begin
  inherited Create;
  FConfig    := AConfig;
  FProvider  := AProvider;
  FSlots     := TList<TSlot>.Create;
  FLock      := TObject.Create;
  FNextSweep := IncMilliSecond(Now, FConfig.SweepInterval);
end;

destructor TConn4DPool.Destroy;
var
  I    : Integer;
  Conn : IConn4DNativeConnection;
begin
  TMonitor.Enter(FLock);
  try
    for I := FSlots.Count - 1 downto 0 do
    begin
      Conn := FSlots[I].Conn;
      if Assigned(Conn) then
        FProvider.DestroyConnection(Conn);
    end;
    FSlots.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
  FSlots.Free;
  FLock.Free;
  inherited;
end;

function TConn4DPool.CalcRemainingMs(const AStartTick : UInt64) : Cardinal;
var
  Elapsed : UInt64;
begin
  Elapsed := GetTickCount64 - AStartTick;
  if Elapsed >= UInt64(FConfig.AcquireTimeout) then
    Exit(0);
  Result := Cardinal(FConfig.AcquireTimeout) - Cardinal(Elapsed);
end;

function TConn4DPool.ExhaustedMessage : string;
begin
  Result := Format('Pool "%s" exhausted: MaxPoolSize=%d, no connection freed within %d ms.', [FConfig.PoolName, FConfig.MaxPoolSize, FConfig.AcquireTimeout]);
end;

function TConn4DPool.FindIdleSlot : Integer;
var
  I : Integer;
begin
  for I := 0 to FSlots.Count - 1 do
    if not FSlots[I].InUse then
      Exit(I);
  Result := -1;
end;

function TConn4DPool.CreateAndAddSlot : Integer;
var
  Conn : IConn4DNativeConnection;
  Slot : TSlot;
begin
  Conn := FProvider.CreateConnection(FConfig);
  FProvider.EnsureConnected(Conn, FConfig);
  Slot.Conn         := Conn;
  Slot.InUse        := False;
  Slot.LastActivity := Now;
  Slot.UseCount     := 0;
  Result            := FSlots.Add(Slot);
end;

procedure TConn4DPool.DiscardSlot(AIndex : Integer);
var
  Slot : TSlot;
  Conn : IConn4DNativeConnection;
begin
  Slot := FSlots[AIndex];
  FSlots.Delete(AIndex);
  Conn := Slot.Conn;
  if Assigned(Conn) then
    FProvider.DestroyConnection(Conn);
  TMonitor.PulseAll(FLock);
end;

function TConn4DPool.EnsureSlotReady(AIndex : Integer) : Boolean;
var
  Slot : TSlot;
begin
  Slot := FSlots[AIndex];
  try
    FProvider.EnsureConnected(Slot.Conn, FConfig);
    Result := FProvider.IsHealthy(Slot.Conn);
  except
    Result := False;
  end;
  if not Result then
    DiscardSlot(AIndex);
end;

function TConn4DPool.Acquire : IConn4DNativeConnection;
var
  StartTick : UInt64;
  Remaining : Cardinal;
  Idx       : Integer;
  Slot      : TSlot;
begin
  StartTick := GetTickCount64;

  TMonitor.Enter(FLock);
  try
    while True do
    begin
      // Try to reuse an existing idle slot.
      Idx := FindIdleSlot;
      if (Idx >= 0) and EnsureSlotReady(Idx) then
      begin
        Slot              := FSlots[Idx];
        Slot.InUse        := True;
        Slot.LastActivity := Now;
        Inc(Slot.UseCount);
        FSlots[Idx] := Slot;
        Exit(Slot.Conn);
      end;

      // Create a new slot if under the size limit.
      if FSlots.Count < FConfig.MaxPoolSize then
      begin
        Idx        := CreateAndAddSlot;
        Slot       := FSlots[Idx];
        Slot.InUse := True;
        Inc(Slot.UseCount);
        FSlots[Idx] := Slot;
        Exit(Slot.Conn);
      end;

      // All slots in use — wait for a release signal.
      Remaining := CalcRemainingMs(StartTick);
      if Remaining = 0 then
        raise EConn4DPoolExhaustedException.Create(ExhaustedMessage);
      if not TMonitor.Wait(FLock, Remaining) then
        raise EConn4DPoolExhaustedException.Create(ExhaustedMessage);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TConn4DPool.Release(const AConn : IConn4DNativeConnection);
var
  I    : Integer;
  Slot : TSlot;
begin
  TMonitor.Enter(FLock);
  try
    for I := 0 to FSlots.Count - 1 do
    begin
      Slot := FSlots[I];
      if Pointer(Slot.Conn) = Pointer(AConn) then
      begin
        Slot.InUse        := False;
        Slot.LastActivity := Now;
        FSlots[I]         := Slot;
        TMonitor.PulseAll(FLock);
        Exit;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TConn4DPool.Sweep : Integer;
var
  I    : Integer;
  Slot : TSlot;
  Now_ : TDateTime;
begin
  Result := 0;
  Now_   := Now;

  TMonitor.Enter(FLock);
  try
    for I := FSlots.Count - 1 downto 0 do
    begin
      Slot := FSlots[I];
      if Slot.InUse then
        Continue;

      if not FProvider.IsHealthy(Slot.Conn) then
      begin
        DiscardSlot(I);
        Inc(Result);
        Continue;
      end;

      if MilliSecondsBetween(Now_, Slot.LastActivity) >= FConfig.IdleTimeout then
      begin
        DiscardSlot(I);
        Inc(Result);
      end;
    end;
    FNextSweep := IncMilliSecond(Now_, FConfig.SweepInterval);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TConn4DPool.SweepIfDue : Integer;
begin
  TMonitor.Enter(FLock);
  try
    if Now < FNextSweep then
      Exit(0);
  finally
    TMonitor.Exit(FLock);
  end;
  Result := Sweep;
end;

function TConn4DPool.PoolName : string;
begin
  Result := FConfig.PoolName;
end;

function TConn4DPool.Config : TConn4DPoolConfig;
begin
  Result := FConfig;
end;

end.
