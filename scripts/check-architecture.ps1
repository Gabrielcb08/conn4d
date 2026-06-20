<#
  Conn4D - Regra da Dependencia (Arquitetura Limpa) como invariante executavel.

  Falha (exit 1) se qualquer unit do anel interno (src\Core, src\Shared) citar, em
  CODIGO (fora de comentarios), um nome de framework de engine ou o seam de
  fronteira. O nucleo de politicas (pool/GC/manager/portas) tem de permanecer livre
  de FireDAC/Zeos/UniDAC e do Conn4D.Adapter.ConnRef. As fronteiras (src\Adapters,
  componente) podem citar.

  Comentarios ({...}, (* *), //) sao ignorados (preservando as linhas) para que a
  documentacao possa mencionar os tipos ao explicar a propria regra.

  Uso:
    powershell -ExecutionPolicy Bypass -File check-architecture.ps1
#>
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Join-Path $here ".."
$src  = Join-Path $root "src"

$innerDirs = @(
  (Join-Path $src "Core"),
  (Join-Path $src "Shared")
)

# Tokens proibidos no anel interno (frameworks de engine + seam de fronteira).
$forbidden = @(
  'FireDAC',
  'ZConnection',
  '\bUni\b',
  'Conn4D\.Adapter',
  'Conn4D\.ConnRef'
)
$pattern = ($forbidden -join '|')

# Substitui um comentario pela mesma quantidade de quebras de linha (preserva linhas).
$keepNewlines = [System.Text.RegularExpressions.MatchEvaluator] {
  param($m) ($m.Value -replace '[^\r\n]', '')
}

$violations = @()
foreach ($dir in $innerDirs) {
  if (-not (Test-Path $dir)) { continue }
  Get-ChildItem -Path $dir -Recurse -Filter *.pas -File | ForEach-Object {
    $file = $_
    $text = [System.IO.File]::ReadAllText($file.FullName)
    # Remove comentarios (mantendo linhas): {...}, (* *), //
    $code = [regex]::Replace($text, '\{[^}]*\}', $keepNewlines)
    $code = [regex]::Replace($code, '\(\*.*?\*\)', $keepNewlines, 'Singleline')
    $code = [regex]::Replace($code, '//[^\r\n]*', '')

    $n = 0
    foreach ($line in ($code -split "`n")) {
      $n++
      if ($line -match $pattern) {
        $violations += [pscustomobject]@{
          File = $file.FullName.Substring($root.Length + 1)
          Line = $n
          Text = $line.Trim()
        }
      }
    }
  }
}

if ($violations.Count -gt 0) {
  Write-Host "VIOLACAO da Regra da Dependencia (Core/Shared cita engine/seam):" -ForegroundColor Red
  $violations | ForEach-Object { Write-Host ("  {0}:{1}  {2}" -f $_.File, $_.Line, $_.Text) -ForegroundColor Yellow }
  exit 1
}

Write-Host "OK: Core/Shared livres de engine (Regra da Dependencia respeitada)." -ForegroundColor Green
exit 0
