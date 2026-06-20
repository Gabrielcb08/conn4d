unit Conn4D.Shared.Exceptions;

{
  Conn4D — Shared / Exceptions

  Hierarquia de exceções (ver spec §10). Falhas excepcionais lançam algo desta
  hierarquia; falhas esperadas usam TConnResult<T> (em Shared.Types). O Core
  nunca engole exceção em silêncio — sempre loga via IConnLogger antes de subir.
}

interface

uses
  System.SysUtils;

type
  /// <summary>Raiz de toda exceção da biblioteca.</summary>
  EConn4DException = class(Exception);

  /// <summary>Configuração inválida ou incompleta.</summary>
  EConn4DConfigException = class(EConn4DException);

  /// <summary>Acquire estourou o AcquireTimeout (pool esgotado, fila cheia).</summary>
  EConn4DTimeoutException = class(EConn4DException);

  /// <summary>Falha originada no driver/engine concreto.</summary>
  EConn4DEngineException = class(EConn4DException);

  /// <summary>Pool no limite e fila de espera saturada.</summary>
  EConn4DPoolExhaustedException = class(EConn4DException);

  /// <summary>Commit/Rollback inválido ou transação em estado incoerente.</summary>
  EConn4DTransactionException = class(EConn4DException);

  /// <summary>Tipo nativo incompatível ao desembrulhar TObject no adapter.</summary>
  EConn4DCastException = class(EConn4DException);

implementation

end.
