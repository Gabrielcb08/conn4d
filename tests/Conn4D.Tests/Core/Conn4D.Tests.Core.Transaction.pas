unit Conn4D.Tests.Core.Transaction;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTransactionTest = class
  public
    [Test] procedure Commit_ChangesStateToCommitted;
    [Test] procedure Rollback_ChangesStateToRolledBack;
    [Test] procedure Rollback_IsIdempotent;
    [Test] procedure AutoRollback_WhenGuardDestroyedWithoutCommit;
    [Test] procedure Commit_Raises_AfterRollback;
    [Test] procedure Transaction_Generic_ReturnsNativeObject;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Domain.Types,
  Conn4D.Domain.Exceptions,
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Transaction,
  Conn4D.Tests.Support.Fakes;

function MakeTx: TConn4DTransaction;
var
  FakeConn: TFakeNativeConnection;
  NativeTx : IConn4DNativeTransaction;
  Guard    : IConn4DTxGuard;
begin
  FakeConn := TFakeNativeConnection.Create;
  NativeTx := FakeConn.CreateTransaction as IConn4DNativeTransaction;
  Guard    := TConn4DTxGuardImpl.Create(NativeTx);
  Result   := TConn4DTransaction._Create(Guard);
end;

procedure TTransactionTest.Commit_ChangesStateToCommitted;
var
  Tx: TConn4DTransaction;
begin
  Tx := MakeTx;
  Tx.Commit;
  Assert.AreEqual(tsCommitted, Tx.State);
end;

procedure TTransactionTest.Rollback_ChangesStateToRolledBack;
var
  Tx: TConn4DTransaction;
begin
  Tx := MakeTx;
  Tx.Rollback;
  Assert.AreEqual(tsRolledBack, Tx.State);
end;

procedure TTransactionTest.Rollback_IsIdempotent;
var
  Tx: TConn4DTransaction;
begin
  Tx := MakeTx;
  Tx.Rollback;
  Assert.WillNotRaise(procedure begin Tx.Rollback; end);
  Assert.AreEqual(tsRolledBack, Tx.State);
end;

procedure TTransactionTest.AutoRollback_WhenGuardDestroyedWithoutCommit;
var
  FakeTx  : TFakeNativeTransaction;
  NativeTx: IConn4DNativeTransaction;
  Guard   : IConn4DTxGuard;
begin
  FakeTx   := TFakeNativeTransaction.Create;
  NativeTx := FakeTx as IConn4DNativeTransaction;
  Guard    := TConn4DTxGuardImpl.Create(NativeTx);
  // Release without committing — guard destructor must auto-rollback
  Guard := nil;
  Assert.AreEqual(1, FakeTx.Rollbacks, 'Auto-rollback must fire on guard destruction');
end;

procedure TTransactionTest.Commit_Raises_AfterRollback;
var
  Tx: TConn4DTransaction;
begin
  Tx := MakeTx;
  Tx.Rollback;
  Assert.WillRaise(procedure begin Tx.Commit; end, EConn4DTransactionException);
end;

procedure TTransactionTest.Transaction_Generic_ReturnsNativeObject;
var
  FakeConn : TFakeNativeConnection;
  NativeTx : IConn4DNativeTransaction;
  Guard    : IConn4DTxGuard;
  Tx       : TConn4DTransaction;
  FakeTx   : TFakeNativeTransaction;
begin
  FakeConn := TFakeNativeConnection.Create;
  NativeTx := FakeConn.CreateTransaction as IConn4DNativeTransaction;
  Guard    := TConn4DTxGuardImpl.Create(NativeTx);
  Tx       := TConn4DTransaction._Create(Guard);

  FakeTx := Tx.Transaction<TFakeNativeTransaction>;
  Assert.IsNotNull(FakeTx);
  Assert.IsTrue(FakeTx is TFakeNativeTransaction);
end;

initialization
  TDUnitX.RegisterTestFixture(TTransactionTest);

end.
