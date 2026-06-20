unit Conn4D.Engine.FireDAC;

{
  Conn4D — Adapter / FireDAC / Engine

  TFireDACEngine: implementação de IConnEngine para o driver FireDAC. É UMA das
  duas únicas units que conhecem FireDAC (a outra é Conn4D.Adapter.FireDAC).

  Regras (ver references/add-engine.md):
   - O cast TObject -> TFDConnection acontece SÓ aqui, encapsulado em AsConn,
     que lança EConn4DCastException se o tipo nativo não bater.
   - Falhas do driver que precisam subir viram EConn4DEngineException.
   - EngineID é único e estável: 'firedac'.

  Observação de runtime: o app consumidor ainda deve linkar a unit de driver
  física do FireDAC (ex.: FireDAC.Phys.FB) e o FDManager; isso é
  responsabilidade da aplicação, não do engine.
}

interface

uses
  FireDAC.Comp.Client,
  Conn4D.Core.Engine,
  Conn4D.Core,
  Conn4D.Shared.Types;

type
  TFireDACEngine = class(TInterfacedObject, IConnEngine)
  private
    function AsConn(const ANative: TObject): TFDConnection;
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

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Stan.Option,
  FireDAC.Stan.Intf,
  Conn4D.Shared.Exceptions,
  Conn4D.Adapter.FireDAC.Providers;

{ mapeamentos auxiliares }

function DriverIdFor(const AProvider: string): string;
var
  P: string;
begin
  P := AProvider.Trim.ToLower;
  if (P = 'firebird') or (P = 'fb') or (P = 'interbase fb') then Exit('FB');
  if (P = 'interbase') or (P = 'ib') then Exit('IB');
  if (P = 'postgresql') or (P = 'postgres') or (P = 'pg') then Exit('PG');
  if (P = 'mysql') then Exit('MySQL');
  if (P = 'mariadb') then Exit('MySQL');
  if (P = 'sqlserver') or (P = 'mssql') or (P = 'sql server') then Exit('MSSQL');
  if (P = 'sqlite') then Exit('SQLite');
  if (P = 'oracle') or (P = 'ora') then Exit('Ora');
  // Caso não mapeado: assume que o Provider já é um DriverID válido do FireDAC.
  Result := AProvider;
end;

function IsolationFor(const AIso: TConnIsolation): TFDTxIsolation;
begin
  case AIso of
    ciReadUncommitted: Result := xiDirtyRead;
    ciReadCommitted:   Result := xiReadCommitted;
    ciRepeatableRead:  Result := xiRepeatableRead;
    ciSerializable:    Result := xiSerializible;  // (sic) grafia do FireDAC
    ciSnapshot:        Result := xiSnapshot;
  else
    Result := xiUnspecified;
  end;
end;

{ TFireDACEngine }

class function TFireDACEngine.New: IConnEngine;
begin
  Result := TFireDACEngine.Create;
end;

function TFireDACEngine.AsConn(const ANative: TObject): TFDConnection;
begin
  if not (ANative is TFDConnection) then
    raise EConn4DCastException.CreateFmt(
      'FireDAC engine received an incompatible native type: %s',
      [string(ANative.ClassName)]);
  Result := TFDConnection(ANative);
end;

function TFireDACEngine.EngineID: string;
begin
  Result := 'firedac';
end;

function TFireDACEngine.CreateNative(const ACfg: IConnConfig): TObject;
var
  Conn: TFDConnection;
  Pair: TPair<string, string>;
begin
  Conn := TFDConnection.Create(nil);
  try
    Conn.LoginPrompt := False;
    Conn.Params.DriverID := DriverIdFor(ACfg.Provider);
    // Deixa o provider unit (se linkado) configurar o driver link — ex.: apontar
    // o VendorLib (fbclient.dll/libpq.dll/...) por plataforma. No-op se ninguém
    // registrou este DriverID.
    TFDProviders.Apply(Conn.Params.DriverID, ACfg);
    if ACfg.Host <> '' then
      Conn.Params.Values['Server'] := ACfg.Host;
    if ACfg.Port > 0 then
      Conn.Params.Values['Port'] := ACfg.Port.ToString;
    if ACfg.Database <> '' then
      Conn.Params.Database := ACfg.Database;
    if ACfg.UserName <> '' then
      Conn.Params.UserName := ACfg.UserName;
    if ACfg.Password <> '' then
      Conn.Params.Password := ACfg.Password;
    if ACfg.ConnectTimeout > 0 then
      Conn.Params.Values['LoginTimeout'] := (ACfg.ConnectTimeout div 1000).ToString;

    for Pair in ACfg.Extra do                 // parâmetros livres do driver
      Conn.Params.Values[Pair.Key] := Pair.Value;
  except
    Conn.Free;
    raise;
  end;
  Result := Conn;
end;

procedure TFireDACEngine.OpenNative(const ANative: TObject);
begin
  try
    AsConn(ANative).Open;
  except
    on E: Exception do
      raise EConn4DEngineException.CreateFmt('FireDAC open failed: %s', [E.Message]);
  end;
end;

procedure TFireDACEngine.CloseNative(const ANative: TObject);
begin
  AsConn(ANative).Close;
end;

procedure TFireDACEngine.DestroyNative(const ANative: TObject);
begin
  if ANative <> nil then
    AsConn(ANative).Free;
end;

function TFireDACEngine.Ping(const ANative: TObject): Boolean;
var
  Conn: TFDConnection;
begin
  Conn := AsConn(ANative);
  try
    if not Conn.Connected then
      Exit(False);
    Conn.Ping;                 // lança se a conexão morreu
    Result := True;
  except
    Result := False;
  end;
end;

procedure TFireDACEngine.BeginTx(const ANative: TObject; const AIsolation: TConnIsolation);
var
  Conn: TFDConnection;
begin
  Conn := AsConn(ANative);
  try
    Conn.TxOptions.Isolation := IsolationFor(AIsolation);
    Conn.StartTransaction;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('FireDAC StartTransaction failed: %s', [E.Message]);
  end;
end;

procedure TFireDACEngine.CommitTx(const ANative: TObject);
begin
  try
    AsConn(ANative).Commit;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('FireDAC Commit failed: %s', [E.Message]);
  end;
end;

procedure TFireDACEngine.RollbackTx(const ANative: TObject);
begin
  try
    AsConn(ANative).Rollback;
  except
    on E: Exception do
      raise EConn4DTransactionException.CreateFmt('FireDAC Rollback failed: %s', [E.Message]);
  end;
end;

function TFireDACEngine.InTx(const ANative: TObject): Boolean;
begin
  Result := AsConn(ANative).InTransaction;
end;

end.
