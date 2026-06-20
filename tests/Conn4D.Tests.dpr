program Conn4D.Tests;

{
  Conn4D — Runner DUnitX (console).

  Roda toda a suíte do Core com engine/relógio/logger MOCKADOS — sem banco real
  (spec §14). Exit code <> 0 quando há falhas, para uso em CI.
}

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,

  // Shared
  Conn4D.Shared.Types       in '..\src\Shared\Conn4D.Shared.Types.pas',
  Conn4D.Shared.Config      in '..\src\Shared\Conn4D.Shared.Config.pas',
  Conn4D.Shared.Exceptions  in '..\src\Shared\Conn4D.Shared.Exceptions.pas',
  Conn4D.Shared.Logger      in '..\src\Shared\Conn4D.Shared.Logger.pas',

  // Core / Abstractions
  Conn4D.Core.Base          in '..\src\Core\Abstractions\Conn4D.Core.Base.pas',
  Conn4D.Core.Engine        in '..\src\Core\Abstractions\Conn4D.Core.Engine.pas',
  Conn4D.Core.Pool          in '..\src\Core\Abstractions\Conn4D.Core.Pool.pas',
  Conn4D.Core.Transaction   in '..\src\Core\Abstractions\Conn4D.Core.Transaction.pas',
  Conn4D.Core.HealthCheck   in '..\src\Core\Abstractions\Conn4D.Core.HealthCheck.pas',
  Conn4D.Core.Observer      in '..\src\Core\Abstractions\Conn4D.Core.Observer.pas',
  Conn4D.Core.GC            in '..\src\Core\Abstractions\Conn4D.Core.GC.pas',
  Conn4D.Core.Clock         in '..\src\Core\Abstractions\Conn4D.Core.Clock.pas',
  Conn4D.Core.Monitor       in '..\src\Core\Abstractions\Conn4D.Core.Monitor.pas',
  Conn4D.Core        in '..\src\Core\Abstractions\Conn4D.Core.pas',

  // Core / Services
  Conn4D.Core.Config             in '..\src\Core\Services\Conn4D.Core.Config.pas',
  Conn4D.Core.SystemClock        in '..\src\Core\Services\Conn4D.Core.SystemClock.pas',
  Conn4D.Core.Semaphore          in '..\src\Core\Services\Conn4D.Core.Semaphore.pas',
  Conn4D.Core.ThreadSafeQueue    in '..\src\Core\Services\Conn4D.Core.ThreadSafeQueue.pas',
  Conn4D.Core.ThreadContext      in '..\src\Core\Services\Conn4D.Core.ThreadContext.pas',
  Conn4D.Core.PoolStore          in '..\src\Core\Services\Conn4D.Core.PoolStore.pas',
  Conn4D.Core.ObserverBroadcaster in '..\src\Core\Services\Conn4D.Core.ObserverBroadcaster.pas',
  Conn4D.Core.Registry           in '..\src\Core\Services\Conn4D.Core.Registry.pas',
  Conn4D.Core.HealthMonitor      in '..\src\Core\Services\Conn4D.Core.HealthMonitor.pas',
  Conn4D.Core.TransactionMgr     in '..\src\Core\Services\Conn4D.Core.TransactionMgr.pas',
  Conn4D.Core.PoolManager        in '..\src\Core\Services\Conn4D.Core.PoolManager.pas',
  Conn4D.Core.Factory            in '..\src\Core\Services\Conn4D.Core.Factory.pas',
  Conn4D.Core.GarbageCollector   in '..\src\Core\Services\Conn4D.Core.GarbageCollector.pas',

  // Adapter FireDAC + componente + fachada (para o teste do TConn4D)
  Conn4D.Adapter.ConnRef  in '..\src\Adapters\Conn4D.Adapter.ConnRef.pas',
  Conn4D.Adapter.Engines  in '..\src\Adapters\Conn4D.Adapter.Engines.pas',
  Conn4D.Adapter.FireDAC.VendorLib in '..\src\Adapters\FireDAC\Conn4D.Adapter.FireDAC.VendorLib.pas',
  Conn4D.Adapter.FireDAC.Providers in '..\src\Adapters\FireDAC\Conn4D.Adapter.FireDAC.Providers.pas',
  Conn4D.Engine.FireDAC   in '..\src\Adapters\FireDAC\Conn4D.Engine.FireDAC.pas',
  Conn4D.Adapter.FireDAC  in '..\src\Adapters\FireDAC\Conn4D.Adapter.FireDAC.pas',
  Conn4D.Component        in '..\src\Component\Conn4D.Component.pas',
  Conn4D                  in '..\src\Conn4D.pas',

  // Mocks
  Conn4D.Mock.Engine   in 'Mocks\Conn4D.Mock.Engine.pas',
  Conn4D.Mock.Clock    in 'Mocks\Conn4D.Mock.Clock.pas',
  Conn4D.Mock.Logger   in 'Mocks\Conn4D.Mock.Logger.pas',

  // Suites
  Conn4D.Test.Config           in 'Conn4D.Test.Config.pas',
  Conn4D.Test.PoolManager      in 'Conn4D.Test.PoolManager.pas',
  Conn4D.Test.GarbageCollector in 'Conn4D.Test.GarbageCollector.pas',
  Conn4D.Test.ThreadSafety     in 'Conn4D.Test.ThreadSafety.pas',
  Conn4D.Test.Registry         in 'Conn4D.Test.Registry.pas',
  Conn4D.Test.EngineSwap       in 'Conn4D.Test.EngineSwap.pas',
  Conn4D.Test.Component        in 'Conn4D.Test.Component.pas';

var
  Runner:  ITestRunner;
  Results: IRunResults;
begin
  try
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Results := Runner.Execute;
    if not Results.AllPassed then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
