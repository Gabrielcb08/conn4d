unit Conn4D.Presentation.Components.TConn4D;

// Non-visual design-time component that mirrors the full TConn4D facade.
//
// Design rules:
//   * All behavior is delegated to Conn4D.Presentation.Facade.TConn4D — there
//     is NO logic duplication. The facade remains the single source of truth.
//   * Class methods reproduce the facade API 1:1 so that `TConn4D.Configure`,
//     `TConn4D.Acquire(...)`, `TConn4D.Shutdown`, etc., resolve correctly even
//     when this unit shadows the facade alias declared in `Conn4D.pas`.
//   * Instance methods are pool-aware conveniences bound to the component's
//     PoolName property. They use distinct names to avoid colliding with the
//     class-level API.

interface

uses
  System.Classes,
  Conn4D.Domain.Types,
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Handle,
  Conn4D.Application.Configurator,
  Conn4D.Presentation.Facade;

type
  // Alias to the static facade so the component can delegate without being
  // confused with its own shadowed `TConn4D` identifier.
  TConn4DFacade = Conn4D.Presentation.Facade.TConn4D;

  TConn4D = class(TComponent)
  private
    FPoolName : string;
  public
    constructor Create(AOwner : TComponent); override;

    // -------------------------------------------------------------------------
    // Class-level API — 1:1 parity with Conn4D.Presentation.Facade.TConn4D.
    // -------------------------------------------------------------------------
    class function  Configure        : TConn4DConfigurator;
    class procedure RegisterProvider(const AProvider : IConn4DProvider);
    class function  Acquire          : TConn4DHandle; overload;
    class function  Acquire(const APoolName : string) : TConn4DHandle; overload;
    class function  PoolExists(const AName : string) : Boolean;
    class function  Sweep(const APoolName : string = '') : Integer;
    class procedure Shutdown;

    // -------------------------------------------------------------------------
    // Instance helpers — operate on this component's PoolName property.
    // -------------------------------------------------------------------------
    function ConfigureThisPool   : TConn4DPoolBuilder;
    function AcquireFromThisPool : TConn4DHandle;
    function ThisPoolExists      : Boolean;
    function SweepThisPool       : Integer;
  published
    property PoolName : string read FPoolName write FPoolName;
  end;

implementation

{ TConn4D }

constructor TConn4D.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FPoolName := TConn4DDefaults.DefaultPoolName;
end;

class function TConn4D.Configure : TConn4DConfigurator;
begin
  Result := TConn4DFacade.Configure;
end;

class procedure TConn4D.RegisterProvider(const AProvider : IConn4DProvider);
begin
  TConn4DFacade.RegisterProvider(AProvider);
end;

class function TConn4D.Acquire : TConn4DHandle;
begin
  Result := TConn4DFacade.Acquire;
end;

class function TConn4D.Acquire(const APoolName : string) : TConn4DHandle;
begin
  Result := TConn4DFacade.Acquire(APoolName);
end;

class function TConn4D.PoolExists(const AName : string) : Boolean;
begin
  Result := TConn4DFacade.PoolExists(AName);
end;

class function TConn4D.Sweep(const APoolName : string) : Integer;
begin
  Result := TConn4DFacade.Sweep(APoolName);
end;

class procedure TConn4D.Shutdown;
begin
  TConn4DFacade.Shutdown;
end;

function TConn4D.ConfigureThisPool : TConn4DPoolBuilder;
begin
  Result := TConn4DFacade.Configure.Pool(FPoolName);
end;

function TConn4D.AcquireFromThisPool : TConn4DHandle;
begin
  Result := TConn4DFacade.Acquire(FPoolName);
end;

function TConn4D.ThisPoolExists : Boolean;
begin
  Result := TConn4DFacade.PoolExists(FPoolName);
end;

function TConn4D.SweepThisPool : Integer;
begin
  Result := TConn4DFacade.Sweep(FPoolName);
end;

end.
