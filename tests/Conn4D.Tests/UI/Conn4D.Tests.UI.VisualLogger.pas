unit Conn4D.Tests.UI.VisualLogger;

interface

uses
  System.Classes,
  System.SysUtils,
  DUnitX.TestFramework;

type
  TFixtureStartProc = reference to procedure(const AFixtureName: string);
  TTestStartProc    = reference to procedure(const AFixtureName, ATestName: string);
  TTestPassProc     = reference to procedure(const AFixtureName, ATestName: string; const ADurationMs: Int64);
  TTestFailProc     = reference to procedure(const AFixtureName, ATestName, AMessage: string; const ADurationMs: Int64);
  TTestingStartsProc = reference to procedure(const ATestCount: Cardinal);
  TTestingEndsProc   = reference to procedure(const APassed, AFailed, AErrors: Integer; const ATotalMs: Int64);
  TLogProc           = reference to procedure(const AMessage: string);

  TVisualTestLogger = class(TInterfacedObject, ITestLogger)
  private
    FOnTestingStarts : TTestingStartsProc;
    FOnFixtureStart  : TFixtureStartProc;
    FOnTestStart     : TTestStartProc;
    FOnTestPass      : TTestPassProc;
    FOnTestFail      : TTestFailProc;
    FOnTestingEnds   : TTestingEndsProc;
    FOnLog           : TLogProc;

    procedure RunInUI(const AProc: TThreadProcedure);
  public
    { ITestLogger }
    procedure OnTestingStarts(const threadId: TThreadID; testCount, testActiveCount: Cardinal);
    procedure OnStartTestFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
    procedure OnSetupFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
    procedure OnEndSetupFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
    procedure OnBeginTest(const threadId: TThreadID; const Test: ITestInfo);
    procedure OnSetupTest(const threadId: TThreadID; const Test: ITestInfo);
    procedure OnEndSetupTest(const threadId: TThreadID; const Test: ITestInfo);
    procedure OnExecuteTest(const threadId: TThreadID; const Test: ITestInfo);
    procedure OnTestSuccess(const threadId: TThreadID; const Test: ITestResult);
    procedure OnTestError(const threadId: TThreadID; const Error: ITestError);
    procedure OnTestFailure(const threadId: TThreadID; const Failure: ITestError);
    procedure OnTestIgnored(const threadId: TThreadID; const AIgnored: ITestResult);
    procedure OnTestMemoryLeak(const threadId: TThreadID; const Test: ITestResult);
    procedure OnLog(const logType: TLogLevel; const msg: string);
    procedure OnTeardownTest(const threadId: TThreadID; const Test: ITestInfo);
    procedure OnEndTeardownTest(const threadId: TThreadID; const Test: ITestInfo);
    procedure OnEndTest(const threadId: TThreadID; const Test: ITestResult);
    procedure OnTearDownFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
    procedure OnEndTearDownFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
    procedure OnEndTestFixture(const threadId: TThreadID; const results: IFixtureResult);
    procedure OnTestingEnds(const RunResults: IRunResults);

    property OnTestingStartsEvent : TTestingStartsProc read FOnTestingStarts write FOnTestingStarts;
    property OnFixtureStartEvent  : TFixtureStartProc  read FOnFixtureStart  write FOnFixtureStart;
    property OnTestStartEvent     : TTestStartProc     read FOnTestStart     write FOnTestStart;
    property OnTestPassEvent      : TTestPassProc      read FOnTestPass      write FOnTestPass;
    property OnTestFailEvent      : TTestFailProc      read FOnTestFail      write FOnTestFail;
    property OnTestingEndsEvent   : TTestingEndsProc   read FOnTestingEnds   write FOnTestingEnds;
    property OnLogEvent           : TLogProc           read FOnLog           write FOnLog;
  end;

implementation

procedure TVisualTestLogger.RunInUI(const AProc: TThreadProcedure);
begin
  if TThread.CurrentThread.ThreadID = MainThreadID then
    AProc()
  else
    TThread.Synchronize(nil, AProc);
end;

procedure TVisualTestLogger.OnTestingStarts(const threadId: TThreadID; testCount, testActiveCount: Cardinal);
begin
  if Assigned(FOnTestingStarts) then
    RunInUI(
      procedure
      begin
        FOnTestingStarts(testActiveCount);
      end);
end;

procedure TVisualTestLogger.OnStartTestFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
var
  LName: string;
begin
  LName := fixture.Name;
  if Assigned(FOnFixtureStart) then
    RunInUI(
      procedure
      begin
        FOnFixtureStart(LName);
      end);
