unit Conn4D.Core.TransactionMgr;

{
  Conn4D — Core / Services / TransactionMgr

  TConnTransaction: implementa IConnTransaction sobre uma conexão nativa já
  emprestada, delegando Begin/Commit/Rollback ao IConnEngine. Agnóstico de
  driver — o engine traduz o TConnIsolation para o nível do banco.

  Modelo de uso: BeginOn inicia a transação e devolve a interface; o consumidor
  faz Commit/Rollback. Operar uma transação já encerrada lança
  EConn4DTransactionException (o Core nunca falha em silêncio).
}

interface

uses
  Conn4D.Shared.Types,
  Conn4D.Shared.Logger,
  Conn4D.Core.Transaction,
  Conn4D.Core.Engine;

type
  TConnTransaction = class(TInterfacedObject, IConnTransaction)
  private
    FEngine:    IConnEngine;
    FNative:    TObject;
    FLogger:    IConnLogger;
    FId:        TGUID;
    FIsolation: TConnIsolation;
    FActive:    Boolean;
    procedure EnsureActive(const AOperation: string);
  public
    constructor Create(const AEngine: IConnEngine; const ANative: TObject;
      const AIsolation: TConnIsolation; const ALogger: IConnLogger);

    function Id: TGUID;
    procedure Commit;
    procedure Rollback;
    function IsActive: Boolean;
    function Isolation: TConnIsolation;

    /// <summary>Inicia uma transação no engine e devolve o contrato.</summary>
    class function BeginOn(const AEngine: IConnEngine; const ANative: TObject;
      const AIsolation: TConnIsolation; const ALogger: IConnLogger): IConnTransaction; static;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Shared.Exceptions;

{ TConnTransaction }

class function TConnTransaction.BeginOn(const AEngine: IConnEngine; const ANative: TObject;
  const AIsolation: TConnIsolation; const ALogger: IConnLogger): IConnTransaction;
begin
  Result := TConnTransaction.Create(AEngine, ANative, AIsolation, ALogger);
end;

constructor TConnTransaction.Create(const AEngine: IConnEngine; const ANative: TObject;
  const AIsolation: TConnIsolation; const ALogger: IConnLogger);
begin
  inherited Create;
  if AEngine = nil then
    raise EConn4DTransactionException.Create('TConnTransaction: engine is nil');
  if ANative = nil then
    raise EConn4DTransactionException.Create('TConnTransaction: native connection is nil');

  FEngine    := AEngine;
  FNative    := ANative;
  FIsolation := AIsolation;
  if ALogger <> nil then
    FLogger := ALogger
  else
    FLogger := TNullLogger.New;
  CreateGUID(FId);

  FEngine.BeginTx(FNative, FIsolation);
  FActive := True;
  FLogger.Debug(Format('Transaction %s started', [GUIDToString(FId)]));
end;

procedure TConnTransaction.EnsureActive(const AOperation: string);
begin
  if not FActive then
    raise EConn4DTransactionException.CreateFmt(
      '%s on an inactive transaction (%s)', [AOperation, GUIDToString(FId)]);
end;

procedure TConnTransaction.Commit;
begin
  EnsureActive('Commit');
  try
    FEngine.CommitTx(FNative);
  finally
    FActive := False;  // mesmo que falhe, a transação não está mais utilizável
  end;
  FLogger.Debug(Format('Transaction %s committed', [GUIDToString(FId)]));
end;

procedure TConnTransaction.Rollback;
begin
  EnsureActive('Rollback');
  try
    FEngine.RollbackTx(FNative);
  finally
    FActive := False;
  end;
  FLogger.Debug(Format('Transaction %s rolled back', [GUIDToString(FId)]));
end;

function TConnTransaction.Id: TGUID;
begin
  Result := FId;
end;

function TConnTransaction.IsActive: Boolean;
begin
  Result := FActive;
end;

function TConnTransaction.Isolation: TConnIsolation;
begin
  Result := FIsolation;
end;

end.
