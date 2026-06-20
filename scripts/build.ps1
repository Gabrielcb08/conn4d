<#
  Conn4D - build dos pacotes (linha de comando / CI).

  Compila Conn4D.dpk (runtime) e dclConn4D.dpk (design) com o dcc32 do Delphi,
  gerando BPL/DCP em bin (raiz). Não instala nada na IDE (use install.ps1).

  Uso:
    powershell -ExecutionPolicy Bypass -File build.ps1 [-StudioVer 23.0]
#>
param(
  [string]$StudioVer = "23.0"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path   # raiz\scripts
$root = Join-Path $here ".."
$src  = Join-Path $root "src"
$pkg  = Join-Path $root "packages\Delphi12"
$out  = Join-Path $root "bin"
$dcu  = Join-Path $pkg "build\dcu"

$bin = "${env:ProgramFiles(x86)}\Embarcadero\Studio\$StudioVer\bin"
$dcc = Join-Path $bin "dcc32.exe"
if (-not (Test-Path $dcc)) { throw "dcc32 nao encontrado em $dcc (ajuste -StudioVer)" }

# Regra da Dependencia (Arquitetura Limpa): falha se Core/Shared citarem engine.
& (Join-Path $here "check-architecture.ps1")
if ($LASTEXITCODE -ne 0) { throw "check-architecture falhou (Core/Shared cita engine)" }

New-Item -ItemType Directory -Force -Path $out, $dcu | Out-Null

# Caminhos de unidade (todas as subpastas de src) + include (src para Conn4D.inc).
$unitPath = @(
  $src,
  "$src\Shared",
  "$src\Core\Abstractions",
  "$src\Core\Services",
  "$src\Adapters",
  "$src\Adapters\FireDAC",
  "$src\Adapters\Zeos",
  "$src\Adapters\UniDAC",
  "$src\Component",
  $out
) -join ";"

function Invoke-Dcc([string]$dpk) {
  Write-Host "==> Compilando $dpk" -ForegroundColor Cyan
  # CONN4D_NOAUTOLINK: mantém o pacote runtime agnóstico de UI/driver (sem puxar
  # VCL nem FireDAC.Phys.* via o auto-link do adapter). Apps compilados do source
  # NÃO definem isto e recebem wait-cursor + drivers automaticamente.
  & $dcc -Q -DCONN4D_NOAUTOLINK "-NU$dcu" "-NB$dcu" "-NH$dcu" "-LE$out" "-LN$out" "-U$unitPath" "-I$src" (Join-Path $pkg $dpk)
  if ($LASTEXITCODE -ne 0) { throw "Falha ao compilar $dpk (exit $LASTEXITCODE)" }
}

Invoke-Dcc "Conn4D.dpk"      # runtime primeiro (gera Conn4D.dcp usado pelo design)
Invoke-Dcc "dclConn4D.dpk"   # design

Write-Host "OK. BPLs em: $out" -ForegroundColor Green
Get-ChildItem $out -Filter *.bpl | ForEach-Object { Write-Host "  $($_.Name)" }
