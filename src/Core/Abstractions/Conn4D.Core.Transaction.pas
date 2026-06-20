unit Conn4D.Core.Transaction;

{
  Conn4D — Core / Abstractions / Transaction

  IConnTransaction: contrato de uma transação em curso (ver spec §4.4).
  Devolvido por BeginTransaction no adapter fluente; o consumidor faz
  Commit/Rollback. Agnóstico de engine.
}

interface

uses
  Conn4D.Shared.Types;

type
  /// <summary>Transação em curso sobre uma conexão emprestada.</summary>
  IConnTransaction = interface
    ['{D1A4F0E1-0000-0000-0000-000000000004}']
    /// <summary>Identidade estável desta transação.</summary>
    function Id: TGUID;
    /// <summary>Confirma a transação.</summary>
    procedure Commit;
    /// <summary>Desfaz a transação.</summary>
    procedure Rollback;
    /// <summary>Indica se a transação ainda está aberta.</summary>
    function IsActive: Boolean;
    /// <summary>Nível de isolamento com que foi iniciada.</summary>
    function Isolation: TConnIsolation;
  end;

implementation

end.
