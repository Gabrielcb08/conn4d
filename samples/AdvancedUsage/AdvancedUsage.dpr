program AdvancedUsage;

// Demonstrates advanced Conn4D v0.3 patterns:
//   1. DemoTransaction          — acquire, begin tx, commit
//   2. DemoAutoRollback         — RAII: tx abandoned without Commit → auto-rollback
//   3. DemoExplicitRollback     — Rollback, state transitions, Commit after Rollback raises
//   4. DemoAcquireOnly          — handle without transaction (DDL / ad-hoc SELECT)
//   5. DemoImplicitAndExplicit  — both cast styles on the same handle
//   6. DemoTwoPoolsConcurrent   — two independent pools accessed from parallel tasks

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Threading,
  System.IniFiles,
  FireDAC.Comp.Client,
  FireDAC.DApt,
  FireDAC.Stan.Async,
  FireDAC.Phys.FB,
  FireDAC.Stan.Def,
  FireDAC.Stan.Param,
  FireDAC.ConsoleUI.Wait,
  Conn4D,
  Conn4D.Domain.Types,
  Conn4D.Domain.Exceptions;

const
  CPool          = 'advanced';
  CSecondPool    = 'advanced-b';
  CTargetProduct = 1;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function TxStateStr(const AState: TConn4DTxState): string;
const
  Names: array[TConn4DTxState] of string = ('Active', 'Committed', 'RolledBack', 'Abandoned');
begin
  Result := Names[AState];
end;

procedure ConfigurePoolFromIni(const AIni: TIniFile; const ASection, APoolName: string;
  const ADefaultMaxPoolSize: Integer);
begin
  if TConn4D.PoolExists(APoolName) then
    Exit;

  TConn4D.Configure
    .Pool(APoolName)
      .Host(AIni.ReadString (ASection, 'Host',          '127.0.0.1'))
      .Port(AIni.ReadInteger(ASection, 'Port',          3050))
      .Database(AIni.ReadString (ASection, 'Database',   ''))
      .UserName(AIni.ReadString (ASection, 'UserName',   'SYSDBA'))
      .Password(AIni.ReadString (ASection, 'Password',   ''))
      .MaxPoolSize(AIni.ReadInteger(ASection, 'MaxPoolSize',    ADefaultMaxPoolSize))
      .AcquireTimeout(AIni.ReadInteger(ASection, 'AcquireTimeout', 10000))
      .AddParam('Protocol', AIni.ReadString(ASection, 'Protocol', 'TCPIP'))
    .Apply;
end;

procedure ConfigurePools;
var
  Ini    : TIniFile;
  IniPath: string;
begin
  IniPath := ExtractFilePath(ParamStr(0)) + 'settings.ini';
  if not FileExists(IniPath) then
    raise Exception.CreateFmt(
      'settings.ini not found at %s.'#13#10 +
      'Copy settings.example.ini to settings.ini and fill in your connection details.',
      [IniPath]);

  Ini := TIniFile.Create(IniPath);
  try
    ConfigurePoolFromIni(Ini, 'Pool.advanced',   CPool,       4);
    ConfigurePoolFromIni(Ini, 'Pool.advanced-b', CSecondPool, 2);
  finally
    Ini.Free;
  end;
end;

// ---------------------------------------------------------------------------
// 1) Basic transaction — acquire, UPDATE, commit
// ---------------------------------------------------------------------------
procedure DemoTransaction;
var
  Handle: TConn4DHandle;
  Tx    : TConn4DTransaction;
  Q     : TFDQuery;
