unit Conn4D;

{$I Conn4D.inc}

{
  Conn4D — Fachada pública.

  Unit única para o consumidor: `uses Conn4D;` dá acesso ao componente/factory
  TConn4D, à configuração (IConnConfig + TConnConfig.New), à porta pura IConn4D e
  à interface agnóstica de conexão IConn4DNative. Re-exporta por alias:

    - Conn4D.Component       : TConn4D, TConn4DEngine
    - Conn4D.Core            : IConn4D (porta pura), IConnConfig
    - Conn4D.Core.Config     : TConnConfig (builder)
    - Conn4D.Adapter.ConnRef : TConnRef, IConn4DNative (acesso à conexão)
    - Conn4D.Adapter.FireDAC : IFDConn4D (marcador de tipo FireDAC)

  Uso típico:
    Conn := TConn4D.Acquire.Configure(
      TConnConfig.New.Provider('Firebird').Port(3050).Database('...'));

  Acesso à conexão nativa SEM cast e SEM nomear a engine: segure IConn4DNative (o
  que Acquire/Conn devolvem) ou use o componente —
    FDQuery.Connection := Conn.Connection;        // ou Conn4D.Connection (componente)
  O resultado é o handle TConnRef, cujo operador implícito converte para o tipo de
  conexão da engine (TFDCustomConnection no FireDAC) conforme o destino.
}

interface

uses
  Conn4D.Core,
  Conn4D.Core.Config,
  Conn4D.Adapter.ConnRef,
  Conn4D.Component,
  // Composição: linka os adapters para suas initialization auto-registrarem as
  // engines no TConn4DEngines (o componente não os puxa mais). FireDAC sempre;
  // Zeos/UniDAC só sob os defines de Conn4D.inc.
  Conn4D.Adapter.FireDAC
{$IFDEF CONN4D_ZEOS}
  , Conn4D.Adapter.Zeos
{$ENDIF}
{$IFDEF CONN4D_UNIDAC}
  , Conn4D.Adapter.UniDAC
{$ENDIF}
  ;

type
  /// Porta agnóstica de engine (ciclo de vida/pool/config), sem acesso nativo.
  IConn4D       = Conn4D.Core.IConn4D;
  /// Porta + acesso à conexão nativa (agnóstica): segure esta para .Connection.
  IConn4DNative = Conn4D.Adapter.ConnRef.IConn4DNative;
  /// Configuração como interface (builder fluente).
  IConnConfig   = Conn4D.Core.IConnConfig;
  /// Implementação/builder da config: TConnConfig.New.
  TConnConfig   = Conn4D.Core.Config.TConnConfig;
  /// Componente de paleta + factory programático.
  TConn4D       = Conn4D.Component.TConn4D;
  /// Engines suportadas.
  TConn4DEngine = Conn4D.Component.TConn4DEngine;
  /// Handle universal da conexão (operadores implícitos por engine).
  TConnRef      = Conn4D.Adapter.ConnRef.TConnRef;
  /// Interface-marcador FireDAC (estende IConn4DNative).
  IFDConn4D     = Conn4D.Adapter.FireDAC.IFDConn4D;

const
  // Valores do enum não vêm pelo alias de tipo — re-exportados aqui.
  enFireDAC = Conn4D.Component.enFireDAC;
  enZeos    = Conn4D.Component.enZeos;
  enUniDAC  = Conn4D.Component.enUniDAC;

implementation

end.
