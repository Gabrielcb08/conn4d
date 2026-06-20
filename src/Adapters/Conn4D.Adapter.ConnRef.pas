unit Conn4D.Adapter.ConnRef;

{$I Conn4D.inc}

{
  Conn4D — Interface Adapter / Handle de conexão (seam engine-aware)

  Anel de Interface Adapters (Arquitetura Limpa). É o ÚNICO ponto, ao lado dos
  engine adapters, autorizado a citar tipos de framework (TFDCustomConnection,
  TZConnection, TUniConnection). O Core (políticas) NÃO depende desta unit — a
  seta da Regra da Dependência aponta para dentro: esta unit usa Conn4D.Core,
  nunca o contrário.

  Dois símbolos:

  - TConnRef: record leve (não-dono) que carrega a conexão nativa emprestada
    (TObject) e expõe um `class operator Implicit` PARA CADA engine habilitada. O
    compilador escolhe o operador pelo tipo do LADO ESQUERDO da atribuição:

       FDQuery.Connection  := Conn.Connection;   // -> TFDCustomConnection (FireDAC)
       ZQuery.Connection   := Conn.Connection;   // -> TZConnection        (Zeos)
       UniQuery.Connection := Conn.Connection;   // -> TUniConnection      (UniDAC)

    Cast VERIFICADO (`as`): atribuir a um alvo cuja engine não corresponde à
    conexão emprestada levanta EInvalidCast — erro claro, nunca AV.

  - IConn4DNative: interface AGNÓSTICA (não cita engine no nome) que ESTENDE a
    porta pura IConn4D do Core e acrescenta só o acessor `Connection`. É o que o
    consumidor segura para escrever `Conn.Connection` SEM cast e sem nomear a
    engine; trocar de engine no futuro não altera o tipo da variável.

  FireDAC entra SEMPRE (engine padrão, vem com o Delphi); Zeos/UniDAC só sob os
  defines de Conn4D.inc — sem o define, o operador correspondente nem existe.
}

interface

uses
  Conn4D.Core,
  FireDAC.Comp.Client
{$IFDEF CONN4D_ZEOS}
  , ZConnection
{$ENDIF}
{$IFDEF CONN4D_UNIDAC}
  , Uni
{$ENDIF}
  ;

type
  /// <summary>
  /// Handle universal da conexão nativa desta thread. Convertido implicitamente
  /// para o tipo de conexão da engine pelo operador que casa com o destino.
  /// </summary>
  TConnRef = record
  private
    FNative: TObject;   // conexão nativa emprestada (o pool/GC é o dono; nunca Free)
  public
    /// <summary>Embrulha a conexão nativa (uso interno dos adapters).</summary>
    class function Wrap(const A: TObject): TConnRef; static; inline;

    class operator Implicit(const ARef: TConnRef): TFDCustomConnection; inline;
{$IFDEF CONN4D_ZEOS}
    class operator Implicit(const ARef: TConnRef): TZConnection; inline;
{$ENDIF}
{$IFDEF CONN4D_UNIDAC}
    class operator Implicit(const ARef: TConnRef): TUniConnection; inline;
{$ENDIF}
  end;

  /// <summary>
  /// Porta do Core (IConn4D) + acesso à conexão nativa. Agnóstica de engine: o
  /// consumidor a segura e chama Connection sem cast. Implementada por todas as
  /// fachadas de engine.
  /// </summary>
  IConn4DNative = interface(IConn4D)
    ['{7E2C9A41-3B6D-4F8E-9C12-5A0B1D2E3F40}']
    /// <summary>Conexão nativa desta thread; operadores implícitos por engine.</summary>
    function Connection: TConnRef;
  end;

implementation

class function TConnRef.Wrap(const A: TObject): TConnRef;
begin
  Result.FNative := A;
end;

class operator TConnRef.Implicit(const ARef: TConnRef): TFDCustomConnection;
begin
  Result := ARef.FNative as TFDCustomConnection;
end;

{$IFDEF CONN4D_ZEOS}
class operator TConnRef.Implicit(const ARef: TConnRef): TZConnection;
begin
  Result := ARef.FNative as TZConnection;
end;
{$ENDIF}

{$IFDEF CONN4D_UNIDAC}
class operator TConnRef.Implicit(const ARef: TConnRef): TUniConnection;
begin
  Result := ARef.FNative as TUniConnection;
end;
{$ENDIF}

end.
