program BasicUsage;

// Four concurrent threads each update the same row, then the main thread reads
// the final value back. Demonstrates the v0.3 connection-pool API:
//   TConn4D.Configure  — fluent pool registration
//   TConn4D.Acquire    — returns TConn4DHandle (RAII record)
//   Handle.BeginTransaction — returns TConn4DTransaction (RAII record)
//   Implicit operators  — assign Handle to Q.Connection; Tx to Q.Transaction

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  System.SyncObjs,
  System.IniFiles,
  FireDAC.Comp.Client,
  FireDAC.DApt,
  FireDAC.Stan.Async,
  FireDAC.Phys.FB,
  FireDAC.Stan.Def,
  FireDAC.Stan.Param,
  FireDAC.ConsoleUI.Wait,
  Conn4D;

const
  CPoolName         = 'default';
  CWorkerCount      = 4;
  CTargetProductId  = 1;
  CAcquireTimeoutMs = 15000;
  CStartGateTimeout = 60000;

// ---------------------------------------------------------------------------
// Pool registration
// ---------------------------------------------------------------------------
procedure ConfigurePool;
var
  Ini    : TIniFile;
  IniPath: string;
begin
  if TConn4D.PoolExists(CPoolName) then
    Exit;

  IniPath := ExtractFilePath(ParamStr(0)) + 'settings.ini';
  if not FileExists(IniPath) then
    raise Exception.CreateFmt(
      'settings.ini not found at %s.'#13#10 +
      'Copy settings.example.ini to settings.ini and fill in your connection details.',
      [IniPath]);

  Ini := TIniFile.Create(IniPath);
  try
    TConn4D.Configure
      .Pool(CPoolName)
        .Host(Ini.ReadString ('Database', 'Host',            '127.0.0.1'))
        .Port(Ini.ReadInteger('Database', 'Port',            3050))
        .Database(Ini.ReadString ('Database', 'Database',   ''))
        .UserName(Ini.ReadString ('Database', 'UserName',   'SYSDBA'))
        .Password(Ini.ReadString ('Database', 'Password',   ''))
        .MaxPoolSize(Ini.ReadInteger('Database', 'MaxPoolSize',    CWorkerCount))
        .AcquireTimeout(Ini.ReadInteger('Database', 'AcquireTimeout', CAcquireTimeoutMs))
        .AddParam('Protocol', Ini.ReadString('Database', 'Protocol', 'TCPIP'))
      .Apply;
  finally
    Ini.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Worker — acquires a connection, wraps it in a transaction, updates one row.
// ---------------------------------------------------------------------------
type
  TWorkerResult  = record
    WorkerNumber: Integer;
    Success     : Boolean;
    MessageText : string;
  end;
  PWorkerResult = ^TWorkerResult;

procedure ExecuteWorker(const AWorkerNumber: Integer; const AStartGate: TEvent;
  var AResult: TWorkerResult; var AReadyCount: Integer);
var
  Handle: TConn4DHandle;
  Tx    : TConn4DTransaction;
  Q     : TFDQuery;
begin
  AResult.WorkerNumber := AWorkerNumber;
  try
    TInterlocked.Increment(AReadyCount);

    if AStartGate.WaitFor(CStartGateTimeout) <> wrSignaled then
      raise Exception.CreateFmt('Thread %d: start signal not received.', [AWorkerNumber]);

    Handle := TConn4D.Acquire(CPoolName);
    Tx     := Handle.BeginTransaction;
    Q      := TFDQuery.Create(nil);
    try
      Q.Connection := Handle;   // implicit operator: TConn4DHandle → TFDConnection
      Q.Transaction := Tx;      // implicit operator: TConn4DTransaction → TFDTransaction
      Q.SQL.Text :=
        'UPDATE PRODUTOS SET DESCRICAO = :DESCRICAO WHERE CODPRODUTO = :CODPRODUTO';
      Q.ParamByName('DESCRICAO').AsString   := Format('QUEIJO - THREAD %d', [AWorkerNumber]);
      Q.ParamByName('CODPRODUTO').AsInteger := CTargetProductId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
    Tx.Commit;

    AResult.Success     := True;
    AResult.MessageText := Format('Thread %d: UPDATE committed.', [AWorkerNumber]);
  except
    on E: Exception do
    begin
      if Tx.IsActive then
        Tx.Rollback;
      AResult.Success     := False;
      AResult.MessageText := Format('Thread %d: FAILED — %s: %s',
        [AWorkerNumber, E.ClassName, E.Message]);
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Read back the current value without a transaction (simple SELECT).
// ---------------------------------------------------------------------------
function ReadProductDescription: string;
var
  Handle: TConn4DHandle;
  Q     : TFDQuery;
