#requires -version 5.1
<#
.SYNOPSIS
  Turns a Wallpaper Engine scene or video wallpaper you own/subscribe to into a local
  "Yan Lab" alternative background with a "Yan Lab" return button.

.DESCRIPTION
  The result is written to Wallpaper Engine\projects\myprojects\<Id> and appears in the
  "Change to Background" menu of Yan Lab - Desktop (Yan Bridge lists every project there
  that has a "yanlab" user-shortcut property).

  * Scene wallpapers (scene.pkg or scene.json): the scene is unpacked and a button image layer
    is added at the bottom-left. Clicking it runs the "Return to Yan Lab" user shortcut.
  * Video wallpapers: a small web wallpaper plays the video full screen with the same button,
    which asks Yan Bridge to switch back. If ffmpeg is on PATH the video is converted to a
    1080p WebM (VP9/Opus) by default, which plays reliably in web wallpapers and is lighter.

  The source folder is only read, never modified. Do not re-upload the generated project to
  the Workshop: it contains someone else's work and is meant for your personal use only.

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
$RepoRoot  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Assets    = Join-Path $RepoRoot 'backgrounds'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Dot       = [string][char]0x00B7

function Fail([string]$t) { Write-Host ''; Write-Host ('  [ERROR] ' + $t) -ForegroundColor Red; Write-Host ''; exit 1 }
function Write-Step([string]$t) { Write-Host ('  > ' + $t) }
function Save-Json([string]$path, $obj) { [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $obj -Depth 100), $Utf8NoBom) }

# Wallpaper Engine scene packages: int32 len + "PKGVxxxx", int32 count, then per entry
# (int32 len + name, int32 offset, int32 size); file data follows the table.
function Expand-ScenePkg([string]$pkg, [string]$outDir) {
  $fs = [IO.File]::OpenRead($pkg)
  try {
    $br = New-Object IO.BinaryReader($fs)
    $magic = [Text.Encoding]::ASCII.GetString($br.ReadBytes($br.ReadInt32()))
    if (-not $magic.StartsWith('PKGV')) { throw "Not a scene package: $pkg" }
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
      if (-not $target.StartsWith([IO.Path]::GetFullPath($outDir))) { throw "Unsafe path in package: $($e[0])" }
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
      $fs.Position = $base + $e[1]
      [IO.File]::WriteAllBytes($target, $br.ReadBytes($e[2]))
    }
    return $entries.Count
  } finally { $fs.Dispose() }
}

# ---------------------------------------------------------------- paths
if (-not (Test-Path -LiteralPath (Join-Path $Source 'project.json'))) { Fail "No project.json in $Source" }
$src = Get-Content -LiteralPath (Join-Path $Source 'project.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$type = [string]$src.type
if ($type -ne 'scene' -and $type -ne 'video') { Fail "Only scene and video wallpapers are supported (this one is '$type')." }

$wpCfgFile = ''
if ($env:LOCALAPPDATA) { $wpCfgFile = Join-Path $env:LOCALAPPDATA 'RhineBridge\wallpapers.json' }
if (-not $YanLabPath -and $wpCfgFile -and (Test-Path -LiteralPath $wpCfgFile)) {
  $wp = Get-Content -LiteralPath $wpCfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $YanLabPath -and $wp.yanlab) { $YanLabPath = Split-Path -Parent ([string]$wp.yanlab) }
}
if (-not $YanLabPath -or -not (Test-Path -LiteralPath (Join-Path $YanLabPath 'project.json'))) {
  Fail 'Yan Lab - Desktop was not found. Run setup first, or pass -YanLabPath "<...\projects\myprojects\yan-lab-desktop>".'
}
$myprojects = Split-Path -Parent $YanLabPath
if ($WallpaperEnginePath) { $myprojects = Join-Path $WallpaperEnginePath 'projects\myprojects' }

