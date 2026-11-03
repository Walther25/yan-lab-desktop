#requires -version 5.1
<#
.SYNOPSIS
  Arma "Yan Lab · Desktop" a partir de TU copia del Workshop de
  "Rhine Lab · Interactive Desktop" (ítem 3799142774) e instala Yan Bridge.

.DESCRIPTION
  Este repositorio no incluye ningún archivo del fondo original. El script:
    1. busca Wallpaper Engine y tu copia suscrita del fondo original;
    2. verifica que sea exactamente la versión compatible (SHA-256);
    3. la copia a Wallpaper Engine\projects\myprojects\<Name> (la carpeta del Workshop no se toca);
    4. aplica los parches de src\patches y verifica el resultado (SHA-256);
    5. agrega los scripts de src\overlay, pone el idioma en inglés y renombra el proyecto;
    6. instala Yan Bridge (ayudante local en 127.0.0.1), salvo que se use -SkipBridge.

.PARAMETER WorkshopPath
  Carpeta del fondo original. Por defecto se detecta: <biblioteca de Steam>\steamapps\workshop\content\431960\3799142774.

.PARAMETER WallpaperEnginePath
  Carpeta de instalación de Wallpaper Engine. Por defecto se detecta: <biblioteca de Steam>\steamapps\common\wallpaper_engine.

.PARAMETER Name
  Nombre de la carpeta del proyecto nuevo dentro de projects\myprojects. Por defecto: yan-lab-desktop.

.PARAMETER Force
  Reconstruye un proyecto que ya existe (la carpeta anterior se guarda como respaldo con fecha).

.PARAMETER SkipBridge
  Solo arma el fondo. Sin Yan Bridge se comporta como el original, con la interfaz en inglés.
#>
[CmdletBinding()]
param(
  [string]$WorkshopPath = '',
  [string]$WallpaperEnginePath = '',
  [string]$Name = 'yan-lab-desktop',
  [switch]$Force,
  [switch]$SkipBridge
)
$ErrorActionPreference = 'Stop'
$SrcRoot    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)   # ...\src
$PatchDir   = Join-Path $SrcRoot 'patches'
$OverlayDir = Join-Path $SrcRoot 'overlay'
$BridgeDir  = Join-Path $SrcRoot 'bridge'
$Utf8NoBom  = New-Object System.Text.UTF8Encoding($false)
$WorkshopId = '3799142774'

function Write-Step([string]$text) { Write-Host ('  > ' + $text) }
function Fail([string]$text) { Write-Host ''; Write-Host ('  [ERROR] ' + $text) -ForegroundColor Red; Write-Host ''; exit 1 }

function Get-Sha256([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }

# Lee y escribe texto UTF-8 conservando el BOM original (si lo tenía).
function Read-Text([string]$path) {
  $bytes = [IO.File]::ReadAllBytes($path)
  $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  $start = 0; if ($bom) { $start = 3 }
  return @{ Text = $Utf8NoBom.GetString($bytes, $start, $bytes.Length - $start); Bom = $bom }
}
function Write-Text([string]$path, [string]$text, [bool]$bom) {
  $body = $Utf8NoBom.GetBytes($text)
  if ($bom) { $body = [byte[]](0xEF, 0xBB, 0xBF) + $body }
  [IO.File]::WriteAllBytes($path, $body)
}

function Get-Count([string]$text, [string]$find) {
  $n = 0; $i = 0
  while (($i = $text.IndexOf($find, $i, [StringComparison]::Ordinal)) -ge 0) { $n++; $i += $find.Length }
  return $n
}

# Aplica un archivo de parche (operaciones replace / regex / prepend). Cada "replace"
# exige la cantidad exacta de coincidencias indicada en "count" (-1 = cualquiera).
function Invoke-PatchFile([string]$text, [string]$patchFile) {
  $patch = Get-Content -LiteralPath $patchFile -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($op in $patch.operations) {
    switch ($op.op) {
      'replace' {
        $n = Get-Count $text $op.find
        if ($op.count -ge 0 -and $n -ne $op.count) {
          throw ("{0}: se esperaban {1} coincidencia(s) y hay {2}" -f (Split-Path -Leaf $patchFile), $op.count, $n)
        }
        $text = $text.Replace([string]$op.find, [string]$op.replace)
      }
      'regex'   { $text = [regex]::Replace($text, [string]$op.pattern, [string]$op.replace) }
      'prepend' { $text = [string]$op.text + $text }
      default   { throw ("Operación de parche desconocida: " + $op.op) }
    }
  }
  return $text
}

# ---------------------------------------------------------------- bibliotecas de Steam
function Get-SteamLibraries {
  $libs = New-Object System.Collections.Generic.List[string]
  $steam = $null
  try { $steam = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath } catch { }
  if (-not $steam -and ${env:ProgramFiles(x86)}) { $steam = Join-Path ${env:ProgramFiles(x86)} 'Steam' }
  if (-not $steam) { return ,$libs }
  $steam = $steam -replace '/', '\'
  if (Test-Path -LiteralPath $steam) { $libs.Add($steam) }
  $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
  if (Test-Path -LiteralPath $vdf) {
    foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
      $p = $m.Groups[1].Value -replace '\\\\', '\'
      if ((Test-Path -LiteralPath $p) -and -not $libs.Contains($p)) { $libs.Add($p) }
    }
  }
  return ,$libs
}

