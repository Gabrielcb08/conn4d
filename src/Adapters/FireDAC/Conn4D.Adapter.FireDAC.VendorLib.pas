unit Conn4D.Adapter.FireDAC.VendorLib;

{
  Conn4D — Adapter / FireDAC / VendorLib

  Resolve o caminho da BIBLIOTECA CLIENTE nativa de um provider (ex.: fbclient.dll
  do Firebird, libpq.dll do PostgreSQL) a partir da config, por plataforma.

  Regra (ver conn4d-packaging-spec):
   - Lê o caminho configurado da plataforma corrente:
       Win64 -> IConnConfig.VendorLibX64
       Win32 -> IConnConfig.VendorLibX86
   - Se o valor configurado terminar em ".dll", é tratado como caminho COMPLETO
     do arquivo (usado se existir; senão devolve '').
   - Senão é tratado como DIRETÓRIO; quando vazio, assume o default por
     plataforma: <pasta do exe>\dlls\x86  ou  \dlls\x64.
   - Result := <dir>\<ADefaultFileName>; devolve '' se o arquivo não existir
     (deixa o FireDAC tentar a busca padrão do SO) — NUNCA lança.
   - ADefaultFileName = '' significa "só aplica se o usuário apontou um .dll
     explícito" (provedores que usam driver do SO, ex.: MSSQL/ODBC).

  Esta unit NÃO depende de FireDAC nem de VCL — só de Conn4D.Core + RTL — então é
  segura no pacote runtime e no runner de testes (console).
}

interface

uses
  Conn4D.Core;

/// <summary>Diretório-base das client libs para a plataforma corrente
/// (configurado ou o default &lt;exe&gt;\dlls\x86|x64).</summary>
function VendorLibBaseDir(const ACfg: IConnConfig): string;

/// <summary>Caminho completo da client lib, ou '' se não houver arquivo
/// resolvível (ver regras no cabeçalho da unit).</summary>
function ResolveVendorLib(const ACfg: IConnConfig; const ADefaultFileName: string): string;

implementation

uses
  System.SysUtils,
  System.IOUtils;

function PlatformSubdir: string;
begin
{$IFDEF WIN64}
  Result := 'x64';
{$ELSE}
  Result := 'x86';
{$ENDIF}
end;

function ConfiguredValue(const ACfg: IConnConfig): string;
begin
  if ACfg = nil then
    Exit('');
{$IFDEF WIN64}
  Result := ACfg.VendorLibX64.Trim;
{$ELSE}
  Result := ACfg.VendorLibX86.Trim;
{$ENDIF}
end;

function DefaultBaseDir: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
            'dlls\' + PlatformSubdir;
end;

function VendorLibBaseDir(const ACfg: IConnConfig): string;
begin
  Result := ConfiguredValue(ACfg);
  if (Result <> '') and Result.ToLower.EndsWith('.dll') then
    Result := ExtractFileDir(Result);          // valor é um arquivo: usa a pasta dele
  if Result = '' then
    Result := DefaultBaseDir;
end;

function ResolveVendorLib(const ACfg: IConnConfig; const ADefaultFileName: string): string;
var
  Configured, Base: string;
begin
  Configured := ConfiguredValue(ACfg);

  // 1) Usuário apontou um .dll explícito.
  if (Configured <> '') and Configured.ToLower.EndsWith('.dll') then
  begin
    if TFile.Exists(Configured) then
      Exit(Configured);
    Exit('');
  end;

  // 2) Sem default de arquivo e sem .dll explícito: nada a aplicar.
  if ADefaultFileName = '' then
    Exit('');

  // 3) Diretório (configurado ou default) + nome padrão do arquivo.
  if Configured <> '' then
    Base := Configured
  else
    Base := DefaultBaseDir;

  Result := IncludeTrailingPathDelimiter(Base) + ADefaultFileName;
  if not TFile.Exists(Result) then
    Result := '';
end;

end.
