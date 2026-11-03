#requires -version 5.1
<#
.SYNOPSIS
  Convierte un fondo de escena o de video de Wallpaper Engine (que tengas o al que estés
  suscrito) en un fondo alternativo local de Yan Lab, con botón "↗ Yan Lab" para volver.

.DESCRIPTION
  El resultado se guarda en Wallpaper Engine\projects\myprojects\<Id> y aparece en el menú
  "Change to Background" de Yan Lab · Desktop (Yan Bridge lista todos los proyectos de esa
  carpeta que tengan la propiedad de acceso directo "yanlab").

  * Escenas (scene.pkg o scene.json): se desempaqueta la escena y se agrega una capa de imagen
    con el botón abajo a la izquierda. Al hacer clic ejecuta el acceso directo "Return to Yan Lab".
  * Videos: un fondo web pequeño reproduce el video a pantalla completa con el mismo botón, que
    le pide a Yan Bridge volver a Yan Lab. Si ffmpeg está en el PATH, el video se convierte por
    defecto a WebM 1080p (VP9/Opus), que se reproduce bien en fondos web y es más liviano.

  La carpeta de origen solo se lee, nunca se modifica. No subas el proyecto generado al
  Workshop: contiene trabajo de otra persona y es solo para tu uso personal.

.EXAMPLE
  .\New-YanLabBackground.ps1 -Source "D:\SteamLibrary\steamapps\workshop\content\431960\123456789" -Title "Night City"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Title,
  [string]$Id = '',
  [string]$WallpaperEnginePath = '',
  [string]$YanLabPath = '',
  [switch]$NoConvert,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$SrcRoot   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)   # ...\src
$Assets    = Join-Path $SrcRoot 'backgrounds'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Dot       = [string][char]0x00B7

function Fail([string]$t) { Write-Host ''; Write-Host ('  [ERROR] ' + $t) -ForegroundColor Red; Write-Host ''; exit 1 }
function Write-Step([string]$t) { Write-Host ('  > ' + $t) }
function Save-Json([string]$path, $obj) { [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $obj -Depth 100), $Utf8NoBom) }

# Paquetes de escena de Wallpaper Engine: int32 largo + "PKGVxxxx", int32 cantidad y, por cada
# entrada, (int32 largo + nombre, int32 posición, int32 tamaño); los datos van después de la tabla.
function Expand-ScenePkg([string]$pkg, [string]$outDir) {
  $fs = [IO.File]::OpenRead($pkg)
  try {
    $br = New-Object IO.BinaryReader($fs)
    $magic = [Text.Encoding]::ASCII.GetString($br.ReadBytes($br.ReadInt32()))
    if (-not $magic.StartsWith('PKGV')) { throw "No es un paquete de escena: $pkg" }
    $count = $br.ReadInt32()
    $entries = @()
    for ($i = 0; $i -lt $count; $i++) {
      $name = [Text.Encoding]::UTF8.GetString($br.ReadBytes($br.ReadInt32()))
      $entries += , @($name, $br.ReadInt32(), $br.ReadInt32())
    }
    $base = $fs.Position
    foreach ($e in $entries) {
      $rel = ($e[0] -replace '/', [IO.Path]::DirectorySeparatorChar)
      $target = [IO.Path]::GetFullPath((Join-Path $outDir $rel))
      if (-not $target.StartsWith([IO.Path]::GetFullPath($outDir))) { throw "Ruta insegura dentro del paquete: $($e[0])" }
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
      $fs.Position = $base + $e[1]
      [IO.File]::WriteAllBytes($target, $br.ReadBytes($e[2]))
    }
    return $entries.Count
  } finally { $fs.Dispose() }
}

