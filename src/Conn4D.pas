unit Conn4D;

// Single-unit entry point for library consumers.
// After `uses Conn4D, FireDAC.Comp.Client;` the consumer has access to
// TConn4D, TConn4DHandle, TConn4DTransaction, TConn4DConfigurator and all
// domain exceptions without any further explicit unit references.

interface

uses
  Conn4D.Domain.Exceptions,
  Conn4D.Domain.Types,
  Conn4D.Domain.PoolConfig,
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Application.Contracts.IPool,
  Conn4D.Application.Handle,
  Conn4D.Application.Transaction,
  Conn4D.Application.Configurator,
  Conn4D.Presentation.Facade;

type
  TConn4D             = Conn4D.Presentation.Facade.TConn4D;
  TConn4DHandle       = Conn4D.Application.Handle.TConn4DHandle;
  TConn4DTransaction  = Conn4D.Application.Transaction.TConn4DTransaction;
  TConn4DConfigurator = Conn4D.Application.Configurator.TConn4DConfigurator;
  TConn4DPoolBuilder  = Conn4D.Application.Configurator.TConn4DPoolBuilder;

implementation

end.
