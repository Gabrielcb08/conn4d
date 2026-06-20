unit Conn4D.Engine.Zeos;

{$I Conn4D.inc}

{
  Conn4D — Adapter / Zeos / Engine

  TZeosEngine: implementação de IConnEngine para o driver ZeosLib. Uma das duas
  únicas units que conhecem Zeos (a outra é Conn4D.Adapter.Zeos).

  ATENÇÃO: requer ZeosLib no caminho de compilação. Não compilado no ambiente
  atual (Zeos ausente); validar ao integrar. Segue exatamente o padrão de
  references/add-engine.md.
}

interface

{$IFDEF CONN4D_ZEOS}

uses
  ZConnection,
  Conn4D.Core.Engine,
  Conn4D.Core,
  Conn4D.Shared.Types;

type
  TZeosEngine = class(TInterfacedObject, IConnEngine)
  private
    function AsConn(const ANative: TObject): TZConnection;
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

{$IFDEF CONN4D_ZEOS}

uses
  System.SysUtils,
  System.Generics.Collections,
  ZDbcIntfs,
  Conn4D.Shared.Exceptions;

function ZeosProtocolFor(const AProvider: string): string;
var
  P: string;
begin
  P := AProvider.Trim.ToLower;
  if (P = 'firebird') or (P = 'fb') then Exit('firebird');
  if (P = 'interbase') or (P = 'ib') then Exit('interbase');
  if (P = 'postgresql') or (P = 'postgres') or (P = 'pg') then Exit('postgresql');
  if (P = 'mysql') then Exit('mysql');
  if (P = 'mariadb') then Exit('mariadb');
  if (P = 'sqlserver') or (P = 'mssql') then Exit('mssql');
  if (P = 'sqlite') then Exit('sqlite');
  if (P = 'oracle') then Exit('oracle');
  Result := P;  // assume já ser um protocolo Zeos válido
end;

function IsolationFor(const AIso: TConnIsolation): TZTransactIsolationLevel;
begin
  case AIso of
    ciReadUncommitted: Result := tiReadUncommitted;
    ciReadCommitted:   Result := tiReadCommitted;
    ciRepeatableRead:  Result := tiRepeatableRead;
    ciSerializable:    Result := tiSerializable;
    ciSnapshot:        Result := tiSerializable;  // Zeos não tem snapshot
  else
    Result := tiNone;
  end;
end;

{ TZeosEngine }

class function TZeosEngine.New: IConnEngine;
begin
  Result := TZeosEngine.Create;
end;

function TZeosEngine.AsConn(const ANative: TObject): TZConnection;
begin
  if not (ANative is TZConnection) then
    raise EConn4DCastException.CreateFmt(
      'Zeos engine received an incompatible native type: %s', [string(ANative.ClassName)]);
  Result := TZConnection(ANative);
end;

function TZeosEngine.EngineID: string;
begin
  Result := 'zeos';
end;

function TZeosEngine.CreateNative(const ACfg: IConnConfig): TObject;
var
  Conn: TZConnection;
  Pair: TPair<string, string>;
begin
  Conn := TZConnection.Create(nil);
  try
    Conn.Protocol := ZeosProtocolFor(ACfg.Provider);
    Conn.HostName := ACfg.Host;
    if ACfg.Port > 0 then
      Conn.Port := ACfg.Port;
    Conn.Database := ACfg.Database;
    Conn.User     := ACfg.UserName;
    Conn.Password := ACfg.Password;
    for Pair in ACfg.Extra do
      Conn.Properties.Values[Pair.Key] := Pair.Value;
  except
    Conn.Free;
    raise;
  end;
  Result := Conn;
end;

procedure TZeosEngine.OpenNative(const ANative: TObject);
begin
  try
    AsConn(ANative).Connect;
  except
    on E: Exception do
      raise EConn4DEngineException.CreateFmt('Zeos connect failed: %s', [E.Message]);
  end;
end;

procedure TZeosEngine.CloseNative(const ANative: TObject);
begin
  AsConn(ANative).Disconnect;
end;

procedure TZeosEngine.DestroyNative(const ANative: TObject);
begin
  if ANative <> nil then
    AsConn(ANative).Free;
end;

function TZeosEngine.Ping(const ANative: TObject): Boolean;
var
  Conn: TZConnection;
begin
  Conn := AsConn(ANative);
  try
    Result := Conn.Connected and Conn.Ping;
  except
    Result := False;
  end;
end;

procedure TZeosEngine.BeginTx(const ANative: TObject; const AIsolation: TConnIsolation);
var
  Conn: TZConnection;
begin
  Conn := AsConn(ANative);
  try
    Conn.TransactIsolationLevel := IsolationFor(AIsolation);
    Conn.StartTransaction;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('Zeos StartTransaction failed: %s', [E.Message]);
  end;
end;

procedure TZeosEngine.CommitTx(const ANative: TObject);
begin
  try
    AsConn(ANative).Commit;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('Zeos Commit failed: %s', [E.Message]);
  end;
end;

procedure TZeosEngine.RollbackTx(const ANative: TObject);
begin
  try
    AsConn(ANative).Rollback;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('Zeos Rollback failed: %s', [E.Message]);
  end;
end;

function TZeosEngine.InTx(const ANative: TObject): Boolean;
begin
  Result := AsConn(ANative).InTransaction;
end;

{$ENDIF}

end.