# ---------------------------------------------------------------- rutas
if (-not (Test-Path -LiteralPath (Join-Path $Source 'project.json'))) { Fail "No hay project.json en $Source" }
$src = Get-Content -LiteralPath (Join-Path $Source 'project.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$type = [string]$src.type
if ($type -ne 'scene' -and $type -ne 'video') { Fail "Solo se admiten fondos de escena y de video (este es '$type')." }

$wpCfgFile = ''
if ($env:LOCALAPPDATA) { $wpCfgFile = Join-Path $env:LOCALAPPDATA 'RhineBridge\wallpapers.json' }
if (-not $YanLabPath -and $wpCfgFile -and (Test-Path -LiteralPath $wpCfgFile)) {
  $wp = Get-Content -LiteralPath $wpCfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $YanLabPath -and $wp.yanlab) { $YanLabPath = Split-Path -Parent ([string]$wp.yanlab) }
}
if (-not $YanLabPath -or -not (Test-Path -LiteralPath (Join-Path $YanLabPath 'project.json'))) {
  Fail 'No se encontró Yan Lab · Desktop. Instalalo primero o usá -YanLabPath "<...\projects\myprojects\yan-lab-desktop>".'
}
$myprojects = Split-Path -Parent $YanLabPath
if ($WallpaperEnginePath) { $myprojects = Join-Path $WallpaperEnginePath 'projects\myprojects' }

