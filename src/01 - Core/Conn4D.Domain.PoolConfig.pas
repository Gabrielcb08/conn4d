unit Conn4D.Domain.PoolConfig;

interface

uses
  Conn4D.Domain.Exceptions,
  Conn4D.Domain.Types;

type
  TConn4DPoolConfig = record
    PoolName : string;
    Host : string;
    Port : Integer;
    Database : string;
    UserName : string;
    Password : string;
    DriverID : string;
    MaxPoolSize : Integer;
    AcquireTimeout : Integer;     // ms
    IdleTimeout : Integer;        // ms
    SweepInterval : Integer;      // ms
    ExtraParams : TArray<string>; // 'Key=Value' pairs

    // Fills in default values where the caller left zeros/empty.
    procedure ApplyDefaults;

    // Raises EConn4DConfigException if required fields are missing.
    procedure Validate;
  end;

implementation

uses
  System.SysUtils;

procedure TConn4DPoolConfig.ApplyDefaults;
begin
  if DriverID = '' then
    DriverID := TConn4DDefaults.DefaultDriverID;
  if Port = 0 then
    Port := 3050;
  if MaxPoolSize = 0 then
    MaxPoolSize := TConn4DDefaults.DefaultMaxPoolSize;
  if AcquireTimeout = 0 then
    AcquireTimeout := TConn4DDefaults.DefaultAcquireTimeout;
  if IdleTimeout = 0 then
    IdleTimeout := TConn4DDefaults.DefaultIdleTimeout;
  if SweepInterval = 0 then
    SweepInterval := TConn4DDefaults.DefaultSweepInterval;
end;

procedure TConn4DPoolConfig.Validate;
begin
  if Trim(PoolName) = '' then
    raise EConn4DConfigException.Create('PoolName is required.');
  if Trim(Database) = '' then
    raise EConn4DConfigException.CreateFmt('Pool "%s": Database is required.', [PoolName]);
  if Trim(DriverID) = '' then
    raise EConn4DConfigException.CreateFmt('Pool "%s": DriverID is required.', [PoolName]);
  if MaxPoolSize <= 0 then
    raise EConn4DConfigException.CreateFmt('Pool "%s": MaxPoolSize must be > 0.', [PoolName]);
  if AcquireTimeout <= 0 then
    raise EConn4DConfigException.CreateFmt('Pool "%s": AcquireTimeout must be > 0.', [PoolName]);
end;

end.
