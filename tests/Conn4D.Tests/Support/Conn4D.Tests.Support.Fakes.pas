unit Conn4D.Tests.Support.Fakes;

// Fake provider and connection for unit tests.
// No real database required.

interface

uses
  System.SysUtils,
  Conn4D.Domain.PoolConfig,
  Conn4D.Application.Contracts.IProvider;

type
  // Minimal fake native connection — no driver, always healthy by default.
  TFakeNativeConnection = class(TInterfacedObject, IConn4DNativeConnection)
  private
    FHealthy: Boolean;
    FTxCount: Integer;
  public
    constructor Create(AHealthy: Boolean = True);
    function NativeObject: TObject;
    function IsHealthy: Boolean;
    function DriverName: string;
    function CreateTransaction: IInterface;

    procedure SetHealthy(AValue: Boolean);
    property TxCount: Integer read FTxCount;
  end;

  // Minimal fake native transaction — records Commit/Rollback calls.
  TFakeNativeTransaction = class(TInterfacedObject, IConn4DNativeTransaction)
  private
    FActive    : Boolean;
    FCommits   : Integer;
    FRollbacks : Integer;
  public
    constructor Create;
    function  NativeObject: TObject;
    function  IsActive: Boolean;
    procedure Commit;
    procedure Rollback;

    property Commits   : Integer read FCommits;
    property Rollbacks : Integer read FRollbacks;
  end;

  // Fake provider: creates TFakeNativeConnection instances.
  TFakeProvider = class(TInterfacedObject, IConn4DProvider)
  private
    FCreateCount  : Integer;
    FDestroyCount : Integer;
    FNextHealthy  : Boolean;
  public
    constructor Create;
    function  DriverName: string;
    function  Supports(const ADriverID: string): Boolean;
    function  CreateConnection(const AConfig: TConn4DPoolConfig): IConn4DNativeConnection;
    procedure EnsureConnected(const AConn: IConn4DNativeConnection;
      const AConfig: TConn4DPoolConfig);
    function  IsHealthy(const AConn: IConn4DNativeConnection): Boolean;
    procedure DestroyConnection(var AConn: IConn4DNativeConnection);

    procedure SetNextConnectionHealth(AHealthy: Boolean);
    property CreateCount  : Integer read FCreateCount;
    property DestroyCount : Integer read FDestroyCount;
  end;

implementation

{ TFakeNativeTransaction }

constructor TFakeNativeTransaction.Create;
begin
  inherited;
  FActive := True;
end;

function TFakeNativeTransaction.NativeObject: TObject;
begin
  Result := Self;
end;

function TFakeNativeTransaction.IsActive: Boolean;
begin
  Result := FActive;
end;

procedure TFakeNativeTransaction.Commit;
begin
  FActive := False;
  Inc(FCommits);
end;

procedure TFakeNativeTransaction.Rollback;
begin
  if FActive then
  begin
    FActive := False;
    Inc(FRollbacks);
  end;
end;

{ TFakeNativeConnection }

constructor TFakeNativeConnection.Create(AHealthy: Boolean);
begin
  inherited Create;
  FHealthy := AHealthy;
end;

function TFakeNativeConnection.NativeObject: TObject;
begin
  Result := Self;
end;

function TFakeNativeConnection.IsHealthy: Boolean;
begin
  Result := FHealthy;
end;

function TFakeNativeConnection.DriverName: string;
begin
  Result := 'Fake';
end;

function TFakeNativeConnection.CreateTransaction: IInterface;
begin
  Inc(FTxCount);
  Result := TFakeNativeTransaction.Create as IConn4DNativeTransaction;
end;

procedure TFakeNativeConnection.SetHealthy(AValue: Boolean);
begin
  FHealthy := AValue;
end;

{ TFakeProvider }

constructor TFakeProvider.Create;
begin
  inherited;
  FNextHealthy := True;
end;

function TFakeProvider.DriverName: string;
begin
  Result := 'Fake';
end;

function TFakeProvider.Supports(const ADriverID: string): Boolean;
begin
  Result := True;
end;

function TFakeProvider.CreateConnection(
  const AConfig: TConn4DPoolConfig): IConn4DNativeConnection;
begin
  Inc(FCreateCount);
  Result := TFakeNativeConnection.Create(FNextHealthy);
end;

procedure TFakeProvider.EnsureConnected(const AConn: IConn4DNativeConnection;
  const AConfig: TConn4DPoolConfig);
begin
  // no-op for tests
end;

function TFakeProvider.IsHealthy(const AConn: IConn4DNativeConnection): Boolean;
begin
  Result := AConn.IsHealthy;
end;

procedure TFakeProvider.DestroyConnection(var AConn: IConn4DNativeConnection);
begin
  Inc(FDestroyCount);
  AConn := nil;
end;

procedure TFakeProvider.SetNextConnectionHealth(AHealthy: Boolean);
begin
  FNextHealthy := AHealthy;
end;

end.
