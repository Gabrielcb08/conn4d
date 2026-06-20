unit Conn4D.Core.Semaphore;

{
  Conn4D — Core / Services / Semaphore

  TConnSemaphore: limita a no máximo `poolSize` threads simultâneas dentro da
  região de empréstimo (ver references/threading-rules.md). É o lock MAIS
  externo da ordem fixa de aquisição:

      1. Semaphore.WaitFor   <-- aqui
      2. PoolStore lock
      3. ThreadContext lock

  Wrapper fino sobre o semáforo do SO: CreateSemaphore (Windows) / sem_t (Posix).
  WaitFor honra timeout e nunca bloqueia para sempre.
}

interface

type
  TConnSemaphore = class
  private
{$IFDEF MSWINDOWS}
    FHandle: THandle;
{$ENDIF}
{$IFDEF POSIX}
    FSem: Pointer;  // ^sem_t
{$ENDIF}
    FMaxCount: Integer;
  public
    /// <summary>Cria o semáforo com contagem inicial = máxima = AMaxCount.</summary>
    constructor Create(const AMaxCount: Integer);
    destructor Destroy; override;

    /// <summary>
    /// Tenta adquirir uma permissão dentro de ATimeoutMs. Retorna True se
    /// adquiriu; False ao estourar o tempo (o chamador deve então lançar
    /// EConn4DTimeoutException). Use INFINITE ($FFFFFFFF) para esperar sem fim.
    /// </summary>
    function WaitFor(const ATimeoutMs: Cardinal): Boolean;

    /// <summary>Libera uma permissão previamente adquirida.</summary>
    procedure Release;

    property MaxCount: Integer read FMaxCount;
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
{$IFDEF POSIX}
  Posix.Semaphore,
  Posix.Time,
  Posix.Errno,
  Posix.SysTypes,
{$ENDIF}
  System.SysUtils;

{ TConnSemaphore }

constructor TConnSemaphore.Create(const AMaxCount: Integer);
begin
  inherited Create;
  if AMaxCount < 1 then
    raise EArgumentOutOfRangeException.Create('TConnSemaphore: AMaxCount must be >= 1');
  FMaxCount := AMaxCount;
{$IFDEF MSWINDOWS}
  FHandle := CreateSemaphore(nil, AMaxCount, AMaxCount, nil);
  if FHandle = 0 then
    RaiseLastOSError;
{$ENDIF}
{$IFDEF POSIX}
  GetMem(FSem, SizeOf(sem_t));
  if sem_init(psem_t(FSem)^, 0, AMaxCount) <> 0 then
  begin
    FreeMem(FSem);
    FSem := nil;
    RaiseLastOSError;
  end;
{$ENDIF}
end;

destructor TConnSemaphore.Destroy;
begin
{$IFDEF MSWINDOWS}
  if FHandle <> 0 then
    CloseHandle(FHandle);
{$ENDIF}
{$IFDEF POSIX}
  if FSem <> nil then
  begin
    sem_destroy(psem_t(FSem)^);
    FreeMem(FSem);
  end;
{$ENDIF}
  inherited;
end;

function TConnSemaphore.WaitFor(const ATimeoutMs: Cardinal): Boolean;
{$IFDEF MSWINDOWS}
begin
  Result := WaitForSingleObject(FHandle, ATimeoutMs) = WAIT_OBJECT_0;
end;
{$ENDIF}
{$IFDEF POSIX}
var
  TS: timespec;
  Res: Integer;
begin
  if ATimeoutMs = INFINITE then
  begin
    repeat
      Res := sem_wait(psem_t(FSem)^);
    until (Res = 0) or (errno <> EINTR);
    Exit(Res = 0);
  end;

  clock_gettime(CLOCK_REALTIME, @TS);
  Inc(TS.tv_sec, ATimeoutMs div 1000);
  Inc(TS.tv_nsec, Int64(ATimeoutMs mod 1000) * 1000000);
  if TS.tv_nsec >= 1000000000 then
  begin
    Inc(TS.tv_sec);
    Dec(TS.tv_nsec, 1000000000);
  end;

  repeat
    Res := sem_timedwait(psem_t(FSem)^, TS);
  until (Res = 0) or (errno <> EINTR);
  Result := Res = 0;
end;
{$ENDIF}

procedure TConnSemaphore.Release;
begin
{$IFDEF MSWINDOWS}
  if not ReleaseSemaphore(FHandle, 1, nil) then
    RaiseLastOSError;
{$ENDIF}
{$IFDEF POSIX}
  if sem_post(psem_t(FSem)^) <> 0 then
    RaiseLastOSError;
{$ENDIF}
end;

end.
