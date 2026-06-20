unit Conn4D.Adapter.FireDAC.Providers;

{
  Conn4D — Adapter / FireDAC / Providers (registry)

  Registry leve que mapeia um DriverID do FireDAC ('FB', 'PG', 'MySQL', ...) para
  um CONFIGURADOR — um callback que ajusta o driver link daquele provider (ex.:
  define o VendorLib) a partir da IConnConfig, no momento em que uma conexão
  nativa é criada.

  Desacoplamento (ver plano de camadas):
   - O ENGINE (Conn4D.Engine.FireDAC) chama TFDProviders.Apply no CreateNative,
     sem conhecer nenhum FireDAC.Phys.* nem VCL.
   - Cada PROVIDER UNIT de aplicação (Conn4D.Adapter.FireDAC.Provider.<X>) chama
     TFDProviders.Register na sua initialization, só se for linkada.
   - Se nenhum provider unit registrou um DriverID, Apply é no-op e o FireDAC usa
     a busca padrão de DLL. Opt-in puro.

  Esta unit NÃO depende de FireDAC nem de VCL — apenas Conn4D.Core + RTL — então é
  segura no pacote runtime e no runner de testes (console).
}

interface

uses
  Conn4D.Core;

type
  /// <summary>Callback que configura o driver link de um provider a partir da config.</summary>
  TFDProviderConfigurator = reference to procedure(const ACfg: IConnConfig);

  /// <summary>Registry global (singleton) DriverID -> configurador. Thread-safe.</summary>
  TFDProviders = record
    /// <summary>Registra (ou substitui) o configurador de um DriverID. Case-insensitive.</summary>
    class procedure Register(const ADriverID: string;
      const AConfigurator: TFDProviderConfigurator); static;
    /// <summary>Aplica o configurador do DriverID, se houver. No-op caso contrário.</summary>
    class procedure Apply(const ADriverID: string; const ACfg: IConnConfig); static;
  end;

implementation

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections;

var
  GMap:  TDictionary<string, TFDProviderConfigurator>;
  GLock: TCriticalSection;

function NormKey(const ADriverID: string): string;
begin
  Result := ADriverID.Trim.ToUpper;
end;

{ TFDProviders }

class procedure TFDProviders.Register(const ADriverID: string;
  const AConfigurator: TFDProviderConfigurator);
begin
  if (ADriverID.Trim = '') or (not Assigned(AConfigurator)) then
    Exit;
  GLock.Enter;
  try
    GMap.AddOrSetValue(NormKey(ADriverID), AConfigurator);
  finally
    GLock.Leave;
  end;
end;

class procedure TFDProviders.Apply(const ADriverID: string; const ACfg: IConnConfig);
var
  Configurator: TFDProviderConfigurator;
begin
  GLock.Enter;
  try
    if not GMap.TryGetValue(NormKey(ADriverID), Configurator) then
      Configurator := nil;
  finally
    GLock.Leave;
  end;
  if Assigned(Configurator) then
    Configurator(ACfg);
end;

initialization
  GLock := TCriticalSection.Create;
  GMap  := TDictionary<string, TFDProviderConfigurator>.Create;

finalization
  GMap.Free;
  GLock.Free;

end.
