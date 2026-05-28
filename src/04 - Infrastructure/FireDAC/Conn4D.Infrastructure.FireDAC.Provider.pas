unit Conn4D.Infrastructure.FireDAC.Provider;

// TConn4DFireDACProvider — implements IConn4DProvider.
// Sole entry point for FireDAC in the library's infrastructure.

interface

uses
  Conn4D.Application.Contracts.IProvider,
  Conn4D.Domain.PoolConfig;

type
  TConn4DFireDACProvider = class(TInterfacedObject, IConn4DProvider)
  private
    procedure ApplyConfig(const AConn: TObject; const AConfig: TConn4DPoolConfig);
  public
    function  DriverName: string;
    function  Supports(const ADriverID: string): Boolean;
    function  CreateConnection(const AConfig: TConn4DPoolConfig): IConn4DNativeConnection;
    procedure EnsureConnected(const AConn: IConn4DNativeConnection;
      const AConfig: TConn4DPoolConfig);
    function  IsHealthy(const AConn: IConn4DNativeConnection): Boolean;
    procedure DestroyConnection(var AConn: IConn4DNativeConnection);
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  Conn4D.Infrastructure.FireDAC.ConnectionHandle;

procedure TConn4DFireDACProvider.ApplyConfig(const AConn: TObject;
  const AConfig: TConn4DPoolConfig);
var
  C: TFDConnection;
  I: Integer;
  Parts: TArray<string>;
begin
  C := TFDConnection(AConn);
  C.LoginPrompt := False;
  C.ResourceOptions.SilentMode := True;
  C.Params.Clear;
  C.Params.Values['DriverID'] := AConfig.DriverID;
  C.Params.Database := AConfig.Database;

  if AConfig.UserName <> '' then
    C.Params.UserName := AConfig.UserName;
  if AConfig.Password <> '' then
    C.Params.Password := AConfig.Password;
  if AConfig.Host <> '' then
    C.Params.Values['Server'] := AConfig.Host;
  if AConfig.Port > 0 then
    C.Params.Values['Port'] := IntToStr(AConfig.Port);

  for I := 0 to High(AConfig.ExtraParams) do
  begin
    Parts := AConfig.ExtraParams[I].Split(['='], 2);
    if Length(Parts) = 2 then
      C.Params.Values[Parts[0]] := Parts[1];
  end;
end;

function TConn4DFireDACProvider.DriverName: string;
begin
  Result := 'FireDAC';
end;

function TConn4DFireDACProvider.Supports(const ADriverID: string): Boolean;
begin
  Result := True; // FireDAC is a multi-driver adapter; DriverID is forwarded to FDConnection.Params
end;

function TConn4DFireDACProvider.CreateConnection(
  const AConfig: TConn4DPoolConfig): IConn4DNativeConnection;
var
  Conn: TFDConnection;
begin
  Conn := TFDConnection.Create(nil);
  ApplyConfig(Conn, AConfig);
  Result := TConn4DFireDACNativeConnection.Create(Conn, True);
end;

procedure TConn4DFireDACProvider.EnsureConnected(const AConn: IConn4DNativeConnection;
  const AConfig: TConn4DPoolConfig);
var
  C: TFDConnection;
begin
  C := TFDConnection(AConn.NativeObject);
  ApplyConfig(C, AConfig);
  if not C.Connected then
  try
    C.Connected := True;
  except
    on E: Exception do
    begin
      if Pos('Object factory', E.Message) > 0 then
        raise Exception.CreateFmt(
          'FireDAC driver "%s" is not registered. ' +
          'Add "FireDAC.Phys.%s" (or the equivalent FireDAC.Phys.XXX unit for your driver) ' +
          'to your project''s uses clause.',
          [AConfig.DriverID, AConfig.DriverID]);
      raise;
    end;
  end;
end;

function TConn4DFireDACProvider.IsHealthy(const AConn: IConn4DNativeConnection): Boolean;
begin
  Result := AConn.IsHealthy;
end;

procedure TConn4DFireDACProvider.DestroyConnection(var AConn: IConn4DNativeConnection);
begin
  AConn := nil; // releases the interface → calls TConn4DFireDACNativeConnection.Destroy
end;

end.
