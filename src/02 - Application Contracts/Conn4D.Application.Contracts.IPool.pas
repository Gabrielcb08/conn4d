unit Conn4D.Application.Contracts.IPool;

// Internal pool contract — not exposed to library consumers.

interface

uses
  Conn4D.Domain.PoolConfig,
  Conn4D.Application.Contracts.IProvider;

type
  IConn4DPool = interface
    ['{F6E0A5D4-7B3C-4F9E-AD94-6A3B8C5E7D55}']
    // Borrows an idle healthy connection; blocks until AcquireTimeout if
    // all slots are in use. Raises EConn4DPoolExhaustedException on timeout.
    function Acquire: IConn4DNativeConnection;

    // Returns a previously-acquired connection to the pool.
    procedure Release(const AConn: IConn4DNativeConnection);

    // Removes idle-too-long and unhealthy connections. Returns count removed.
    function Sweep: Integer;

    // Triggers Sweep only when the configured interval has elapsed.
    function SweepIfDue: Integer;

    function PoolName: string;
    function Config: TConn4DPoolConfig;
  end;

implementation

end.