begin
  Writeln;
  Writeln('=== Demo 1: Basic Transaction (commit) ===');

  Handle := TConn4D.Acquire(CPool);
  Tx     := Handle.BeginTransaction;
  Q      := TFDQuery.Create(nil);
  try
    Q.Connection  := Handle;
    Q.Transaction := Tx;
    Q.SQL.Text    := 'UPDATE PRODUTOS SET DESCRICAO=:d WHERE CODPRODUTO=:id';
    Q.ParamByName('d').AsString   := 'DEMO_1_COMMITTED';
    Q.ParamByName('id').AsInteger := CTargetProduct;
    Q.ExecSQL;
    Writeln(Format('  Updated %d row(s). Committing...', [Q.RowsAffected]));
  finally
    Q.Free;
  end;
  Tx.Commit;
  Writeln(Format('  Tx state after Commit: %s', [TxStateStr(Tx.State)]));
end;

// ---------------------------------------------------------------------------
// 2) RAII auto-rollback — transaction goes out of scope without Commit
// ---------------------------------------------------------------------------
procedure DemoAutoRollback;

  procedure UpdateWithoutCommit;
  var
    Handle: TConn4DHandle;
    Tx    : TConn4DTransaction;
    Q     : TFDQuery;
  begin
    Handle := TConn4D.Acquire(CPool);
    Tx     := Handle.BeginTransaction;
    Q      := TFDQuery.Create(nil);
    try
      Q.Connection  := Handle;
      Q.Transaction := Tx;
      Q.SQL.Text    := 'UPDATE PRODUTOS SET DESCRICAO=:d WHERE CODPRODUTO=:id';
      Q.ParamByName('d').AsString   := 'SHOULD_BE_ROLLED_BACK';
      Q.ParamByName('id').AsInteger := CTargetProduct;
      Q.ExecSQL;
      Writeln(Format('  Updated %d row(s). NOT committing — procedure will return.',
        [Q.RowsAffected]));
    finally
      Q.Free;
    end;
    // Tx leaves scope here: guard refcount → 0 → auto-rollback fires.
  end;

begin
  Writeln;
  Writeln('=== Demo 2: RAII Auto-Rollback (abandoned tx) ===');
  UpdateWithoutCommit;
  Writeln('  Procedure returned — update was rolled back automatically.');
end;

// ---------------------------------------------------------------------------
// 3) Explicit rollback — state transitions
// ---------------------------------------------------------------------------
procedure DemoExplicitRollback;
var
  Handle: TConn4DHandle;
  Tx    : TConn4DTransaction;
begin
  Writeln;
  Writeln('=== Demo 3: Explicit Rollback + state transitions ===');

  Handle := TConn4D.Acquire(CPool);
  Tx     := Handle.BeginTransaction;

  Writeln(Format('  State before Rollback: %s', [TxStateStr(Tx.State)]));
  Tx.Rollback;
  Writeln(Format('  State after  Rollback: %s', [TxStateStr(Tx.State)]));

  // Second Rollback is a no-op (idempotent).
  Tx.Rollback;
  Writeln('  Second Rollback: no-op (idempotent). (ok)');

  // Commit after Rollback must raise.
  try
    Tx.Commit;
    raise Exception.Create('Expected EConn4DTransactionException was not raised!');
  except
    on E: EConn4DTransactionException do
      Writeln(Format('  Commit after Rollback raised %s as expected. (ok)', [E.ClassName]));
  end;
end;

// ---------------------------------------------------------------------------
// 4) Acquire-only — raw connection access without a transaction
//    Useful for DDL statements or tools that manage their own transactions.
// ---------------------------------------------------------------------------
procedure DemoAcquireOnly;
var
  Handle  : TConn4DHandle;
  FDConn  : TFDConnection;
  Q       : TFDQuery;
  Count   : Integer;
begin
  Writeln;
  Writeln('=== Demo 4: Acquire-only (no transaction) ===');

  Handle := TConn4D.Acquire(CPool);
  FDConn := Handle.Connection<TFDConnection>;  // explicit generic cast
  Writeln(Format('  Connected: %s  DriverName: %s',
    [BoolToStr(FDConn.Connected, True), FDConn.DriverName]));

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Handle;  // implicit operator
    Q.SQL.Text   := 'SELECT COUNT(*) AS N FROM PRODUTOS';
    Q.Open;
    Count := Q.FieldByName('N').AsInteger;
  finally
    Q.Free;
  end;
  Writeln(Format('  PRODUTOS row count = %d', [Count]));
  // Handle goes out of scope at end of procedure → returned to pool.
