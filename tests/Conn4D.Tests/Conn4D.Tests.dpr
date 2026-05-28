program Conn4D.Tests;

uses
  Vcl.Forms,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  DUnitX.TestFramework,
  DUnitX.TestRunner,
  DUnitX.Extensibility,
  DUnitX.Loggers.Console,
  Conn4D.Tests.Support.Fakes
    in 'Support\Conn4D.Tests.Support.Fakes.pas',
  Conn4D.Tests.Domain.PoolConfig
    in 'Domain\Conn4D.Tests.Domain.PoolConfig.pas',
  Conn4D.Tests.Core.Pool
    in 'Core\Conn4D.Tests.Core.Pool.pas',
  Conn4D.Tests.Core.Transaction
    in 'Core\Conn4D.Tests.Core.Transaction.pas',
  Conn4D.Tests.Core.Handle
    in 'Core\Conn4D.Tests.Core.Handle.pas',
  Conn4D.Tests.Integration.Firebird
    in 'Integration\Conn4D.Tests.Integration.Firebird.pas',
  Conn4D.Tests.UI.VisualLogger in 'UI\Conn4D.Tests.UI.VisualLogger.pas',
  Conn4D.Tests.UI.MainForm in 'UI\Conn4D.Tests.UI.MainForm.pas' {frmTestRunner};

{$R *.res}

function HasSwitch(const ASwitch: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), ASwitch) then
      Exit(True);
end;

procedure EnsureConsoleInitialized;
begin
  if not AttachConsole(ATTACH_PARENT_PROCESS) then
    AllocConsole;

  {$I-}
  AssignFile(Input, '');
  Reset(Input);
  AssignFile(Output, '');
  Rewrite(Output);
  AssignFile(ErrOutput, '');
  Rewrite(ErrOutput);
  {$I+}
end;

procedure RunConsoleTests;
var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
begin
  EnsureConsoleInitialized;

  Writeln('Conn4D - Test Suite (Console Mode)');
  Writeln('');

  Runner := TDUnitX.CreateRunner;
  Runner.UseRTTI := True;
  Logger := TDUnitXConsoleLogger.Create(False);
  Runner.AddLogger(Logger);

  try
    Results := Runner.Execute;

    if Results.AllPassed then
    begin
      Writeln(Format('Success: %d tests passed', [Results.TestCount]));
      ExitCode := 0;
    end
    else
    begin
      Writeln(Format('FAILED: %d passed, %d failed, %d errors', [Results.PassCount, Results.FailureCount, Results.ErrorCount]));
      ExitCode := 1;
    end;
  except
    on E: Exception do
    begin
      Writeln('ERROR: ' + E.Message);
      ExitCode := 1;
    end;
  end;

  if HasSwitch('--pause') then
  begin
    Writeln('');
    Writeln('Done... Press <Enter> to close.');
    Readln;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := HasSwitch('--console') and HasSwitch('--leaks');

  if HasSwitch('--console') then
  begin
    RunConsoleTests;
    Exit;
  end;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Conn4D - Test Runner';
  Application.CreateForm(TfrmTestRunner, frmTestRunner);
  Application.Run;
end.
