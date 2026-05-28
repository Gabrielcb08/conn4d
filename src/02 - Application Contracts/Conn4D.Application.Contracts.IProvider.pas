unit Conn4D.Application.Contracts.IProvider;

// Provider contracts — the only boundary between Core and Infrastructure.
// Zero uses FireDAC.*. Consumers and Core code depend only on these interfaces.

interface

uses
  Conn4D.Domain.PoolConfig;

type
  // Neutral wrapper around a driver-specific connection object.
  // Ownership stays with the pool slot; callers must never Free NativeObject.
  IConn4DNativeConnection = interface
    ['{B3A7C9D1-4E2F-4A8B-9C61-3D0E5F2A4B22}']
    function NativeObject: TObject;
    function IsHealthy: Boolean;
    function DriverName: string;

    // Creates and starts a native transaction on this connection.
    // The caller is responsible for Commit or Rollback.
    function CreateTransaction: IInterface; // returns IConn4DNativeTransaction
  end;

  // Neutral wrapper around a driver-specific transaction object.
  IConn4DNativeTransaction = interface
    ['{D4C8E3B2-5F1A-4D9C-8B72-4E1F6A3C5B33}']
    function NativeObject: TObject;
    function IsActive: Boolean;
    procedure Commit;
    procedure Rollback;
  end;

  // Extension point for future database engines.
  // The FireDAC adapter is the only built-in implementation.
  IConn4DProvider = interface
    ['{E5D9F4C3-6A2B-4E8D-9C83-5F2A7B4D6C44}']
    function DriverName: string;

    // Returns True when this provider can handle the given DriverID.
    // The registry delegates matching to the provider; no heuristics in Core.
    function Supports(const ADriverID: string): Boolean;

    // Allocates a new physical connection; does not yet open it.
    function CreateConnection(const AConfig: TConn4DPoolConfig): IConn4DNativeConnection;

    // Ensures the connection is open; reconnects if dropped.
    procedure EnsureConnected(const AConn: IConn4DNativeConnection;
      const AConfig: TConn4DPoolConfig);

    // True when the connection can be used immediately.
    function IsHealthy(const AConn: IConn4DNativeConnection): Boolean;

    // Releases all driver resources for the given connection.
    procedure DestroyConnection(var AConn: IConn4DNativeConnection);
  end;

implementation

end.