end;

procedure TVisualTestLogger.OnSetupFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
begin
end;

procedure TVisualTestLogger.OnEndSetupFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
begin
end;

procedure TVisualTestLogger.OnBeginTest(const threadId: TThreadID; const Test: ITestInfo);
var
  LFixture, LTest: string;
begin
  LFixture := Test.Fixture.Name;
  LTest    := Test.Name;
  if Assigned(FOnTestStart) then
    RunInUI(
      procedure
      begin
        FOnTestStart(LFixture, LTest);
      end);
end;

procedure TVisualTestLogger.OnSetupTest(const threadId: TThreadID; const Test: ITestInfo);
begin
end;

procedure TVisualTestLogger.OnEndSetupTest(const threadId: TThreadID; const Test: ITestInfo);
begin
end;

procedure TVisualTestLogger.OnExecuteTest(const threadId: TThreadID; const Test: ITestInfo);
begin
end;

procedure TVisualTestLogger.OnTestSuccess(const threadId: TThreadID; const Test: ITestResult);
var
  LFixture, LTest: string;
  LDuration: Int64;
begin
  LFixture  := Test.Test.Fixture.Name;
  LTest     := Test.Test.Name;
  LDuration := Trunc(Test.Duration.TotalMilliseconds);
  if Assigned(FOnTestPass) then
    RunInUI(
      procedure
      begin
        FOnTestPass(LFixture, LTest, LDuration);
      end);
end;

procedure TVisualTestLogger.OnTestError(const threadId: TThreadID; const Error: ITestError);
var
  LFixture, LTest, LMsg: string;
  LDuration: Int64;
begin
  LFixture  := Error.Test.Fixture.Name;
  LTest     := Error.Test.Name;
  LMsg      := Error.ExceptionClass.ClassName + ': ' + Error.ExceptionMessage;
  LDuration := Trunc(Error.Duration.TotalMilliseconds);
  if Assigned(FOnTestFail) then
    RunInUI(
      procedure
      begin
        FOnTestFail(LFixture, LTest, LMsg, LDuration);
      end);
end;

procedure TVisualTestLogger.OnTestFailure(const threadId: TThreadID; const Failure: ITestError);
var
  LFixture, LTest, LMsg: string;
  LDuration: Int64;
begin
  LFixture  := Failure.Test.Fixture.Name;
  LTest     := Failure.Test.Name;
  LMsg      := Failure.ExceptionMessage;
  LDuration := Trunc(Failure.Duration.TotalMilliseconds);
  if Assigned(FOnTestFail) then
    RunInUI(
      procedure
      begin
        FOnTestFail(LFixture, LTest, LMsg, LDuration);
      end);
end;

procedure TVisualTestLogger.OnTestIgnored(const threadId: TThreadID; const AIgnored: ITestResult);
begin
end;

procedure TVisualTestLogger.OnTestMemoryLeak(const threadId: TThreadID; const Test: ITestResult);
begin
end;

procedure TVisualTestLogger.OnLog(const logType: TLogLevel; const msg: string);
var
  LMsg: string;
begin
  LMsg := msg;
  if Assigned(FOnLog) then
    RunInUI(
      procedure
      begin
        FOnLog(LMsg);
      end);
end;

procedure TVisualTestLogger.OnTeardownTest(const threadId: TThreadID; const Test: ITestInfo);
begin
end;

procedure TVisualTestLogger.OnEndTeardownTest(const threadId: TThreadID; const Test: ITestInfo);
begin
end;

procedure TVisualTestLogger.OnEndTest(const threadId: TThreadID; const Test: ITestResult);
begin
end;

procedure TVisualTestLogger.OnTearDownFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
begin
end;

procedure TVisualTestLogger.OnEndTearDownFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo);
begin
end;

procedure TVisualTestLogger.OnEndTestFixture(const threadId: TThreadID; const results: IFixtureResult);
begin
end;

procedure TVisualTestLogger.OnTestingEnds(const RunResults: IRunResults);
var
  LPassed, LFailed, LErrors: Integer;
  LTotalMs: Int64;
begin
  LPassed  := RunResults.PassCount;
  LFailed  := RunResults.FailureCount;
  LErrors  := RunResults.ErrorCount;
  LTotalMs := Trunc(RunResults.Duration.TotalMilliseconds);
  if Assigned(FOnTestingEnds) then
    RunInUI(
      procedure
      begin
        FOnTestingEnds(LPassed, LFailed, LErrors, LTotalMs);
      end);
end;

end.

