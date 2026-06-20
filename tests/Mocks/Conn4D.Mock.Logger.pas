unit Conn4D.Mock.Logger;

{
  Conn4D — Tests / Mocks / Logger

  TMockLogger: IConnLogger que captura mensagens em memória, para asserts sobre
  o que o Core logou (ex.: warning de zombie reclamado).
}

interface

uses
  System.SyncObjs,
  System.Generics.Collections,
  Conn4D.Shared.Logger;

type
  TMockLogger = class(TInterfacedObject, IConnLogger)
  private
    FLock:     TCriticalSection;
    FMessages: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Log(const ALevel: TConnLogLevel; const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);

    function Count: Integer;
    function Contains(const ASubstr: string): Boolean;
  end;

implementation

uses
  System.SysUtils;

{ TMockLogger }

constructor TMockLogger.Create;
begin
  inherited Create;
  FLock     := TCriticalSection.Create;
  FMessages := TList<string>.Create;
end;

destructor TMockLogger.Destroy;
begin
  FMessages.Free;
  FLock.Free;
  inherited;
end;

procedure TMockLogger.Log(const ALevel: TConnLogLevel; const AMessage: string);
begin
  FLock.Enter;
  try
    FMessages.Add(AMessage);
  finally
    FLock.Leave;
  end;
end;

procedure TMockLogger.Debug(const AMessage: string);
begin
  Log(llDebug, AMessage);
end;

procedure TMockLogger.Info(const AMessage: string);
begin
  Log(llInfo, AMessage);
end;

procedure TMockLogger.Warn(const AMessage: string);
begin
  Log(llWarn, AMessage);
end;

procedure TMockLogger.Error(const AMessage: string);
begin
  Log(llError, AMessage);
end;

function TMockLogger.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FMessages.Count;
  finally
    FLock.Leave;
  end;
end;

function TMockLogger.Contains(const ASubstr: string): Boolean;
var
  M: string;
begin
  FLock.Enter;
  try
    for M in FMessages do
      if M.Contains(ASubstr) then
        Exit(True);
    Result := False;
  finally
    FLock.Leave;
  end;
end;

end.