end;

// ---------------------------------------------------------------------------
// 5) Implicit vs explicit cast — both patterns on the same handle
// ---------------------------------------------------------------------------
procedure DemoImplicitAndExplicit;
var
  Handle : TConn4DHandle;
  Tx     : TConn4DTransaction;
  FDConn : TFDConnection;
  FDTx   : TFDTransaction;
begin
  Writeln;
  Writeln('=== Demo 5: Implicit vs explicit cast ===');

  Handle := TConn4D.Acquire(CPool);
  Tx     := Handle.BeginTransaction;

  // Explicit generic form
  FDConn := Handle.Connection<TFDConnection>;
  FDTx   := Tx.Transaction<TFDTransaction>;
  Writeln(Format('  Explicit — TFDConnection: %s  TFDTransaction: %s',
    [FDConn.ClassName, FDTx.ClassName]));

  // Implicit form — let the compiler resolve via class operator
  FDConn := Handle;
  FDTx   := Tx;
  Writeln(Format('  Implicit — TFDConnection: %s  TFDTransaction: %s',
    [FDConn.ClassName, FDTx.ClassName]));

  Tx.Rollback;
end;

// ---------------------------------------------------------------------------
// 6) Two independent pools accessed concurrently from parallel tasks
// ---------------------------------------------------------------------------
procedure DemoTwoPoolsConcurrent;
var
  T1, T2: ITask;
begin
  Writeln;
  Writeln('=== Demo 6: Two pools concurrent ===');

  T1 := TTask.Run(
    procedure
    var
      Handle: TConn4DHandle;
      Tx    : TConn4DTransaction;
      Q     : TFDQuery;
      Val   : Integer;
    begin
      Handle := TConn4D.Acquire(CPool);
      Tx     := Handle.BeginTransaction;
      Q      := TFDQuery.Create(nil);
      try
        Q.Connection  := Handle;
        Q.Transaction := Tx;
        Q.SQL.Text    := 'SELECT 1 AS X FROM RDB$DATABASE';
        Q.Open;
        Val := Q.FieldByName('X').AsInteger;
      finally
        Q.Free;
      end;
      Tx.Commit;
      Writeln(Format('  [pool A] query returned %d', [Val]));
    end);

  T2 := TTask.Run(
    procedure
    var
      Handle: TConn4DHandle;
      Tx    : TConn4DTransaction;
      Q     : TFDQuery;
      Val   : Integer;
    begin
      Handle := TConn4D.Acquire(CSecondPool);
      Tx     := Handle.BeginTransaction;
      Q      := TFDQuery.Create(nil);
      try
        Q.Connection  := Handle;
        Q.Transaction := Tx;
        Q.SQL.Text    := 'SELECT 2 AS X FROM RDB$DATABASE';
        Q.Open;
        Val := Q.FieldByName('X').AsInteger;
      finally
        Q.Free;
      end;
      Tx.Commit;
      Writeln(Format('  [pool B] query returned %d', [Val]));
    end);

  TTask.WaitForAll([T1, T2], 10000);

  Writeln(Format('  Sweep pool A: %d slot(s) reclaimed', [TConn4D.Sweep(CPool)]));
  Writeln(Format('  Sweep pool B: %d slot(s) reclaimed', [TConn4D.Sweep(CSecondPool)]));
end;

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
begin
  try
    ConfigurePools;

    DemoTransaction;
    DemoAutoRollback;
    DemoExplicitRollback;
    DemoAcquireOnly;
    DemoImplicitAndExplicit;
    DemoTwoPoolsConcurrent;

    Writeln;
    Writeln('All demos complete.');

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
