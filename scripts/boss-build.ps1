<#
  boss-build.ps1 — compiles the Spring4D core and this package's design/runtime
  packages right after `boss install` (wired via boss.json "scripts.postinstall").

  Goal: a fresh `boss install` leaves the library ready to use, with no manual
  IDE build. All artifacts go to <repo>\bin\<Platform> so nothing pollutes the
  global RAD Studio directories.

  Build matrix (Win32 — the RAD Studio IDE and its design-time packages are
  32-bit; Win64 is intentionally out of scope here):
    Spring.Base / Spring.Core ...... Win32 (Release)
    <Package>.dproj (runtime) ...... Win32 (Release)
    dcl<Package>.dproj (designtime)  Win32 (Release)
#>

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------------
# Per-package configuration (only this block differs between the sibling repos)
# ----------------------------------------------------------------------------
$RuntimeProjects    = @('Conn4D.dproj')        # built Win32 + Win64
$DesigntimeProjects = @('dclConn4D.dproj')     # built Win32 only
$BuildSpringCore    = $true                    # Conn4D requires Spring.Base/Core

# ----------------------------------------------------------------------------
$Root      = Split-Path -Parent $PSScriptRoot
$Bin       = Join-Path $Root 'bin'
$PkgDir    = Join-Path $Root 'packages\Delphi12'

function Resolve-BDS {
  # 1) honour an explicit BDS env var, 2) the registry, 3) the default 23.0 path
  $candidates = @()
  if ($env:BDS) { $candidates += $env:BDS }
  foreach ($hive in @(
      'HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS\23.0',
      'HKLM:\SOFTWARE\Embarcadero\BDS\23.0',
      'HKCU:\SOFTWARE\Embarcadero\BDS\23.0')) {
    try {
      $rd = (Get-ItemProperty -Path $hive -Name RootDir -ErrorAction Stop).RootDir
      if ($rd) { $candidates += $rd }
    } catch { }
  }
  $candidates += 'C:\Program Files (x86)\Embarcadero\Studio\23.0'
  foreach ($c in $candidates) {
    if ($c -and (Test-Path (Join-Path $c 'bin\rsvars.bat'))) { return $c }
  }
  throw 'Delphi 12 (BDS 23.0) not found. Set the BDS environment variable or install RAD Studio 23.0.'
}

function Initialize-DelphiEnv {
  $bds = Resolve-BDS
  $env:BDS          = $bds
  $env:BDSINCLUDE   = Join-Path $bds 'include'
  if (-not $env:BDSCOMMONDIR) {
    $env:BDSCOMMONDIR = Join-Path $env:PUBLIC 'Documents\Embarcadero\Studio\23.0'
  }
  $env:FrameworkDir = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319'
  $env:PATH = "$($env:FrameworkDir);$bds\bin;$bds\bin64;$($env:PATH)"
  Write-Host "Using Delphi at: $bds" -ForegroundColor DarkGray
}

function Resolve-SpringRoot {
  # self/dev layout first, then a flattened-consumer fallback
  foreach ($candidate in @(
      (Join-Path $Root 'modules\Spring4D'),
      (Join-Path (Split-Path -Parent $Root) 'Spring4D'))) {
    if (Test-Path (Join-Path $candidate 'repo\Packages\Delphi11')) { return $candidate }
  }
  return (Join-Path $Root 'modules\Spring4D')
}

function Invoke-DelphiBuild([string]$Project, [string]$Platform) {
  $outDir = Join-Path $Bin $Platform
  $dcuDir = Join-Path $outDir 'dcu'
  New-Item -ItemType Directory -Force -Path $dcuDir | Out-Null
  Write-Host (">> {0} [{1}]" -f ([System.IO.Path]::GetFileName($Project)), $Platform) -ForegroundColor Cyan
  & msbuild $Project /t:Build /p:Config=Release /p:Platform=$Platform `
      /p:DCC_BplOutput=$outDir /p:DCC_DcpOutput=$outDir /p:DCC_DcuOutput=$dcuDir `
      /nologo /v:minimal
  if ($LASTEXITCODE -ne 0) { throw ("Build failed: {0} ({1})" -f $Project, $Platform) }
}

# ----------------------------------------------------------------------------
Write-Host '=== Conn4D boss postinstall build ===' -ForegroundColor Green
Initialize-DelphiEnv

if ($BuildSpringCore) {
  $springRoot = Resolve-SpringRoot
  $springSrc  = Join-Path $springRoot 'repo\Source'
  if (-not (Test-Path $springSrc)) {
    Write-Host 'Spring4D repo\Source missing — fetching via GetRepo.ps1...' -ForegroundColor Yellow
    Push-Location $springRoot
    try { & (Join-Path $springRoot 'GetRepo.ps1') } finally { Pop-Location }
  }
  $springPkg = Join-Path $springRoot 'repo\Packages\Delphi11'
  Invoke-DelphiBuild (Join-Path $springPkg 'Spring.Base.dproj') 'Win32'
  Invoke-DelphiBuild (Join-Path $springPkg 'Spring.Core.dproj') 'Win32'
}

foreach ($proj in $RuntimeProjects) {
  Invoke-DelphiBuild (Join-Path $PkgDir $proj) 'Win32'
}

foreach ($proj in $DesigntimeProjects) {
  Invoke-DelphiBuild (Join-Path $PkgDir $proj) 'Win32'
}

Write-Host '=== build finished — artifacts in bin\Win32 ===' -ForegroundColor Green
