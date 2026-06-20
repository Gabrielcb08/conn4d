unit Conn4D.Mock.Engine;

{
  Conn4D — Tests / Mocks / Engine

  TMockEngine: IConnEngine 100% em memória, sem banco real (exigência da spec
  §14 — Core testável com engine mockado). A "conexão nativa" é um TMockNative
  que rastreia aberto/fechado/transação e pode ser configurado para falhar ou
  ficar "doente" (para testar health check e zombies).

  Contadores expõem quantas conexões foram criadas/destruídas, permitindo
  asserts sobre o ciclo de vida sem tocar I/O.
}

interface

uses
  System.SyncObjs,
  Conn4D.Core.Engine,
  Conn4D.Core,
  Conn4D.Shared.Types;

type
  /// Conexão nativa falsa.
  TMockNative = class
  public
    Opened:    Boolean;
    InTx:      Boolean;
    Healthy:   Boolean;
    Serial:    Integer;   // identifica a instância nos asserts
    constructor Create(const ASerial: Integer);
  end;

  TMockEngine = class(TInterfacedObject, IConnEngine)
  private
    FLock:           TCriticalSection;
    FEngineID:       string;
    FCreatedCount:   Integer;
    FDestroyedCount: Integer;
    FSerialSeq:      Integer;
    FFailOpen:       Boolean;
    FNextUnhealthy:  Boolean;
  public
    constructor Create(const AEngineID: string = 'mock');
    destructor Destroy; override;

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

    // Controles de teste
    procedure SetFailOpen(const AValue: Boolean);
    procedure MakeNextUnhealthy;

    property CreatedCount: Integer read FCreatedCount;
    property DestroyedCount: Integer read FDestroyedCount;
    function LiveCount: Integer;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Shared.Exceptions;

{ TMockNative }

constructor TMockNative.Create(const ASerial: Integer);
begin
  inherited Create;
  Serial  := ASerial;
  Healthy := True;
end;

{ TMockEngine }

constructor TMockEngine.Create(const AEngineID: string);
begin
  inherited Create;
  FLock     := TCriticalSection.Create;
  FEngineID := AEngineID;
end;

destructor TMockEngine.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TMockEngine.EngineID: string;
begin
  Result := FEngineID;
end;

function TMockEngine.CreateNative(const ACfg: IConnConfig): TObject;
var
  N: TMockNative;
begin
  FLock.Enter;
  try
    Inc(FSerialSeq);
    N := TMockNative.Create(FSerialSeq);
    if FNextUnhealthy then
    begin
      N.Healthy := False;
      FNextUnhealthy := False;
    end;
    Inc(FCreatedCount);
    Result := N;
  finally
    FLock.Leave;
  end;
end;

procedure TMockEngine.OpenNative(const ANative: TObject);
begin
  if FFailOpen then
    raise EConn4DEngineException.Create('Mock: forced open failure');
  TMockNative(ANative).Opened := True;
end;

procedure TMockEngine.CloseNative(const ANative: TObject);
begin
  TMockNative(ANative).Opened := False;
end;

procedure TMockEngine.DestroyNative(const ANative: TObject);
begin
  if ANative = nil then
    Exit;
  FLock.Enter;
  try
    Inc(FDestroyedCount);
  finally
    FLock.Leave;
  end;
  ANative.Free;
end;

function TMockEngine.Ping(const ANative: TObject): Boolean;
begin
  Result := TMockNative(ANative).Opened and TMockNative(ANative).Healthy;
end;

procedure TMockEngine.BeginTx(const ANative: TObject; const AIsolation: TConnIsolation);
begin
  TMockNative(ANative).InTx := True;
end;

procedure TMockEngine.CommitTx(const ANative: TObject);
begin
  TMockNative(ANative).InTx := False;
end;

procedure TMockEngine.RollbackTx(const ANative: TObject);
begin
  TMockNative(ANative).InTx := False;
end;

function TMockEngine.InTx(const ANative: TObject): Boolean;
begin
  Result := TMockNative(ANative).InTx;
end;

procedure TMockEngine.SetFailOpen(const AValue: Boolean);
begin
  FFailOpen := AValue;
end;

procedure TMockEngine.MakeNextUnhealthy;
begin
  FNextUnhealthy := True;
end;

function TMockEngine.LiveCount: Integer;
begin
  FLock.Enter;
  try
    Result := FCreatedCount - FDestroyedCount;
  finally
    FLock.Leave;
  end;
end;

end.
