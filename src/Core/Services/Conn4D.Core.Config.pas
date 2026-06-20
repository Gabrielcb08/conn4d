unit Conn4D.Core.Config;

{
  Conn4D — Core / Services / Config

  TConnConfig: implementação de IConnConfig (a config como interface). Builder
  fluente com semântica de REFERÊNCIA — cada setter muta o próprio objeto e
  devolve a si mesmo (Self) como IConnConfig, permitindo encadeamento. Comece em
  TConnConfig.New.

  EndConfig devolve a fachada vinculada (definida por BindTo, chamado por
  IConn4D.Configure sem parâmetro); avulsa, devolve nil. Clone produz uma cópia
  independente (sem vínculo) — usada quando uma config pronta é aplicada.
}

interface

uses
  System.Generics.Collections,
  Conn4D.Shared.Config,
  Conn4D.Core;

type
  TConnConfig = class(TInterfacedObject, IConnConfig)
  private
    FProvider:       string;
    FHost:           string;
    FPort:           Integer;
    FDatabase:       string;
    FUserName:       string;
    FPassword:       string;
    FConnectTimeout: Integer;
    FVendorLibX86:   string;
    FVendorLibX64:   string;
    FPool:           TConnPoolConfig;
    FGC:             TConnGCConfig;
    FExtra:          TArray<TPair<string, string>>;
    [weak] FParent:  IConn4D;   // referência FRACA: evita ciclo config<->fachada
  public
    /// <summary>Nova config com os defaults da spec. Início do builder.</summary>
    class function New: IConnConfig; static;

    { Getters }
    function Provider: string; overload;
    function Host: string; overload;
    function Port: Integer; overload;
    function Database: string; overload;
    function UserName: string; overload;
    function Password: string; overload;
    function ConnectTimeout: Integer; overload;
    function VendorLibX86: string; overload;
    function VendorLibX64: string; overload;
    function Pool: TConnPoolConfig;
    function GC: TConnGCConfig;
    function Extra: TArray<TPair<string, string>>; overload;
    function GetExtra(const AKey: string; const ADefault: string = ''): string;

    { Setters fluentes }
    function Provider(const AValue: string): IConnConfig; overload;
    function Host(const AValue: string): IConnConfig; overload;
    function Port(const AValue: Integer): IConnConfig; overload;
    function Database(const AValue: string): IConnConfig; overload;
    function UserName(const AValue: string): IConnConfig; overload;
    function Password(const AValue: string): IConnConfig; overload;
    function ConnectTimeout(const AValue: Integer): IConnConfig; overload;
    function VendorLibX86(const AValue: string): IConnConfig; overload;
    function VendorLibX64(const AValue: string): IConnConfig; overload;
    function MinSize(const AValue: Integer): IConnConfig;
    function MaxSize(const AValue: Integer): IConnConfig;
    function AcquireTimeout(const AValue: Cardinal): IConnConfig;
    function MaxLeaseTime(const AValue: Cardinal): IConnConfig;
    function IdleTimeout(const AValue: Cardinal): IConnConfig;
    function GCEnabled(const AValue: Boolean): IConnConfig;
    function GCInterval(const AValue: Cardinal): IConnConfig;
    function Extra(const AKey, AValue: string): IConnConfig; overload;

    function Clone: IConnConfig;
    function BindTo(const AOwner: IConn4D): IConnConfig;
    function EndConfig: IConn4D;
  end;

implementation

uses
  System.SysUtils;

{ TConnConfig }

class function TConnConfig.New: IConnConfig;
var
  C: TConnConfig;
begin
  C := TConnConfig.Create;
  C.FPort           := 0;
  C.FConnectTimeout := 5000;
  C.FPool.MinSize        := 1;
  C.FPool.MaxSize        := 10;
  C.FPool.AcquireTimeout := 5000;
  C.FPool.MaxLeaseTime   := 60000;
  C.FPool.IdleTimeout    := 120000;
  C.FGC.Enabled  := True;
  C.FGC.Interval := 30000;
  Result := C;
end;

{ Getters }

function TConnConfig.Provider: string;
begin
  Result := FProvider;
end;

function TConnConfig.Host: string;
begin
  Result := FHost;
end;

function TConnConfig.Port: Integer;
begin
  Result := FPort;
end;

function TConnConfig.Database: string;
begin
  Result := FDatabase;
end;

function TConnConfig.UserName: string;
begin
  Result := FUserName;
end;

function TConnConfig.Password: string;
begin
  Result := FPassword;
end;

function TConnConfig.ConnectTimeout: Integer;
begin
  Result := FConnectTimeout;
end;

function TConnConfig.VendorLibX86: string;
begin
  Result := FVendorLibX86;
