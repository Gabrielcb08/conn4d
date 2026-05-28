unit Conn4D.Domain.Types;

interface

type
  TConn4DPoolState = (psIdle, psAcquired, psUnhealthy);

  TConn4DTxState = (tsActive, tsCommitted, tsRolledBack, tsAbandoned);

  TConn4DDefaults = record
  public
    const DefaultPoolName          = 'default';
    const DefaultDriverID          = 'FB';
    const DefaultMaxPoolSize       = 10;
    const DefaultAcquireTimeout    = 5000;
    const DefaultIdleTimeout       = 300000;
    const DefaultSweepInterval     = 60000;
  end;

implementation

end.
