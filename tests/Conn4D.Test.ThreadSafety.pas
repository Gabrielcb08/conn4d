unit Conn4D.Test.ThreadSafety;

interface

uses
  DUnitX.TestFramework,
  Conn4D.Core.Engine,
  Conn4D.Core.Pool,
  Conn4D.Mock.Engine;

type
  [TestFixture]
  TThreadSafetyTests = class
  private
    FMock:   TMockEngine;
    FEngine: IConnEngine;
    FPool:   IConnPool;
  public
    [TearDown] procedure TearDown;
    // Invariantes da spec §14: N > poolSize threads nunca obtêm mais que
    // poolSize ativas, nunca recebem a mesma conexão simultaneamente, nunca
    // travam (deadlock).
    [Test] procedure Stress_NeverExceedsPoolSize_NoDuplicates_NoDeadlock;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  Conn4D.Core.Config,
  Conn4D.Core,
  Conn4D.Core.Clock,
  Conn4D.Core.Factory,
  Conn4D.Mock.Clock;

procedure TThreadSafetyTests.TearDown;
begin
  FPool := nil;
  FEngine := nil; FMock := nil;
end;

procedure TThreadSafetyTests.Stress_NeverExceedsPoolSize_NoDuplicates_NoDeadlock;
const
  MaxSize     = 4;
  ThreadCount = 24;
  IterPerThr  = 25;
var
  Cfg:        IConnConfig;
  Tasks:      array of ITask;
  I:          Integer;
  Active:     Integer;
  PeakActive: Integer;
  Violations: Integer;
  InUseLock:  TCriticalSection;
  InUse:      TDictionary<TObject, Boolean>;
  Completed:  Boolean;
begin
  FMock := TMockEngine.Create;
  FEngine := FMock;
  Cfg := TConnConfig.New.MaxSize(MaxSize);
  FPool := TConn4DCoreFactory.CreateManager(FEngine, Cfg, TMockClock.Create(0));

  Active     := 0;
  PeakActive := 0;
  Violations := 0;
  InUseLock  := TCriticalSection.Create;
  InUse      := TDictionary<TObject, Boolean>.Create;
  try
    SetLength(Tasks, ThreadCount);
    for I := 0 to ThreadCount - 1 do
      Tasks[I] := TTask.Run(
        procedure
        var
          K:      Integer;
          Native: TObject;
          Cur:    Integer;
        begin
          for K := 0 to IterPerThr - 1 do
          begin
            Native := FPool.Acquire(5000);
            try
              Cur := TInterlocked.Increment(Active);
              if Cur > MaxSize then
                TInterlocked.Increment(Violations);
              if Cur > PeakActive then
                PeakActive := Cur;  // aproximação; protegida abaixo p/ leitura

              InUseLock.Enter;
              try
                if InUse.ContainsKey(Native) then
                  TInterlocked.Increment(Violations)  // mesma conexão p/ 2 threads
                else
                  InUse.Add(Native, True);
              finally
                InUseLock.Leave;
              end;

              TThread.Yield;        // amplia janela de corrida

              InUseLock.Enter;
              try
                InUse.Remove(Native);
              finally
                InUseLock.Leave;
              end;

              TInterlocked.Decrement(Active);
            finally
              FPool.ReturnToPool(Native);
            end;
          end;
        end);

    Completed := TTask.WaitForAll(Tasks, 30000);  // 30s: se não terminar => deadlock

    Assert.IsTrue(Completed, 'all tasks completed (no deadlock)');
    Assert.AreEqual(0, Violations,
      'no over-capacity and no duplicate handout');
    Assert.IsTrue(FMock.LiveCount <= MaxSize,
      Format('live natives (%d) never exceed MaxSize (%d)', [FMock.LiveCount, MaxSize]));
    Assert.AreEqual(0, FPool.ActiveCount, 'all returned at end');
  finally
    InUse.Free;
    InUseLock.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TThreadSafetyTests);

end.