Write-Host ''
Write-Host '  YAN LAB · DESKTOP  |  instalación' -ForegroundColor White
Write-Host '  ---------------------------------'

$libs = @()
if (-not $WallpaperEnginePath -or -not $WorkshopPath) { $libs = Get-SteamLibraries }
if (-not $WallpaperEnginePath) {
  foreach ($l in $libs) {
    $c = Join-Path $l 'steamapps\common\wallpaper_engine'
    if (Test-Path -LiteralPath (Join-Path $c 'wallpaper64.exe')) { $WallpaperEnginePath = $c; break }
  }
}
if (-not $WallpaperEnginePath -or -not (Test-Path -LiteralPath $WallpaperEnginePath)) {
  Fail 'No se encontró Wallpaper Engine. Ejecutá de nuevo con -WallpaperEnginePath "<carpeta de wallpaper64.exe>".'
}
if (-not $WorkshopPath) {
  foreach ($l in $libs) {
    $c = Join-Path $l ('steamapps\workshop\content\431960\' + $WorkshopId)
    if (Test-Path -LiteralPath (Join-Path $c 'project.json')) { $WorkshopPath = $c; break }
  }
}
if (-not $WorkshopPath -or -not (Test-Path -LiteralPath (Join-Path $WorkshopPath 'project.json'))) {
  Fail ('No se encontró el fondo original. Suscribite al ítem ' + $WorkshopId + ' ("Rhine Lab · Interactive Desktop") en Wallpaper Engine, esperá a que se descargue y ejecutá esto otra vez (o usá -WorkshopPath).')
}
Write-Step ('Wallpaper Engine: ' + $WallpaperEnginePath)
Write-Step ('Fondo original: ' + $WorkshopPath)

# ---------------------------------------------------------------- verificar el original
$manifest = Get-Content -LiteralPath (Join-Path $PatchDir 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$srcBundle = Join-Path $WorkshopPath $manifest.bundle
if (-not (Test-Path -LiteralPath $srcBundle)) { Fail ('Estructura inesperada: falta ' + $manifest.bundle + '. Probablemente el ítem del Workshop se actualizó; ver README > Limitaciones.') }
$srcHash = Get-Sha256 $srcBundle
if ($srcHash -ne $manifest.sourceSha256) {
  Fail ("Versión no compatible del fondo original (SHA-256 $srcHash). Los parches solo sirven para la versión exacta indicada en src\patches\manifest.json. No se cambió nada.")
}
Write-Step 'Versión original verificada (SHA-256 correcto).'

# ---------------------------------------------------------------- copiar
$myprojects = Join-Path $WallpaperEnginePath 'projects\myprojects'
New-Item -ItemType Directory -Force -Path $myprojects | Out-Null
$dest = Join-Path $myprojects $Name
if (Test-Path -LiteralPath $dest) {
  if (-not $Force) { Fail ("Ya existe $dest. Usá -Force para reconstruirlo (la carpeta anterior queda como respaldo) o -Name para elegir otra carpeta.") }
  $backup = $dest + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
  Move-Item -LiteralPath $dest -Destination $backup
  Write-Step ('Carpeta anterior movida a ' + $backup)
}
Write-Step ('Copiando a ' + $dest)
Copy-Item -LiteralPath $WorkshopPath -Destination $dest -Recurse
Get-ChildItem -LiteralPath $dest -Recurse -File | Where-Object { $_.Name -like '*.bak*' } | Remove-Item -Force

try {
  # ------------------------------------------------------------ parches del bundle
  $bundle = Join-Path $dest $manifest.bundle
  $text = (Read-Text $bundle).Text
  foreach ($p in $manifest.bundlePatches) {
    $text = Invoke-PatchFile $text (Join-Path $PatchDir $p)
    Write-Step ('Aplicado ' + $p)
  }
  Write-Text $bundle $text $false
  $outHash = Get-Sha256 $bundle
  if ($outHash -ne $manifest.resultSha256) { throw "El bundle parcheado no coincide con el resultado esperado (SHA-256 $outHash)." }
  Write-Step 'Resultado verificado (SHA-256 correcto).'

  # ------------------------------------------------------------ index.html
  $idx = Join-Path $dest 'index.html'
  $r = Read-Text $idx
  Write-Text $idx (Invoke-PatchFile $r.Text (Join-Path $PatchDir $manifest.htmlPatch)) $r.Bom
  Write-Step 'index.html actualizado (título y scripts del overlay).'

  # ------------------------------------------------------------ TXT exportables de los archivos
  foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $dest 'archives') -Recurse -Filter '*.txt' -ErrorAction SilentlyContinue)) {
    $r = Read-Text $f.FullName
    $t2 = $r.Text.Replace('RHINE LAB', 'YAN LAB').Replace('Rhine Lab', 'Yan Lab')
    if ($t2 -ne $r.Text) { Write-Text $f.FullName $t2 $r.Bom }
  }

  # ------------------------------------------------------------ project.json
  $pj = Join-Path $dest 'project.json'
  $r = Read-Text $pj
  $t = $r.Text
  $desc = 'Yan Lab - Desktop: a local, personal variant of "Rhine Lab - Interactive Desktop" by LBEILC (Steam Workshop ' + $WorkshopId + '), built with the Yan Lab Desktop patch set. Unofficial fan work; Arknights characters, names and setting belong to their respective owners.'
  $descJson = $desc.Replace('\', '\\').Replace('"', '\"')
  $t = [regex]::Replace($t, '(?m)^\t"title"\s*:\s*"(?:[^"\\]|\\.)*"', ("`t" + '"title" : "Yan Lab · Desktop"'))
  $t = [regex]::Replace($t, '(?m)^\t"description"\s*:\s*"(?:[^"\\]|\\.)*"', ("`t" + '"description" : "' + $descJson.Replace('$', '$$') + '"'))
  $t = [regex]::Replace($t, '(?m)^\t"visibility"\s*:\s*"public"', ("`t" + '"visibility" : "private"'))
  $t = [regex]::Replace($t, ',\s*\r?\n\t"workshopid"\s*:\s*"[^"]*"', '')
  $t = [regex]::Replace($t, ',\s*\r?\n\t"workshopurl"\s*:\s*"[^"]*"', '')
  # Idioma por defecto -> inglés (solo el "value" de la propiedad, no la lista de opciones)
  $li = $t.IndexOf('"language"')
  if ($li -ge 0) {
    $ti = $t.IndexOf('"type" : "combo"', $li)
    $vi = $t.IndexOf('"value" : "zh-CN"', [Math]::Max($ti, 0))
    $end = $t.IndexOf("`n`t`t`t}", $li)
    if ($ti -gt $li -and $vi -gt $ti -and $vi -lt $end) { $t = $t.Remove($vi, 17).Insert($vi, '"value" : "en-US"') }
  }
  $check = $t | ConvertFrom-Json
  if ($check.workshopid -or $check.general.properties.language.value -ne 'en-US') { throw 'No se pudo actualizar project.json de forma segura.' }
  Write-Text $pj $t $r.Bom
  Write-Step 'project.json: nombre nuevo, idioma inglés y sin vínculo al Workshop.'

  # ------------------------------------------------------------ overlay y archivos del puente
  Copy-Item -Path (Join-Path $OverlayDir '*') -Destination $dest -Force
  $bridgeDest = Join-Path $dest 'yan-bridge'
  New-Item -ItemType Directory -Force -Path $bridgeDest | Out-Null
  Copy-Item -Path (Join-Path $BridgeDir '*') -Destination $bridgeDest -Force
  # Configuración vacía para que el fondo cargue limpio antes de instalar el puente
  $cfg = Join-Path $dest 'bridge-config.js'
  if (-not (Test-Path -LiteralPath $cfg)) { [IO.File]::WriteAllText($cfg, "window.rhineBridgeConfig = null;`r`n", $Utf8NoBom) }
  Write-Step 'Scripts del overlay y archivos de Yan Bridge agregados.'
}
catch {
  Write-Host ('  ' + $_.Exception.Message) -ForegroundColor Red
  Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
  Fail 'La instalación se detuvo y se borró la carpeta a medio armar. Tu copia del Workshop no se modificó.'
}

if (-not $SkipBridge) {
  Write-Host ''
  & (Join-Path $bridgeDest 'install.ps1')
}

Write-Host ''
Write-Host '  [OK] Yan Lab · Desktop está listo.' -ForegroundColor Green
Write-Host ('       Carpeta del proyecto: ' + $dest)
Write-Host '       En Wallpaper Engine buscá "Yan Lab · Desktop" en tus fondos.'
Write-Host '       Si todavía no aparece, reiniciá Wallpaper Engine una vez.'
Write-Host ''
