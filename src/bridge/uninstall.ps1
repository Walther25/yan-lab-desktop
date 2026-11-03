#requires -version 5.1
# Uninstalls Yan Bridge: stops the server and removes automatic startup.
$ErrorActionPreference = 'Continue'
$appDir   = Join-Path $env:LOCALAPPDATA 'RhineBridge'
$startup  = [Environment]::GetFolderPath('Startup')

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -and $_.CommandLine -like '*RhineBridge*rhine-bridge.ps1*' } |
  ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }

foreach ($n in @('Yan Bridge.lnk','Rhine Bridge.lnk')) { $l = Join-Path $startup $n; if (Test-Path -LiteralPath $l) { Remove-Item -LiteralPath $l -Force } }
if (Test-Path -LiteralPath $appDir)   { Remove-Item -LiteralPath $appDir -Recurse -Force }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg  = Join-Path (Split-Path -Parent $here) 'bridge-config.js'
if (Test-Path -LiteralPath $cfg) { Remove-Item -LiteralPath $cfg -Force }

Write-Host ''
Write-Host '  Yan Bridge uninstalled. Archives will show only the original files again.'
Write-Host ''
