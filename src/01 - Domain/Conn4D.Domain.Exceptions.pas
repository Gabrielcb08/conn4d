unit Conn4D.Domain.Exceptions;

interface

uses
  System.SysUtils;

type
  EConn4DException         = class(Exception);
  EConn4DConfigException   = class(EConn4DException);
  EConn4DPoolNotFoundException  = class(EConn4DException);
  EConn4DPoolExhaustedException = class(EConn4DException);
  EConn4DCastException     = class(EConn4DException);
  EConn4DTransactionException   = class(EConn4DException);
  EConn4DProviderException = class(EConn4DException);

implementation

end.