end;

function TConnConfig.VendorLibX64: string;
begin
  Result := FVendorLibX64;
end;

function TConnConfig.Pool: TConnPoolConfig;
begin
  Result := FPool;
end;

function TConnConfig.GC: TConnGCConfig;
begin
  Result := FGC;
end;

function TConnConfig.Extra: TArray<TPair<string, string>>;
begin
  Result := FExtra;
end;

function TConnConfig.GetExtra(const AKey, ADefault: string): string;
var
  Pair: TPair<string, string>;
begin
  for Pair in FExtra do
    if SameText(Pair.Key, AKey) then
      Exit(Pair.Value);
  Result := ADefault;
end;

{ Setters fluentes }

function TConnConfig.Provider(const AValue: string): IConnConfig;
begin
  FProvider := AValue;
  Result := Self;
end;

function TConnConfig.Host(const AValue: string): IConnConfig;
begin
  FHost := AValue;
  Result := Self;
end;

function TConnConfig.Port(const AValue: Integer): IConnConfig;
begin
  FPort := AValue;
  Result := Self;
end;

function TConnConfig.Database(const AValue: string): IConnConfig;
begin
  FDatabase := AValue;
  Result := Self;
end;

function TConnConfig.UserName(const AValue: string): IConnConfig;
begin
  FUserName := AValue;
  Result := Self;
end;

function TConnConfig.Password(const AValue: string): IConnConfig;
begin
  FPassword := AValue;
  Result := Self;
end;

function TConnConfig.ConnectTimeout(const AValue: Integer): IConnConfig;
begin
  FConnectTimeout := AValue;
  Result := Self;
end;

function TConnConfig.VendorLibX86(const AValue: string): IConnConfig;
begin
  FVendorLibX86 := AValue;
  Result := Self;
end;

function TConnConfig.VendorLibX64(const AValue: string): IConnConfig;
begin
  FVendorLibX64 := AValue;
  Result := Self;
end;

function TConnConfig.MinSize(const AValue: Integer): IConnConfig;
begin
  FPool.MinSize := AValue;
  Result := Self;
end;

function TConnConfig.MaxSize(const AValue: Integer): IConnConfig;
begin
  FPool.MaxSize := AValue;
  Result := Self;
end;

function TConnConfig.AcquireTimeout(const AValue: Cardinal): IConnConfig;
begin
  FPool.AcquireTimeout := AValue;
  Result := Self;
end;

function TConnConfig.MaxLeaseTime(const AValue: Cardinal): IConnConfig;
begin
  FPool.MaxLeaseTime := AValue;
  Result := Self;
end;

function TConnConfig.IdleTimeout(const AValue: Cardinal): IConnConfig;
begin
  FPool.IdleTimeout := AValue;
  Result := Self;
end;

function TConnConfig.GCEnabled(const AValue: Boolean): IConnConfig;
begin
  FGC.Enabled := AValue;
  Result := Self;
end;

function TConnConfig.GCInterval(const AValue: Cardinal): IConnConfig;
begin
  FGC.Interval := AValue;
  Result := Self;
end;

function TConnConfig.Extra(const AKey, AValue: string): IConnConfig;
var
  I: Integer;
  Found: Boolean;
begin
  Found := False;
  for I := 0 to High(FExtra) do
    if SameText(FExtra[I].Key, AKey) then
    begin
      FExtra[I] := TPair<string, string>.Create(AKey, AValue);
      Found := True;
      Break;
    end;
  if not Found then
  begin
    SetLength(FExtra, Length(FExtra) + 1);
    FExtra[High(FExtra)] := TPair<string, string>.Create(AKey, AValue);
  end;
  Result := Self;
end;

function TConnConfig.Clone: IConnConfig;
var
  C: TConnConfig;
begin
  C := TConnConfig.Create;
  C.FProvider       := FProvider;
  C.FHost           := FHost;
  C.FPort           := FPort;
  C.FDatabase       := FDatabase;
  C.FUserName       := FUserName;
  C.FPassword       := FPassword;
  C.FConnectTimeout := FConnectTimeout;
  C.FVendorLibX86   := FVendorLibX86;
  C.FVendorLibX64   := FVendorLibX64;
  C.FPool           := FPool;
  C.FGC             := FGC;
  C.FExtra          := Copy(FExtra);
  C.FParent         := nil;   // cópia independente, sem vínculo
  Result := C;
end;

function TConnConfig.BindTo(const AOwner: IConn4D): IConnConfig;
begin
  FParent := AOwner;
  Result := Self;
end;

function TConnConfig.EndConfig: IConn4D;
begin
  Result := FParent;
end;

end.
