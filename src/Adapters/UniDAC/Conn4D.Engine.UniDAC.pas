unit Conn4D.Engine.UniDAC;

{$I Conn4D.inc}

{
  Conn4D — Adapter / UniDAC / Engine

  TUniDACEngine: implementação de IConnEngine para o driver UniDAC (Devart).
  Uma das duas únicas units que conhecem UniDAC (a outra é
  Conn4D.Adapter.UniDAC).

  ATENÇÃO: requer UniDAC no caminho de compilação. Não compilado no ambiente
  atual (UniDAC ausente); validar ao integrar. Os nomes do enum de isolamento
  (TCRIsolationLevel) devem ser confirmados contra a versão instalada.
}

interface

{$IFDEF CONN4D_UNIDAC}

uses
  Uni,
  Conn4D.Core.Engine,
  Conn4D.Core,
  Conn4D.Shared.Types;

type
  TUniDACEngine = class(TInterfacedObject, IConnEngine)
  private
    function AsConn(const ANative: TObject): TUniConnection;
  public
    function EngineID: string;
    function CreateNative(const ACfg: IConnConfig): TObject;
    procedure OpenNative(const ANative: TObject);
    procedure CloseNative(const ANative: TObject);
    procedure DestroyNative(const ANative: TObject);
    function Ping(const ANative: TObject): Boolean;
    procedure BeginTx(const ANative: TObject; const AIsolation: TConnIsolation);
    procedure CommitTx(const ANative: TObject);
    procedure RollbackTx(const ANative: TObject);
    function InTx(const ANative: TObject): Boolean;

    class function New: IConnEngine; static;
  end;

{$ENDIF}

implementation

{$IFDEF CONN4D_UNIDAC}

uses
  System.SysUtils,
  System.Generics.Collections,
  CRAccess,                 // TCRIsolationLevel
  Conn4D.Shared.Exceptions;

function UniProviderFor(const AProvider: string): string;
var
  P: string;
begin
  P := AProvider.Trim.ToLower;
  if (P = 'firebird') or (P = 'fb') then Exit('InterBase');  // UniDAC: provider InterBase atende FB
  if (P = 'interbase') or (P = 'ib') then Exit('InterBase');
  if (P = 'postgresql') or (P = 'postgres') or (P = 'pg') then Exit('PostgreSQL');
  if (P = 'mysql') then Exit('MySQL');
  if (P = 'mariadb') then Exit('MySQL');
  if (P = 'sqlserver') or (P = 'mssql') then Exit('SQL Server');
  if (P = 'sqlite') then Exit('SQLite');
  if (P = 'oracle') then Exit('Oracle');
  Result := AProvider;  // assume ser um ProviderName válido do UniDAC
end;

function IsolationFor(const AIso: TConnIsolation): TCRIsolationLevel;
begin
  case AIso of
    ciReadUncommitted: Result := ilReadUncommitted;
    ciReadCommitted:   Result := ilReadCommitted;
    ciRepeatableRead:  Result := ilRepeatableRead;
    ciSerializable:    Result := ilIsolated;     // verificar nome na versão instalada
    ciSnapshot:        Result := ilSnapshot;
  else
    Result := ilReadCommitted;
  end;
end;

{ TUniDACEngine }

class function TUniDACEngine.New: IConnEngine;
begin
  Result := TUniDACEngine.Create;
end;

function TUniDACEngine.AsConn(const ANative: TObject): TUniConnection;
begin
  if not (ANative is TUniConnection) then
    raise EConn4DCastException.CreateFmt(
      'UniDAC engine received an incompatible native type: %s', [string(ANative.ClassName)]);
  Result := TUniConnection(ANative);
end;

function TUniDACEngine.EngineID: string;
begin
  Result := 'unidac';
end;

function TUniDACEngine.CreateNative(const ACfg: IConnConfig): TObject;
var
  Conn: TUniConnection;
  Pair: TPair<string, string>;
begin
  Conn := TUniConnection.Create(nil);
  try
    Conn.LoginPrompt  := False;
    Conn.ProviderName := UniProviderFor(ACfg.Provider);
    Conn.Server       := ACfg.Host;
    if ACfg.Port > 0 then
      Conn.Port := ACfg.Port;
    Conn.Database := ACfg.Database;
    Conn.Username := ACfg.UserName;
    Conn.Password := ACfg.Password;
    for Pair in ACfg.Extra do
      Conn.SpecificOptions.Values[Pair.Key] := Pair.Value;
  except
    Conn.Free;
    raise;
  end;
  Result := Conn;
end;

procedure TUniDACEngine.OpenNative(const ANative: TObject);
begin
  try
    AsConn(ANative).Connect;
  except
    on E: Exception do
      raise EConn4DEngineException.CreateFmt('UniDAC connect failed: %s', [E.Message]);
  end;
end;

procedure TUniDACEngine.CloseNative(const ANative: TObject);
begin
  AsConn(ANative).Disconnect;
end;

procedure TUniDACEngine.DestroyNative(const ANative: TObject);
begin
  if ANative <> nil then
    AsConn(ANative).Free;
end;

function TUniDACEngine.Ping(const ANative: TObject): Boolean;
var
  Conn: TUniConnection;
begin
  Conn := AsConn(ANative);
  try
    if not Conn.Connected then
      Exit(False);
    Conn.Ping;
    Result := True;
  except
    Result := False;
  end;
end;

procedure TUniDACEngine.BeginTx(const ANative: TObject; const AIsolation: TConnIsolation);
var
  Conn: TUniConnection;
begin
  Conn := AsConn(ANative);
  try
    Conn.IsolationLevel := IsolationFor(AIsolation);
    Conn.StartTransaction;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('UniDAC StartTransaction failed: %s', [E.Message]);
  end;
end;

procedure TUniDACEngine.CommitTx(const ANative: TObject);
begin
  try
    AsConn(ANative).Commit;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('UniDAC Commit failed: %s', [E.Message]);
  end;
end;

procedure TUniDACEngine.RollbackTx(const ANative: TObject);
begin
  try
    AsConn(ANative).Rollback;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('UniDAC Rollback failed: %s', [E.Message]);
  end;
end;

function TUniDACEngine.InTx(const ANative: TObject): Boolean;
begin
  Result := AsConn(ANative).InTransaction;
end;

{$ENDIF}

end.
