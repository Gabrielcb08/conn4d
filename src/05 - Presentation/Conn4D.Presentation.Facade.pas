unit Conn4D.Presentation.Facade;

// TConn4D — static entry point. Zero logic; delegates to PoolRegistry.
// Registers TConn4DFireDACProvider automatically on first use.

interface

uses
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Handle,
  Conn4D.Application.Configurator;

type
  TConn4D = class
  public
    // -------------------------------------------------------------------------
    // Configuration
    // -------------------------------------------------------------------------

    // Returns the fluent configurator:
    // TConn4D.Configure.Pool('default').Host(...).Database(...).Apply;
    class function Configure : TConn4DConfigurator;

    // Explicit provider registration (optional — FireDAC is auto-registered).
    class procedure RegisterProvider(const AProvider : IConn4DProvider);

    // -------------------------------------------------------------------------
    // Connection acquisition
    // -------------------------------------------------------------------------

    // Acquires a connection from the default pool.
    class function Acquire : TConn4DHandle; overload;

    // Acquires a connection from a named pool.
    class function Acquire(const APoolName : string) : TConn4DHandle; overload;

    // -------------------------------------------------------------------------
    // Pool management
    // -------------------------------------------------------------------------
    class function PoolExists(const AName : string) : Boolean;

    // Removes idle/unhealthy connections from a named pool (empty = all pools).
    class function Sweep(const APoolName : string = '') : Integer;

    // Stops the sweeper and destroys all pools. Call on application shutdown.
    class procedure Shutdown;
  end;

implementation

uses
  System.SysUtils,
  Conn4D.Domain.Types,
  Conn4D.Application.Contracts.IPool,
  Conn4D.Application.PoolRegistry,
  Conn4D.Container;

var
  GProvidersRegistered : Boolean = False;
  GRegLock             : TObject;

procedure EnsureProviders;
var
  Providers : TArray<IConn4DProvider>;
  P         : IConn4DProvider;
begin
  if GProvidersRegistered then
    Exit;

  TMonitor.Enter(GRegLock);
  try
    if GProvidersRegistered then
      Exit;
    Providers := TConn4DContainer.ResolveProviders;
    for P in Providers do
      TConn4DPoolRegistry.Instance.RegisterProvider(P);
    GProvidersRegistered := True;
  finally
    TMonitor.Exit(GRegLock);
  end;
end;

{ TConn4D }

class function TConn4D.Configure : TConn4DConfigurator;
begin
  EnsureProviders;
  Result := TConn4DConfigurator.Create;
end;

class procedure TConn4D.RegisterProvider(const AProvider : IConn4DProvider);
begin
  TConn4DPoolRegistry.Instance.RegisterProvider(AProvider);
end;

class function TConn4D.Acquire : TConn4DHandle;
begin
  Result := Acquire(TConn4DDefaults.DefaultPoolName);
end;

class function TConn4D.Acquire(const APoolName : string) : TConn4DHandle;
var
  Pool  : IConn4DPool;
  Conn  : IConn4DNativeConnection;
  Guard : IConn4DLeaseGuard;
begin
  EnsureProviders;
  Pool   := TConn4DPoolRegistry.Instance.GetPool(APoolName);
  Conn   := Pool.Acquire;
  Guard  := TConn4DLeaseGuardImpl.Create(Pool, Conn);
  Result := TConn4DHandle._Create(Guard);
end;

class function TConn4D.PoolExists(const AName : string) : Boolean;
begin
  Result := TConn4DPoolRegistry.Instance.PoolExists(AName);
end;

class function TConn4D.Sweep(const APoolName : string) : Integer;
var
  Pool : IConn4DPool;
begin
  if Trim(APoolName) = '' then
    Exit(TConn4DPoolRegistry.Instance.SweepAll);
  Pool   := TConn4DPoolRegistry.Instance.GetPool(APoolName);
  Result := Pool.Sweep;
end;

class procedure TConn4D.Shutdown;
begin
  TConn4DPoolRegistry.Instance.Clear;
end;

initialization

GRegLock := TObject.Create;

finalization

FreeAndNil(GRegLock);

end.
