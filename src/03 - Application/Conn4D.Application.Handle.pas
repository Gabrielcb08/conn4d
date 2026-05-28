unit Conn4D.Application.Handle;

// TConn4DHandle — value-type RAII connection handle.
//
// The internal IConn4DLeaseGuard is reference-counted; its destructor
// returns the connection to the pool, so copying the record extends the
// lease lifetime (last copy out → Release). Callers must not cache
// NativeObject pointers beyond the handle's lifetime.
//
// Implicit operator: requires FireDAC in the interface section for the
// operator declaration. All pool/connection logic is FireDAC-free.

interface

uses
  FireDAC.Comp.Client,
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Contracts.IPool,
  Conn4D.Application.Transaction;

type
  // Internal guard — releases the slot back to the pool on last copy.
  IConn4DLeaseGuard = interface
    ['{A8F2C5D6-9E4B-4DAE-BF16-8C5D0E7F9A66}']
    function Pool : IConn4DPool;
    function Conn : IConn4DNativeConnection;
  end;

  TConn4DHandle = record
  private
    FGuard : IConn4DLeaseGuard;
  public
    // Explicit generic cast — works for any registered provider.
    function Connection<T : class> : T;

    // Implicit conversion to TFDConnection for direct FireDAC assignment.
    class operator Implicit(const AHandle : TConn4DHandle) : TFDConnection;

    // Opens a new transaction on this connection. The caller owns the
    // returned TConn4DTransaction; failing to Commit causes auto-rollback.
    function BeginTransaction : TConn4DTransaction;

    function PoolName : string;
    function IsValid : Boolean;

    // Internal constructor — called by TConn4D.Acquire.
    class function _Create(const AGuard : IConn4DLeaseGuard) : TConn4DHandle; static;
  end;

  TConn4DLeaseGuardImpl = class(TInterfacedObject, IConn4DLeaseGuard)
  private
    FPool : IConn4DPool;
    FConn : IConn4DNativeConnection;
  public
    constructor Create(const APool : IConn4DPool; const AConn : IConn4DNativeConnection);
    destructor Destroy; override;
    function Pool : IConn4DPool;
    function Conn : IConn4DNativeConnection;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Domain.Exceptions;

{ TConn4DLeaseGuardImpl }

constructor TConn4DLeaseGuardImpl.Create(const APool : IConn4DPool; const AConn : IConn4DNativeConnection);
begin
  inherited Create;
  FPool := APool;
  FConn := AConn;
end;

destructor TConn4DLeaseGuardImpl.Destroy;
begin
  try
    if Assigned(FPool) and Assigned(FConn) then
      FPool.Release(FConn);
  finally
    FConn := nil;
    FPool := nil;
    inherited;
  end;
end;

function TConn4DLeaseGuardImpl.Pool : IConn4DPool;
begin
  Result := FPool;
end;

function TConn4DLeaseGuardImpl.Conn : IConn4DNativeConnection;
begin
  Result := FConn;
end;

{ TConn4DHandle }

class function TConn4DHandle._Create(const AGuard : IConn4DLeaseGuard) : TConn4DHandle;
begin
  Result.FGuard := AGuard;
end;

function TConn4DHandle.Connection<T> : T;
begin
  if not Assigned(FGuard) then
    raise EConn4DCastException.Create('TConn4DHandle is not initialized.');
  try
    Result := FGuard.Conn.NativeObject as T;
  except
    on E : EInvalidCast do
      raise EConn4DCastException.CreateFmt('Connection cast failed: expected %s.', [T.ClassName]);
  end;
end;

class operator TConn4DHandle.Implicit(const AHandle : TConn4DHandle) : TFDConnection;
begin
  if not Assigned(AHandle.FGuard) then
    raise EConn4DCastException.Create('TConn4DHandle is not initialized.');
  Result := AHandle.FGuard.Conn.NativeObject as TFDConnection;
end;

function TConn4DHandle.BeginTransaction : TConn4DTransaction;
var
  NativeTx : IConn4DNativeTransaction;
  Guard    : IConn4DTxGuard;
begin
  if not Assigned(FGuard) then
    raise EConn4DTransactionException.Create('TConn4DHandle is not initialized.');

  NativeTx := FGuard.Conn.CreateTransaction as IConn4DNativeTransaction;
  Guard    := TConn4DTxGuardImpl.Create(NativeTx);
  Result   := TConn4DTransaction._Create(Guard);
end;

function TConn4DHandle.PoolName : string;
begin
  if Assigned(FGuard) then
    Result := FGuard.Pool.PoolName
  else
    Result := '';
end;

function TConn4DHandle.IsValid : Boolean;
begin
  Result := Assigned(FGuard) and Assigned(FGuard.Conn);
end;

end.
