unit Conn4D.Shared.Logger;

{
  Conn4D — Shared / Logger

  Abstração de log da biblioteca. O Core depende de IConnLogger, nunca de um
  logger concreto. TNullLogger é a implementação padrão no-op, usada quando o
  consumidor não fornece logger — assim o Core nunca precisa testar nil.
}

interface

type
  /// <summary>Severidade de uma entrada de log.</summary>
  TConnLogLevel = (llDebug, llInfo, llWarn, llError);

  /// <summary>
  /// Contrato de log. Métodos de conveniência por nível delegam a Log.
  /// Implementações devem ser thread-safe: o Core loga de múltiplas threads
  /// (negócio + GC) concorrentemente.
  /// </summary>
  IConnLogger = interface
    ['{D1A4F0E1-5040-0000-0000-000000000001}']
    procedure Log(const ALevel: TConnLogLevel; const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
  end;

  /// <summary>Logger no-op. Descarta tudo. Padrão quando nenhum é injetado.</summary>
  TNullLogger = class(TInterfacedObject, IConnLogger)
  public
    procedure Log(const ALevel: TConnLogLevel; const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);

    /// <summary>Fábrica de conveniência: devolve um IConnLogger no-op.</summary>
    class function New: IConnLogger; static;
  end;

implementation

{ TNullLogger }

class function TNullLogger.New: IConnLogger;
begin
  Result := TNullLogger.Create;
end;

procedure TNullLogger.Log(const ALevel: TConnLogLevel; const AMessage: string);
begin
  // no-op
end;

procedure TNullLogger.Debug(const AMessage: string);
begin
  // no-op
end;

procedure TNullLogger.Info(const AMessage: string);
begin
  // no-op
end;

procedure TNullLogger.Warn(const AMessage: string);
begin
  // no-op
end;

procedure TNullLogger.Error(const AMessage: string);
begin
  // no-op
end;

end.
