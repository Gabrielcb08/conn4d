unit Conn4D.Core.SystemClock;

{
  Conn4D — Core / Services / SystemClock

  Implementação real de IConnClock para produção. Usa um relógio monotônico
  (TStopwatch) — imune a ajustes de horário do sistema, ao contrário de Now.
  Nos testes, troca-se por um mock que avança o tempo manualmente.
}

interface

uses
  Conn4D.Core.Clock;

type
  TConnSystemClock = class(TInterfacedObject, IConnClock)
  public
    function NowMs: Int64;
    class function New: IConnClock; static;
  end;

implementation

uses
  System.Diagnostics;

{ TConnSystemClock }

class function TConnSystemClock.New: IConnClock;
begin
  Result := TConnSystemClock.Create;
end;

function TConnSystemClock.NowMs: Int64;
begin
  // TStopwatch.GetTimeStamp é monotônico; normaliza para milissegundos.
  Result := TStopwatch.GetTimeStamp * 1000 div TStopwatch.Frequency;
end;

end.
