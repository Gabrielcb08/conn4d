<#
  Conn4D - hook de postinstall do Boss.

  Chamado por `boss install` (ver boss.json > scripts.postinstall). Apenas
  delega para build.ps1, que compila os pacotes runtime/design com o dcc32.
  Mantido separado para casar com a convenção do template (scripts/boss-build.ps1).
#>
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "build.ps1")
