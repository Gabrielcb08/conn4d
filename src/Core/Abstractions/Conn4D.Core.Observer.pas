unit Conn4D.Core.Observer;

{
  Conn4D — Core / Abstractions / Observer

  Eventos de ciclo de vida das conexões e o contrato Observer (ver spec §4.5).
  IConnObserver é o assinante; IConnObserverBroadcaster é o ponto de publicação
  que pool e GC usam — ambos via interface, preservando DIP.
}

interface

type
  /// <summary>Tipos de evento publicados durante o ciclo de vida da conexão.</summary>
  TConnEventType = (
    ceCreated,
    ceAcquired,
    ceReleased,
    ceEvictedIdle,
    ceEvictedZombie,
    ceHealthFail,
    ceShutdown
  );

  /// <summary>Evento de ciclo de vida. Apenas dados.</summary>
  TConnEvent = record
    EventType: TConnEventType;
    ConnId:    TGUID;
    EngineID:  string;
    Timestamp: TDateTime;
    Detail:    string;
  end;

  /// <summary>Assinante de eventos de conexão.</summary>
  IConnObserver = interface
    ['{D1A4F0E1-0000-0000-0000-000000000007}']
    procedure OnConnEvent(const AEvent: TConnEvent);
  end;

  /// <summary>
  /// Ponto de publicação e gerenciamento de assinantes. Pool e GC publicam
  /// eventos por esta interface, sem conhecer os observadores concretos.
  /// </summary>
  IConnObserverBroadcaster = interface
    ['{D1A4F0E1-0000-0000-0000-000000000008}']
    procedure Subscribe(const AObserver: IConnObserver);
    procedure Unsubscribe(const AObserver: IConnObserver);
    procedure Publish(const AEvent: TConnEvent);
  end;

implementation

end.