begin
  Handle := TConn4D.Acquire(CPoolName);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Handle;
    Q.SQL.Text   := 'SELECT DESCRICAO FROM PRODUTOS WHERE CODPRODUTO = :id';
    Q.ParamByName('id').AsInteger := CTargetProductId;
    Q.Open;
    Result := IfThen(Q.Eof, '<not found>', Q.FieldByName('DESCRICAO').AsString);
  finally
    Q.Free;
  end;
  // Handle goes out of scope here → released back to pool.
end;

// ---------------------------------------------------------------------------
// Thread wrapper
// ---------------------------------------------------------------------------
type
  TUpdateWorkerThread = class(TThread)
  private
    FWorkerNumber: Integer;
    FStartGate   : TEvent;
    FResult      : PWorkerResult;
    FReadyCount  : PInteger;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerNumber: Integer; const AStartGate: TEvent;
      AResult: PWorkerResult; AReadyCount: PInteger);
  end;

constructor TUpdateWorkerThread.Create(AWorkerNumber: Integer;
  const AStartGate: TEvent; AResult: PWorkerResult; AReadyCount: PInteger);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerNumber   := AWorkerNumber;
  FStartGate      := AStartGate;
  FResult         := AResult;
  FReadyCount     := AReadyCount;
end;

procedure TUpdateWorkerThread.Execute;
begin
  ExecuteWorker(FWorkerNumber, FStartGate, FResult^, FReadyCount^);
end;

// ---------------------------------------------------------------------------
// Main demo
// ---------------------------------------------------------------------------
procedure RunParallelUpdateDemo;
var
  StartGate  : TEvent;
  Threads    : array[0..CWorkerCount - 1] of TThread;
  Results    : array[0..CWorkerCount - 1] of TWorkerResult;
  ReadyCount : Integer;
  I          : Integer;
begin
  StartGate  := TEvent.Create(nil, True, False, '');
  ReadyCount := 0;
  try
    for I := 0 to High(Threads) do
    begin
      Threads[I] := TUpdateWorkerThread.Create(
        I + 1, StartGate, @Results[I], @ReadyCount);
      Threads[I].Start;
    end;

    while TInterlocked.CompareExchange(ReadyCount, 0, 0) < CWorkerCount do
      Sleep(10);

    Writeln(Format('%d threads ready — firing simultaneous UPDATE on CODPRODUTO=%d...',
      [CWorkerCount, CTargetProductId]));
    StartGate.SetEvent;

    for I := 0 to High(Threads) do
      Threads[I].WaitFor;
  finally
    for I := 0 to High(Threads) do
      Threads[I].Free;
    StartGate.Free;
  end;

  Writeln;
  Writeln('Results:');
  for I := 0 to High(Results) do
    Writeln('  ', Results[I].MessageText);

  Writeln;
  Writeln('Final DESCRICAO in database: ' + ReadProductDescription);
end;

begin
  try
    ConfigurePool;
    RunParallelUpdateDemo;
    TConn4D.Shutdown;
    ReadLn;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ReadLn;
      ExitCode := 1;
    end;
  end;
end.
