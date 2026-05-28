unit Conn4D.Tests.Domain.PoolConfig;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPoolConfigTest = class
  public
    [Test] procedure Validate_Raises_WhenPoolNameEmpty;
    [Test] procedure Validate_Raises_WhenDatabaseEmpty;
    [Test] procedure Validate_Raises_WhenDriverIDEmpty;
    [Test] procedure Validate_Raises_WhenMaxPoolSizeZero;
    [Test] procedure Validate_Succeeds_WhenAllRequiredFieldsSet;
    [Test] procedure ApplyDefaults_SetsExpectedValues;
  end;

implementation

uses
  Conn4D.Domain.Types,
  Conn4D.Domain.PoolConfig,
  Conn4D.Domain.Exceptions;

procedure TPoolConfigTest.Validate_Raises_WhenPoolNameEmpty;
var
  C: TConn4DPoolConfig;
begin
  C := Default(TConn4DPoolConfig);
  C.Database := 'APP.FDB';
  C.DriverID := 'FB';
  C.MaxPoolSize := 5;
  C.AcquireTimeout := 1000;
  Assert.WillRaise(
    procedure begin C.Validate; end,
    EConn4DConfigException);
end;

procedure TPoolConfigTest.Validate_Raises_WhenDatabaseEmpty;
var
  C: TConn4DPoolConfig;
begin
  C := Default(TConn4DPoolConfig);
  C.PoolName := 'test';
  C.DriverID := 'FB';
  C.MaxPoolSize := 5;
  C.AcquireTimeout := 1000;
  Assert.WillRaise(
    procedure begin C.Validate; end,
    EConn4DConfigException);
end;

procedure TPoolConfigTest.Validate_Raises_WhenDriverIDEmpty;
var
  C: TConn4DPoolConfig;
begin
  C := Default(TConn4DPoolConfig);
  C.PoolName := 'test';
  C.Database := 'APP.FDB';
  C.MaxPoolSize := 5;
  C.AcquireTimeout := 1000;
  Assert.WillRaise(
    procedure begin C.Validate; end,
    EConn4DConfigException);
end;

procedure TPoolConfigTest.Validate_Raises_WhenMaxPoolSizeZero;
var
  C: TConn4DPoolConfig;
begin
  C := Default(TConn4DPoolConfig);
  C.PoolName := 'test';
  C.Database := 'APP.FDB';
  C.DriverID := 'FB';
  C.MaxPoolSize := 0;
  C.AcquireTimeout := 1000;
  Assert.WillRaise(
    procedure begin C.Validate; end,
    EConn4DConfigException);
end;

procedure TPoolConfigTest.Validate_Succeeds_WhenAllRequiredFieldsSet;
var
  C: TConn4DPoolConfig;
begin
  C := Default(TConn4DPoolConfig);
  C.PoolName := 'test';
  C.Database := 'APP.FDB';
  C.DriverID := 'FB';
  C.MaxPoolSize := 5;
  C.AcquireTimeout := 1000;
  Assert.WillNotRaise(
    procedure begin C.Validate; end);
end;

procedure TPoolConfigTest.ApplyDefaults_SetsExpectedValues;
var
  C: TConn4DPoolConfig;
begin
  C := Default(TConn4DPoolConfig);
  C.ApplyDefaults;
  Assert.AreEqual(TConn4DDefaults.DefaultDriverID,       C.DriverID);
  Assert.AreEqual(TConn4DDefaults.DefaultMaxPoolSize,    C.MaxPoolSize);
  Assert.AreEqual(TConn4DDefaults.DefaultAcquireTimeout, C.AcquireTimeout);
  Assert.AreEqual(TConn4DDefaults.DefaultIdleTimeout,    C.IdleTimeout);
  Assert.AreEqual(TConn4DDefaults.DefaultSweepInterval,  C.SweepInterval);
end;

initialization
  TDUnitX.RegisterTestFixture(TPoolConfigTest);

end.
