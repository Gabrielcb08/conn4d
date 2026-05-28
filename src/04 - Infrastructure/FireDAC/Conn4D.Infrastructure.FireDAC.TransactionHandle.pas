unit Conn4D.Infrastructure.FireDAC.TransactionHandle;

// TConn4DFireDACNativeTransaction — implements IConn4DNativeTransaction.
// Creates, starts, commits, and rolls back a TFDTransaction.

interface

uses
  FireDAC.Comp.Client,
  Conn4D.Application.Contracts.IProvider;

type
  TConn4DFireDACNativeTransaction = class(TInterfacedObject, IConn4DNativeTransaction)
  private
    FTx   : TFDTransaction;
    FConn : TFDConnection;
  public
    // Creates a TFDTransaction linked to AConn and immediately starts it.
    constructor Create(const AConn : TFDConnection);
    destructor Destroy; override;

    function NativeObject : TObject;
    function IsActive : Boolean;
    procedure Commit;
    procedure Rollback;
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Stan.Def;

constructor TConn4DFireDACNativeTransaction.Create(const AConn : TFDConnection);
begin
  inherited Create;
  FConn          := AConn;
  FTx            := TFDTransaction.Create(nil);
  FTx.Connection := FConn;
  FTx.StartTransaction;
end;

destructor TConn4DFireDACNativeTransaction.Destroy;
begin
  try
    if Assigned(FTx) and FTx.Active then
      FTx.Rollback;
  except
  end;
  FreeAndNil(FTx);
  inherited;
end;

function TConn4DFireDACNativeTransaction.NativeObject : TObject;
begin
  Result := FTx;
end;

function TConn4DFireDACNativeTransaction.IsActive : Boolean;
begin
  Result := Assigned(FTx) and FTx.Active;
end;

procedure TConn4DFireDACNativeTransaction.Commit;
begin
  FTx.Commit;
end;

procedure TConn4DFireDACNativeTransaction.Rollback;
begin
  if FTx.Active then
    FTx.Rollback;
end;

end.
