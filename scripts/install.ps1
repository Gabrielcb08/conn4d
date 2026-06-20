<#
  Conn4D - build + instalacao do pacote de design na IDE Delphi.

  1) Compila runtime + design (chama build.ps1).
  2) Registra dclConn4D.bpl em HKCU\Software\Embarcadero\BDS\<ver>\Known Packages,
     fazendo o componente TConn4D aparecer na paleta ORData ao abrir a IDE.

  Feche a IDE antes de rodar. Uso:
    powershell -ExecutionPolicy Bypass -File install.ps1 [-StudioVer 23.0]
#>
param(
  [string]$StudioVer = "23.0"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1) build
& (Join-Path $here "build.ps1") -StudioVer $StudioVer

# 2) registro do BPL de design
$bpl = Join-Path $here "..\bin\dclConn4D.bpl"
if (-not (Test-Path $bpl)) { throw "dclConn4D.bpl nao encontrado em $bpl" }
$bpl = (Resolve-Path $bpl).Path

$key = "HKCU:\Software\Embarcadero\BDS\$StudioVer\Known Packages"
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
New-ItemProperty -Path $key -Name $bpl -Value "Conn4D Design - TConn4D (paleta ORData)" -PropertyType String -Force | Out-Null

Write-Host "Instalado: $bpl" -ForegroundColor Green
Write-Host "Abra a IDE Delphi $StudioVer; TConn4D estara na paleta ORData." -ForegroundColor Green
Write-Host "Dica: adicione packages\out ao PATH (ou copie os BPL) para o runtime ser encontrado." -ForegroundColor Yellow
