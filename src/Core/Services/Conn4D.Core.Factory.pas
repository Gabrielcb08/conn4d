unit Conn4D.Core.Factory;

{
  Conn4D — Core / Services / Factory

  TConn4DCoreFactory: ponto único para construir um manager de pool já com suas
  dependências resolvidas (clock/logger/broadcaster/health padrão quando não
  fornecidos). Os adapters chamam isto para obter o runtime genérico do Core e
  então o embrulham na fachada fluente tipada do engine — o Core nunca sabe
  qual engine está por baixo.

  Devolve IConnPool; o mesmo objeto também implementa IConn4DBase, recuperável
  via Supports (ver TryGetBase) para registro no TConn4DRegistry.
}

interface

uses
  System.SysUtils,
  Conn4D.Core,
  Conn4D.Core.Base,
  Conn4D.Core.Pool,
  Conn4D.Core.Engine,
  Conn4D.Core.Clock,
  Conn4D.Core.HealthCheck,
  Conn4D.Core.Observer,
  Conn4D.Shared.Logger;

type
  TConn4DCoreFactory = record
  public
    /// <summary>
    /// Cria um TConnPoolManager configurado e o devolve como IConnPool.
    /// Quando AWithHealth é True, injeta um TConnHealthMonitor sobre AEngine.
    /// </summary>
    class function CreateManager(const AEngine: IConnEngine; const AConfig: IConnConfig;
      const AClock: IConnClock = nil; const ALogger: IConnLogger = nil;
      const ABroadcaster: IConnObserverBroadcaster = nil;
      const AWithHealth: Boolean = True): IConnPool; static;

    /// <summary>Recupera a face IConn4DBase do mesmo manager.</summary>
    class function TryGetBase(const APool: IConnPool; out ABase: IConn4DBase): Boolean; static;
  end;

implementation

uses
  Conn4D.Core.PoolManager,
  Conn4D.Core.HealthMonitor;

{ TConn4DCoreFactory }

class function TConn4DCoreFactory.CreateManager(const AEngine: IConnEngine;
  const AConfig: IConnConfig; const AClock: IConnClock; const ALogger: IConnLogger;
  const ABroadcaster: IConnObserverBroadcaster; const AWithHealth: Boolean): IConnPool;
var
  Health: IConnHealthCheck;
begin
  if AWithHealth then
    Health := TConnHealthMonitor.New(AEngine)
  else
    Health := nil;

  Result := TConnPoolManager.Create(AEngine, AConfig, AClock, ALogger, ABroadcaster, Health);
end;

class function TConn4DCoreFactory.TryGetBase(const APool: IConnPool; out ABase: IConn4DBase): Boolean;
begin
  Result := Supports(APool, IConn4DBase, ABase);
end;

end.