if (-not $Id) { $Id = 'yan-lab-' + (($Title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')) }
if ($Id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Fail "-Id no válido: '$Id'." }
$dest = Join-Path $myprojects $Id
if (Test-Path -LiteralPath $dest) {
  if (-not $Force) { Fail "Ya existe $dest (usá -Force para reconstruirlo)." }
  Remove-Item -LiteralPath $dest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Write-Step ("Creando $Id ($type)")

$props = [ordered]@{}
if ($src.general -and $src.general.properties -and $src.general.properties.schemecolor) {
  $props['schemecolor'] = $src.general.properties.schemecolor
}
$preview = [string]$src.preview
if ($preview -and (Test-Path -LiteralPath (Join-Path $Source $preview))) { Copy-Item -LiteralPath (Join-Path $Source $preview) -Destination $dest }

try {
  if ($type -eq 'scene') {
    # ------------------------------------------------------------ escena
    $pkg = Join-Path $Source 'scene.pkg'
    if (Test-Path -LiteralPath $pkg) { Write-Step ('Se extrajeron ' + (Expand-ScenePkg $pkg $dest) + ' archivos de scene.pkg') }
    else {
      Get-ChildItem -LiteralPath $Source -Force | Where-Object { $_.Name -ne 'project.json' } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force }
    }
    $sceneFile = Join-Path $dest 'scene.json'
    if (-not (Test-Path -LiteralPath $sceneFile)) { throw 'La escena no tiene scene.json.' }
    foreach ($sub in 'materials', 'models') {
      New-Item -ItemType Directory -Force -Path (Join-Path $dest $sub) | Out-Null
      Copy-Item -Path (Join-Path $Assets ('scene\' + $sub + '\*')) -Destination (Join-Path $dest $sub) -Force
    }
    $scene = Get-Content -LiteralPath $sceneFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $w = 1920.0; $h = 1080.0
    $ortho = $scene.general.orthogonalprojection
    if ($ortho -and $ortho.width -and $ortho.height) { $w = [double]$ortho.width; $h = [double]$ortho.height }
    else { Write-Host '  ! La escena no indica su tamaño; el botón se ubica para 1920x1080.' -ForegroundColor Yellow }
    $maxId = 0
    foreach ($o in $scene.objects) { if ($o.id -and [int]$o.id -gt $maxId) { $maxId = [int]$o.id } }
    $btn = Get-Content -LiteralPath (Join-Path $Assets 'scene\button-object.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    # Mismo tamaño y posición relativos que los fondos originales: 7,5 % del ancho, centrado en (8,94 %, 10,68 %) desde abajo a la izquierda.
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $s = $w * 0.5625 / 3840.0
    $btn.id = $maxId + 1
    $btn.origin = ('{0} {1} 0.00000' -f ($w * 343.125 / 3840.0).ToString('0.00000', $inv), ($h * 230.625 / 2160.0).ToString('0.00000', $inv))
    $btn.scale = ('{0} {0} 1.00000' -f $s.ToString('0.00000', $inv))
    $scene.objects = @($scene.objects) + $btn
    Save-Json $sceneFile $scene
    $props['yanlab'] = [ordered]@{ order = 1; text = 'Return to Yan Lab'; type = 'usershortcut'; value = '' }
    $project = [ordered]@{
      contentrating = 'Everyone'
      description   = "Fondo local de Yan Lab basado en '$($src.title)'. Solo para uso personal; los derechos del original pertenecen a su autor."
      file          = 'scene.json'
      general       = [ordered]@{ properties = $props }
      preview       = $preview
      tags          = @($src.tags)
      title         = ('Yan Lab ' + $Dot + ' ' + $Title)
      type          = 'scene'
      version       = 1
      visibility    = 'private'
    }
    Save-Json (Join-Path $dest 'project.json') $project
    Write-Step 'Botón de regreso agregado a la escena.'
  }
  else {
    # ------------------------------------------------------------ video
    $video = Join-Path $Source ([string]$src.file)
    if (-not (Test-Path -LiteralPath $video)) { throw 'No se encontró el archivo de video.' }
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    $videoName = 'background' + [IO.Path]::GetExtension($video).ToLowerInvariant()
    if ($ffmpeg -and -not $NoConvert) {
      $videoName = 'background.webm'
      Write-Step 'Convirtiendo el video a WebM 1080p con ffmpeg (puede tardar varios minutos)...'
      & $ffmpeg.Source -y -hide_banner -loglevel error -i $video -vf "scale='min(1920,iw)':-2:flags=lanczos" -c:v libvpx-vp9 -b:v 0 -crf 31 -deadline good -cpu-used 4 -row-mt 1 -c:a libopus -b:a 128k (Join-Path $dest $videoName)
      if ($LASTEXITCODE -ne 0) { throw 'ffmpeg falló.' }
    } else {
      Copy-Item -LiteralPath $video -Destination (Join-Path $dest $videoName)
      if ([IO.Path]::GetExtension($videoName) -ne '.webm') { Write-Host '  ! El video se copió tal cual. Si no se reproduce, instalá ffmpeg y ejecutá de nuevo (WebM es lo más confiable en fondos web).' -ForegroundColor Yellow }
    }
    $html = [IO.File]::ReadAllText((Join-Path $Assets 'video\index.html'), $Utf8NoBom).Replace('{{VIDEO}}', $videoName).Replace('{{TITLE}}', ('Yan Lab ' + $Dot + ' ' + [Net.WebUtility]::HtmlEncode($Title)))
    [IO.File]::WriteAllText((Join-Path $dest 'index.html'), $html, $Utf8NoBom)
    Copy-Item -LiteralPath (Join-Path $Assets 'video\yanlab_button.png') -Destination $dest
    $cfg = Join-Path $YanLabPath 'bridge-config.js'
    if (Test-Path -LiteralPath $cfg) { Copy-Item -LiteralPath $cfg -Destination $dest }
    else { Write-Host '  ! Yan Bridge todavía no está instalado; el botón de regreso funcionará después de instalarlo y ejecutar esto otra vez.' -ForegroundColor Yellow }
    $props['volume'] = [ordered]@{ order = 1; text = 'Volume'; type = 'slider'; min = 0; max = 100; step = 1; value = 0 }
    $props['yanlab'] = [ordered]@{ order = 2; text = 'Return to Yan Lab'; type = 'usershortcut'; value = '' }
    $project = [ordered]@{
      contentrating = 'Everyone'
      description   = "Fondo local de Yan Lab basado en '$($src.title)'. Solo para uso personal; los derechos del original pertenecen a su autor."
      file          = 'index.html'
      general       = [ordered]@{ properties = $props }
      preview       = $preview
      tags          = @($src.tags)
      title         = ('Yan Lab ' + $Dot + ' ' + $Title)
      type          = 'web'
      version       = 1
      visibility    = 'private'
    }
    Save-Json (Join-Path $dest 'project.json') $project
    Write-Step 'Fondo de video creado.'
  }
}
catch {
  Write-Host ('  ' + $_.Exception.Message) -ForegroundColor Red
  Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
  Fail 'No se creó nada. El fondo de origen no se modificó.'
}

Write-Host ''
Write-Host ('  [OK] ' + $dest) -ForegroundColor Green
Write-Host '       Ya aparece en Yan Lab > Change to Background.'
if ($type -eq 'scene') {
  Write-Host '       Solo la primera vez: abrilo en Wallpaper Engine y asigná "Return to Yan Lab" a'
  Write-Host '       yan-bridge\Return to Yan Lab.lnk (dentro de la carpeta de Yan Lab · Desktop).'
}
Write-Host ''
