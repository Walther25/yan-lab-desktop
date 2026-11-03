#requires -version 5.1
# Yan Bridge installer for the "Yan Lab · Desktop" wallpaper.
param([int]$Port = 47831)
$ErrorActionPreference = 'Stop'

$here      = Split-Path -Parent $MyInvocation.MyCommand.Path
$wallpaper = Split-Path -Parent $here
$appDir    = Join-Path $env:LOCALAPPDATA 'RhineBridge'
$tokenFile = Join-Path $appDir 'token.txt'
$startup   = [Environment]::GetFolderPath('Startup')
$shortcut  = Join-Path $startup 'Yan Bridge.lnk'
$legacyLnk = Join-Path $startup 'Rhine Bridge.lnk'

Write-Host ''
Write-Host '  YAN LAB · BRIDGE — setup' -ForegroundColor White
Write-Host '  -------------------------'

# 1. Detener una instancia anterior (si existe)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -and $_.CommandLine -like '*RhineBridge*rhine-bridge.ps1*' } |
  ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }
Start-Sleep -Milliseconds 400

# 2. Copiar el servidor a %LOCALAPPDATA%\RhineBridge
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
Copy-Item -LiteralPath (Join-Path $here 'rhine-bridge.ps1') -Destination (Join-Path $appDir 'rhine-bridge.ps1') -Force
Copy-Item -LiteralPath (Join-Path $here 'editor.html') -Destination (Join-Path $appDir 'editor.html') -Force

# 3. Token secreto (se conserva si ya existía)
if (-not (Test-Path -LiteralPath $tokenFile)) {
  $bytes = New-Object byte[] 32
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  $rng.GetBytes($bytes)
  $token = -join ($bytes | ForEach-Object { $_.ToString('x2') })
  Set-Content -LiteralPath $tokenFile -Value $token -Encoding ASCII -NoNewline
}
$token = (Get-Content -LiteralPath $tokenFile -Raw).Trim()

# 3b. Ubicaciones (se regenera en cada instalación; editable a mano)
$desktop = [Environment]::GetFolderPath('Desktop')
$roots = New-Object System.Collections.Generic.List[object]
foreach ($pair in @(@('pc-settings','PC settings'), @('clients','Clients'), @('apps','Apps'), @('games','Games'))) {
  $p = Join-Path $desktop $pair[1]
  if (Test-Path -LiteralPath $p -PathType Container) {
    $roots.Add([ordered]@{ id = $pair[0]; label = $pair[1]; path = $p; launch = $true })
  }
}
$roots.Add([ordered]@{ id = 'documents'; label = 'Documents'; path = [Environment]::GetFolderPath('MyDocuments'); launch = $false })
[IO.File]::WriteAllText((Join-Path $appDir 'roots.json'), (ConvertTo-Json -InputObject $roots -Depth 4), (New-Object Text.UTF8Encoding($false)))

# 3c. Cambio de fondo: rutas de Yan Lab y de la escena de Reshiram + acceso directo de regreso
$myprojects = Split-Path -Parent $wallpaper
$weProc = Get-Process -Name 'wallpaper64', 'wallpaper32' -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
$weExe = if ($weProc) { $weProc.Path } else { Join-Path (Split-Path -Parent (Split-Path -Parent $myprojects)) 'wallpaper64.exe' }
$wpCfg = [ordered]@{
  yanlab   = (Join-Path $wallpaper 'project.json')
  reshiram = (Join-Path $myprojects 'yan-lab-reshiram\project.json')
  weExe    = $weExe
}
[IO.File]::WriteAllText((Join-Path $appDir 'wallpapers.json'), (ConvertTo-Json -InputObject $wpCfg), (New-Object Text.UTF8Encoding($false)))
$q = [char]34
$retVbs = Join-Path $appDir 'return-to-yanlab.vbs'
$vbsLines = @(
  'On Error Resume Next',
  'Dim ok : ok = False',
  'Set h = CreateObject("MSXML2.ServerXMLHTTP.6.0")',
  ('h.open "POST", "http://127.0.0.1:' + $Port + '/api/wallpaper?target=yanlab&token=' + $token + '", False'),
  'h.setRequestHeader "Content-Type", "text/plain"',
  'h.send ""',
  'If Err.Number = 0 Then If h.status = 200 Then ok = True',
  'If Not ok Then',
  '  Err.Clear',
  ('  CreateObject("WScript.Shell").Run ' + $q + $q + $q + $weExe + $q + $q + ' -control openWallpaper -file ' + $q + $q + $wpCfg.yanlab + $q + $q + $q + ', 0, False'),
  'End If')
Set-Content -LiteralPath $retVbs -Value $vbsLines -Encoding ASCII
$retLnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $here 'Return to Yan Lab.lnk'))
$retLnk.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
$retLnk.Arguments = '"' + $retVbs + '"'
$retLnk.WorkingDirectory = $appDir
$retLnk.Description = 'Switch the wallpaper back to Yan Lab'
$retLnk.Save()

# 4. Configuración que lee el fondo
$cfg = "window.rhineBridgeConfig = { port: $Port, token: `"$token`" };`r`n"
[IO.File]::WriteAllText((Join-Path $wallpaper 'bridge-config.js'), $cfg, (New-Object Text.UTF8Encoding($false)))

# 5. Lanzador oculto + arranque automático al iniciar sesión
$launcher = Join-Path $appDir 'launch.vbs'
$ps1 = Join-Path $appDir 'rhine-bridge.ps1'
$vbs = 'CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""' + $ps1 + '"" -Port ' + $Port + '", 0, False'
Set-Content -LiteralPath $launcher -Value $vbs -Encoding ASCII

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($shortcut)
$lnk.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
$lnk.Arguments = '"' + $launcher + '"'
$lnk.WorkingDirectory = $appDir
$lnk.Description = 'Yan Bridge: lists and opens desktop folders and Documents for the Yan Lab wallpaper'
$lnk.Save()
if (Test-Path -LiteralPath $legacyLnk) { Remove-Item -LiteralPath $legacyLnk -Force }

# 6. Arrancar ahora y comprobar
Start-Process -FilePath (Join-Path $env:WINDIR 'System32\wscript.exe') -ArgumentList ('"' + $launcher + '"')
$ok = $false
for ($i = 0; $i -lt 20 -and -not $ok; $i++) {
  Start-Sleep -Milliseconds 400
  try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/ping?token=$token" -TimeoutSec 2
    if ($r.ok) { $ok = $true }
  } catch { }
}

Write-Host ''
if ($ok) {
  Write-Host '  [OK] Yan Bridge is running.' -ForegroundColor Green
  foreach ($x in $r.roots) { Write-Host ("       · " + $x.label + "  ->  " + $x.path) }
  Write-Host  '       It will start automatically every time you sign in.'
  Write-Host ''
  Write-Host '  Now reload the wallpaper in Wallpaper Engine.'
} else {
  Write-Host '  [ERROR] The bridge did not respond.' -ForegroundColor Red
  Write-Host ("          Check the log: " + (Join-Path $appDir 'bridge.log'))
}
Write-Host ''