if (-not $Id) { $Id = 'yan-lab-' + (($Title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')) }
if ($Id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Fail "Invalid -Id '$Id'." }
$dest = Join-Path $myprojects $Id
if (Test-Path -LiteralPath $dest) {
  if (-not $Force) { Fail "$dest already exists (use -Force to rebuild it)." }
  Remove-Item -LiteralPath $dest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Write-Step ("Creating $Id ($type)")

$props = [ordered]@{}
if ($src.general -and $src.general.properties -and $src.general.properties.schemecolor) {
  $props['schemecolor'] = $src.general.properties.schemecolor
}
$preview = [string]$src.preview
if ($preview -and (Test-Path -LiteralPath (Join-Path $Source $preview))) { Copy-Item -LiteralPath (Join-Path $Source $preview) -Destination $dest }

try {
  if ($type -eq 'scene') {
    # ------------------------------------------------------------ scene
    $pkg = Join-Path $Source 'scene.pkg'
    if (Test-Path -LiteralPath $pkg) { Write-Step ('Unpacked ' + (Expand-ScenePkg $pkg $dest) + ' files from scene.pkg') }
    else {
      Get-ChildItem -LiteralPath $Source -Force | Where-Object { $_.Name -ne 'project.json' } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force }
    }
    $sceneFile = Join-Path $dest 'scene.json'
    if (-not (Test-Path -LiteralPath $sceneFile)) { throw 'scene.json not found in the scene.' }
    foreach ($sub in 'materials', 'models') {
      New-Item -ItemType Directory -Force -Path (Join-Path $dest $sub) | Out-Null
      Copy-Item -Path (Join-Path $Assets ('scene\' + $sub + '\*')) -Destination (Join-Path $dest $sub) -Force
    }
    $scene = Get-Content -LiteralPath $sceneFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $w = 1920.0; $h = 1080.0
    $ortho = $scene.general.orthogonalprojection
    if ($ortho -and $ortho.width -and $ortho.height) { $w = [double]$ortho.width; $h = [double]$ortho.height }
    else { Write-Host '  ! The scene has no orthographic size; the button is placed for 1920x1080.' -ForegroundColor Yellow }
    $maxId = 0
    foreach ($o in $scene.objects) { if ($o.id -and [int]$o.id -gt $maxId) { $maxId = [int]$o.id } }
    $btn = Get-Content -LiteralPath (Join-Path $Assets 'scene\button-object.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    # Same relative size and position as the original backgrounds: 7.5% of the width, centred at (8.94%, 10.68%) from the bottom-left.
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
      description   = "Local Yan Lab background based on '$($src.title)'. Personal use only; all rights to the original belong to its author."
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
    Write-Step 'Return button added to the scene.'
  }
  else {
    # ------------------------------------------------------------ video
    $video = Join-Path $Source ([string]$src.file)
    if (-not (Test-Path -LiteralPath $video)) { throw 'Video file not found.' }
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    $videoName = 'background' + [IO.Path]::GetExtension($video).ToLowerInvariant()
    if ($ffmpeg -and -not $NoConvert) {
      $videoName = 'background.webm'
      Write-Step 'Converting the video to 1080p WebM with ffmpeg (this can take several minutes)...'
      & $ffmpeg.Source -y -hide_banner -loglevel error -i $video -vf "scale='min(1920,iw)':-2:flags=lanczos" -c:v libvpx-vp9 -b:v 0 -crf 31 -deadline good -cpu-used 4 -row-mt 1 -c:a libopus -b:a 128k (Join-Path $dest $videoName)
      if ($LASTEXITCODE -ne 0) { throw 'ffmpeg failed.' }
    } else {
      Copy-Item -LiteralPath $video -Destination (Join-Path $dest $videoName)
      if ([IO.Path]::GetExtension($videoName) -ne '.webm') { Write-Host '  ! Video copied as-is. If it does not play, install ffmpeg and run again (WebM plays most reliably in web wallpapers).' -ForegroundColor Yellow }
    }
    $html = [IO.File]::ReadAllText((Join-Path $Assets 'video\index.html'), $Utf8NoBom).Replace('{{VIDEO}}', $videoName).Replace('{{TITLE}}', ('Yan Lab ' + $Dot + ' ' + [Net.WebUtility]::HtmlEncode($Title)))
    [IO.File]::WriteAllText((Join-Path $dest 'index.html'), $html, $Utf8NoBom)
    Copy-Item -LiteralPath (Join-Path $Assets 'video\yanlab_button.png') -Destination $dest
    $cfg = Join-Path $YanLabPath 'bridge-config.js'
    if (Test-Path -LiteralPath $cfg) { Copy-Item -LiteralPath $cfg -Destination $dest }
    else { Write-Host '  ! Yan Bridge is not installed yet; the return button will work after installing it and running this again.' -ForegroundColor Yellow }
    $props['volume'] = [ordered]@{ order = 1; text = 'Volume'; type = 'slider'; min = 0; max = 100; step = 1; value = 0 }
    $props['yanlab'] = [ordered]@{ order = 2; text = 'Return to Yan Lab'; type = 'usershortcut'; value = '' }
    $project = [ordered]@{
      contentrating = 'Everyone'
      description   = "Local Yan Lab background based on '$($src.title)'. Personal use only; all rights to the original belong to its author."
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
    Write-Step 'Video background created.'
  }
}
catch {
  Write-Host ('  ' + $_.Exception.Message) -ForegroundColor Red
  Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
  Fail 'Nothing was created. The source wallpaper was not modified.'
}

Write-Host ''
Write-Host ('  [OK] ' + $dest) -ForegroundColor Green
Write-Host '       It now appears in Yan Lab > Change to Background.'
if ($type -eq 'scene') {
  Write-Host '       First time only: open it in Wallpaper Engine and set "Return to Yan Lab" to'
  Write-Host '       yan-bridge\Return to Yan Lab.lnk (inside the Yan Lab - Desktop folder).'
}
Write-Host ''
