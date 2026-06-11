unit Conn4D.Container;

interface

uses
  Conn4D.Application.Contracts.IProvider;

type
  TConn4DContainer = class
  private
    class var FRegistered: Boolean;
  public
    class procedure RegisterServices;

    // Registers services, then returns every IConn4DProvider the container
    // resolves. Falls back to the built-in FireDAC provider when the container
    // resolves none (e.g. reduced RTTI or a runtime-package mismatch), so the
    // library always has a working provider for the default DriverID.
    class function ResolveProviders: TArray<IConn4DProvider>;
  end;

implementation

uses
  Spring.Container,
  Conn4D.Infrastructure.FireDAC.Provider;

class procedure TConn4DContainer.RegisterServices;
begin
  if FRegistered then
    Exit;

  GlobalContainer.RegisterType<TConn4DFireDACProvider>
    .Implements<IConn4DProvider>
    .AsSingleton;

  GlobalContainer.Build;
  FRegistered := True;
end;

class function TConn4DContainer.ResolveProviders: TArray<IConn4DProvider>;
begin
  RegisterServices;
  Result := GlobalContainer.ResolveAll<IConn4DProvider>;
  if Length(Result) = 0 then
    Result := [TConn4DFireDACProvider.Create];
end;

end.
