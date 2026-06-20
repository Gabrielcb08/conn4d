unit Conn4D.Mock.Clock;

{
  Conn4D — Tests / Mocks / Clock

  TMockClock: IConnClock controlado pelo teste. NowMs só muda via Advance,
  permitindo simular passagem de tempo (idle/zombie) sem Sleep e sem flakiness
  (ver references/threading-rules.md).
}

interface

uses
  System.SyncObjs,
  Conn4D.Core.Clock;

type
  TMockClock = class(TInterfacedObject, IConnClock)
  private
    FLock: TCriticalSection;
    FNow:  Int64;
  public
    constructor Create(const AStartMs: Int64 = 0);
    destructor Destroy; override;
    function NowMs: Int64;
    procedure Advance(const ADeltaMs: Int64);
    procedure SetNow(const AValueMs: Int64);
  end;

implementation

{ TMockClock }

constructor TMockClock.Create(const AStartMs: Int64);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FNow  := AStartMs;
end;

destructor TMockClock.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TMockClock.NowMs: Int64;
begin
  FLock.Enter;
  try
    Result := FNow;
  finally
    FLock.Leave;
  end;
end;

procedure TMockClock.Advance(const ADeltaMs: Int64);
begin
  FLock.Enter;
  try
    Inc(FNow, ADeltaMs);
  finally
    FLock.Leave;
  end;
end;

procedure TMockClock.SetNow(const AValueMs: Int64);
begin
  FLock.Enter;
  try
    FNow := AValueMs;
  finally
    FLock.Leave;
  end;
end;

end.
