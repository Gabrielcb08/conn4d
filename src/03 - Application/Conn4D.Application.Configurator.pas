unit Conn4D.Application.Configurator;

interface

uses
  Conn4D.Domain.PoolConfig;

type
  TConn4DPoolBuilder = class;

  // Entry point: TConn4D.Configure.Pool('name').Host(...).Apply;
  TConn4DConfigurator = class
  public
    function Pool(const AName: string): TConn4DPoolBuilder;
  end;

  // Fluent builder for a single pool. Call Apply to register it.
  TConn4DPoolBuilder = class
  private
    FConfig: TConn4DPoolConfig;
    FConfigurator: TConn4DConfigurator;
  public
    constructor Create(const AConfigurator: TConn4DConfigurator;
      const AName: string);

    function Host(const AValue: string): TConn4DPoolBuilder;
    function Port(const AValue: Integer): TConn4DPoolBuilder;
    function Database(const AValue: string): TConn4DPoolBuilder;
    function UserName(const AValue: string): TConn4DPoolBuilder;
    function Password(const AValue: string): TConn4DPoolBuilder;
    function DriverID(const AValue: string): TConn4DPoolBuilder;
    function MaxPoolSize(const AValue: Integer): TConn4DPoolBuilder;
    function AcquireTimeout(const AValue: Integer): TConn4DPoolBuilder;
    function IdleTimeout(const AValue: Integer): TConn4DPoolBuilder;
    function SweepInterval(const AValue: Integer): TConn4DPoolBuilder;
    function AddParam(const AKeyValue: string): TConn4DPoolBuilder; overload;
    function AddParam(const AKey, AValue: string): TConn4DPoolBuilder; overload;

    // Validates, then registers the pool in TConn4DPoolRegistry.
    procedure Apply;

    // Allows chaining to another pool after Apply.
    function Pool(const AName: string): TConn4DPoolBuilder;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Application.PoolRegistry;

{ TConn4DConfigurator }

function TConn4DConfigurator.Pool(const AName: string): TConn4DPoolBuilder;
begin
  Result := TConn4DPoolBuilder.Create(Self, AName);
end;

{ TConn4DPoolBuilder }

constructor TConn4DPoolBuilder.Create(const AConfigurator: TConn4DConfigurator;
  const AName: string);
begin
  inherited Create;
  FConfigurator     := AConfigurator;
  FConfig.PoolName  := Trim(AName);
  FConfig.ApplyDefaults;
end;

function TConn4DPoolBuilder.Host(const AValue: string): TConn4DPoolBuilder;
begin FConfig.Host := Trim(AValue); Result := Self; end;

function TConn4DPoolBuilder.Port(const AValue: Integer): TConn4DPoolBuilder;
begin FConfig.Port := AValue; Result := Self; end;

function TConn4DPoolBuilder.Database(const AValue: string): TConn4DPoolBuilder;
begin FConfig.Database := Trim(AValue); Result := Self; end;

function TConn4DPoolBuilder.UserName(const AValue: string): TConn4DPoolBuilder;
begin FConfig.UserName := Trim(AValue); Result := Self; end;

function TConn4DPoolBuilder.Password(const AValue: string): TConn4DPoolBuilder;
begin FConfig.Password := AValue; Result := Self; end;

function TConn4DPoolBuilder.DriverID(const AValue: string): TConn4DPoolBuilder;
begin FConfig.DriverID := Trim(AValue); Result := Self; end;

function TConn4DPoolBuilder.MaxPoolSize(const AValue: Integer): TConn4DPoolBuilder;
begin FConfig.MaxPoolSize := AValue; Result := Self; end;

function TConn4DPoolBuilder.AcquireTimeout(const AValue: Integer): TConn4DPoolBuilder;
begin FConfig.AcquireTimeout := AValue; Result := Self; end;

function TConn4DPoolBuilder.IdleTimeout(const AValue: Integer): TConn4DPoolBuilder;
begin FConfig.IdleTimeout := AValue; Result := Self; end;

function TConn4DPoolBuilder.SweepInterval(const AValue: Integer): TConn4DPoolBuilder;
begin FConfig.SweepInterval := AValue; Result := Self; end;

function TConn4DPoolBuilder.AddParam(const AKeyValue: string): TConn4DPoolBuilder;
var
  Params: TArray<string>;
begin
  Params := FConfig.ExtraParams;
  SetLength(Params, Length(Params) + 1);
  Params[High(Params)] := AKeyValue;
  FConfig.ExtraParams := Params;
  Result := Self;
end;

function TConn4DPoolBuilder.AddParam(const AKey, AValue: string): TConn4DPoolBuilder;
begin
  Result := AddParam(AKey + '=' + AValue);
end;

procedure TConn4DPoolBuilder.Apply;
begin
  FConfig.Validate;
  TConn4DPoolRegistry.Instance.RegisterPool(FConfig);
end;

function TConn4DPoolBuilder.Pool(const AName: string): TConn4DPoolBuilder;
begin
  Apply;
  Result := FConfigurator.Pool(AName);
end;

end.
