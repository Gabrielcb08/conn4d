unit Conn4D.Infrastructure.FireDAC.ConnectionHandle;

// TConn4DFireDACNativeConnection — implements IConn4DNativeConnection.
// The ONLY unit in the library that may use FireDAC.Comp.Client directly.

interface

uses
  FireDAC.Comp.Client,
  Conn4D.Application.Contracts.IProvider;

type
  TConn4DFireDACNativeConnection = class(TInterfacedObject, IConn4DNativeConnection)
  private
    FConn  : TFDConnection;
    FOwned : Boolean; // True when this object owns FConn lifetime
  public
    // AOwned = True: destructor frees FConn.
    constructor Create(const AConn : TFDConnection; AOwned : Boolean = True);
    destructor Destroy; override;

    function NativeObject : TObject;
    function IsHealthy : Boolean;
    function DriverName : string;
    function CreateTransaction : IInterface; // returns IConn4DNativeTransaction
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Infrastructure.FireDAC.TransactionHandle;

constructor TConn4DFireDACNativeConnection.Create(const AConn : TFDConnection; AOwned : Boolean);
begin
  inherited Create;
  FConn  := AConn;
  FOwned := AOwned;
end;

destructor TConn4DFireDACNativeConnection.Destroy;
begin
  if FOwned then
    FreeAndNil(FConn);
  inherited;
end;

function TConn4DFireDACNativeConnection.NativeObject : TObject;
begin
  Result := FConn;
end;

function TConn4DFireDACNativeConnection.IsHealthy : Boolean;
begin
  Result := Assigned(FConn) and FConn.Connected;
  if not Result then
    Exit;
  try
    FConn.Ping;
    Result := True;
  except
    Result := False;
  end;
end;

function TConn4DFireDACNativeConnection.DriverName : string;
begin
  Result := 'FireDAC';
end;

function TConn4DFireDACNativeConnection.CreateTransaction : IInterface;
begin
  Result := TConn4DFireDACNativeTransaction.Create(FConn);
end;

end.
