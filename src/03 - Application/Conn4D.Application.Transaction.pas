unit Conn4D.Application.Transaction;

// TConn4DTransaction — value-type RAII transaction handle.
//
// Lifetime: backed by an IConn4DTxGuard interface reference; when the last
// copy goes out of scope the guard destructor auto-rolls back if the
// transaction was never committed (tsAbandoned).
//
// Implicit operator: Delphi infers the driver type from the assignment
// target (e.g. Qry.Transaction := Tx;). Uses FireDAC only for the operator
// declaration — all logic is FireDAC-free.

interface

uses
  FireDAC.Comp.Client,
  Conn4D.Domain.Types,
  Conn4D.Application.Contracts.IProvider;

type
  // Internal guard — reference-counted; destructor auto-rolls back.
  IConn4DTxGuard = interface
    ['{C7E1B4D5-8F3A-4C9D-AE05-7B4C9D6E8F55}']
    function NativeTx : IConn4DNativeTransaction;
    function State : TConn4DTxState;
    procedure SetState(const AState : TConn4DTxState);
    procedure Commit;
    procedure Rollback;
  end;

  TConn4DTransaction = record
  private
    FGuard : IConn4DTxGuard;
  public
    // Explicit generic cast — always available regardless of driver.
    function Transaction<T : class> : T;

    // Implicit conversion to TFDTransaction for direct FireDAC assignment.
    class operator Implicit(const ATx : TConn4DTransaction) : TFDTransaction;

    procedure Commit;
    procedure Rollback;

    function IsActive : Boolean;
    function State : TConn4DTxState;

    // Internal constructor — called by TConn4DHandle.BeginTransaction.
    class function _Create(const AGuard : IConn4DTxGuard) : TConn4DTransaction; static;
  end;

  TConn4DTxGuardImpl = class(TInterfacedObject, IConn4DTxGuard)
  private
    FNative : IConn4DNativeTransaction;
    FState  : TConn4DTxState;
  public
    constructor Create(const ANative : IConn4DNativeTransaction);
    destructor Destroy; override;
    function NativeTx : IConn4DNativeTransaction;
    function State : TConn4DTxState;
    procedure SetState(const AState : TConn4DTxState);
    procedure Commit;
    procedure Rollback;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Domain.Exceptions;

{ TConn4DTxGuardImpl }

constructor TConn4DTxGuardImpl.Create(const ANative : IConn4DNativeTransaction);
begin
  inherited Create;
  FNative := ANative;
  FState  := tsActive;
end;

destructor TConn4DTxGuardImpl.Destroy;
begin
  if FState = tsActive then
  begin
    FState := tsAbandoned;
    try
      FNative.Rollback;
    except
    end;
  end;
  FNative := nil;
  inherited;
end;

function TConn4DTxGuardImpl.NativeTx : IConn4DNativeTransaction;
begin
  Result := FNative;
end;

function TConn4DTxGuardImpl.State : TConn4DTxState;
begin
  Result := FState;
end;

procedure TConn4DTxGuardImpl.SetState(const AState : TConn4DTxState);
begin
  FState := AState;
end;

procedure TConn4DTxGuardImpl.Commit;
begin
  if FState <> tsActive then
    raise EConn4DTransactionException.CreateFmt('Cannot Commit: transaction is in state %d.', [Ord(FState)]);
  FNative.Commit;
  FState := tsCommitted;
end;

procedure TConn4DTxGuardImpl.Rollback;
begin
  if FState = tsActive then
  begin
    FNative.Rollback;
    FState := tsRolledBack;
  end;
  // Idempotent: second call is a no-op.
end;

{ TConn4DTransaction }

class function TConn4DTransaction._Create(const AGuard : IConn4DTxGuard) : TConn4DTransaction;
begin
  Result.FGuard := AGuard;
end;

function TConn4DTransaction.Transaction<T> : T;
begin
  if not Assigned(FGuard) then
    raise EConn4DCastException.Create('TConn4DTransaction is not initialized.');
  try
    Result := FGuard.NativeTx.NativeObject as T;
  except
    on E : EInvalidCast do
      raise EConn4DCastException.CreateFmt('Transaction cast failed: expected %s.', [T.ClassName]);
  end;
end;

class operator TConn4DTransaction.Implicit(const ATx : TConn4DTransaction) : TFDTransaction;
begin
  if not Assigned(ATx.FGuard) then
    raise EConn4DCastException.Create('TConn4DTransaction is not initialized.');
  Result := ATx.FGuard.NativeTx.NativeObject as TFDTransaction;
end;

procedure TConn4DTransaction.Commit;
begin
  if not Assigned(FGuard) then
    raise EConn4DTransactionException.Create('TConn4DTransaction is not initialized.');
  FGuard.Commit;
end;

procedure TConn4DTransaction.Rollback;
begin
  if not Assigned(FGuard) then
    raise EConn4DTransactionException.Create('TConn4DTransaction is not initialized.');
  FGuard.Rollback;
end;

function TConn4DTransaction.IsActive : Boolean;
begin
  Result := Assigned(FGuard) and (FGuard.State = tsActive);
end;

function TConn4DTransaction.State : TConn4DTxState;
begin
  if not Assigned(FGuard) then
    Exit(tsAbandoned);
  Result := FGuard.State;
end;

end.
