#requires -version 5.1
<#
.SYNOPSIS
  Builds "Yan Lab - Desktop" from your own Steam Workshop copy of
  "Rhine Lab - Interactive Desktop" (Workshop item 3799142774) and installs Yan Bridge.

.DESCRIPTION
  This repository does not ship any file of the original wallpaper. The script:
    1. finds Wallpaper Engine and your subscribed copy of the original wallpaper;
    2. checks that it is exactly the supported version (SHA-256);
    3. copies it to Wallpaper Engine\projects\myprojects\<Name> (the Workshop folder is never modified);
    4. applies the patches in ..\patches and verifies the result (SHA-256);
    5. adds the overlay scripts, switches the default language to English and renames the project;
    6. installs Yan Bridge (local helper on 127.0.0.1) unless -SkipBridge is given.

.PARAMETER WorkshopPath
  Folder of the original wallpaper. Default: auto-detected Steam library\steamapps\workshop\content\431960\3799142774.

.PARAMETER WallpaperEnginePath
  Wallpaper Engine install folder. Default: auto-detected (Steam library\steamapps\common\wallpaper_engine).

.PARAMETER Name
  Folder name of the new project inside projects\myprojects. Default: yan-lab-desktop.

.PARAMETER Force
  Replace an existing project folder with the same name (its old contents are moved to a timestamped backup).

.PARAMETER SkipBridge
  Build the wallpaper only. Without Yan Bridge it behaves like the original wallpaper plus English UI.
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
$RepoRoot   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$PatchDir   = Join-Path $RepoRoot 'patches'
$OverlayDir = Join-Path $RepoRoot 'overlay'
$BridgeDir  = Join-Path $RepoRoot 'bridge'
$Utf8NoBom  = New-Object System.Text.UTF8Encoding($false)
$WorkshopId = '3799142774'

function Write-Step([string]$text) { Write-Host ('  > ' + $text) }
function Fail([string]$text) { Write-Host ''; Write-Host ('  [ERROR] ' + $text) -ForegroundColor Red; Write-Host ''; exit 1 }

function Get-Sha256([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }

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

function Invoke-PatchFile([string]$text, [string]$patchFile) {
  $patch = Get-Content -LiteralPath $patchFile -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($op in $patch.operations) {
    switch ($op.op) {
      'replace' {
        $n = Get-Count $text $op.find
        if ($op.count -ge 0 -and $n -ne $op.count) {
          throw ("{0}: expected {1} match(es), found {2}" -f (Split-Path -Leaf $patchFile), $op.count, $n)
        }
        $text = $text.Replace([string]$op.find, [string]$op.replace)
      }
      'regex'   { $text = [regex]::Replace($text, [string]$op.pattern, [string]$op.replace) }
      'prepend' { $text = [string]$op.text + $text }
      default   { throw ("Unknown patch operation: " + $op.op) }
    }
  }
  return $text
}

# ---------------------------------------------------------------- locate Steam
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
Write-Host '  YAN LAB - DESKTOP  |  setup' -ForegroundColor White
Write-Host '  ---------------------------'

$libs = @()
if (-not $WallpaperEnginePath -or -not $WorkshopPath) { $libs = Get-SteamLibraries }
if (-not $WallpaperEnginePath) {
  foreach ($l in $libs) {
    $c = Join-Path $l 'steamapps\common\wallpaper_engine'
    if (Test-Path -LiteralPath (Join-Path $c 'wallpaper64.exe')) { $WallpaperEnginePath = $c; break }
  }
}
if (-not $WallpaperEnginePath -or -not (Test-Path -LiteralPath $WallpaperEnginePath)) {
  Fail 'Wallpaper Engine was not found. Run again with -WallpaperEnginePath "<folder of wallpaper64.exe>".'
}
if (-not $WorkshopPath) {
  foreach ($l in $libs) {
    $c = Join-Path $l ('steamapps\workshop\content\431960\' + $WorkshopId)
    if (Test-Path -LiteralPath (Join-Path $c 'project.json')) { $WorkshopPath = $c; break }
  }
}
if (-not $WorkshopPath -or -not (Test-Path -LiteralPath (Join-Path $WorkshopPath 'project.json'))) {
  Fail ('The original wallpaper was not found. Subscribe to Workshop item ' + $WorkshopId + ' ("Rhine Lab - Interactive Desktop") in Wallpaper Engine, wait for the download, then run this again (or pass -WorkshopPath).')
}
Write-Step ('Wallpaper Engine: ' + $WallpaperEnginePath)
Write-Step ('Original wallpaper: ' + $WorkshopPath)

# ---------------------------------------------------------------- verify source
$manifest = Get-Content -LiteralPath (Join-Path $PatchDir 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$srcBundle = Join-Path $WorkshopPath $manifest.bundle
if (-not (Test-Path -LiteralPath $srcBundle)) { Fail ('Unexpected wallpaper layout: ' + $manifest.bundle + ' is missing. The Workshop item was probably updated; see README > Compatibility.') }
$srcHash = Get-Sha256 $srcBundle
if ($srcHash -ne $manifest.sourceSha256) {
  Fail ("Unsupported version of the original wallpaper (SHA-256 $srcHash). These patches only fit the exact build listed in patches\manifest.json. Nothing was changed. See README > Compatibility.")
}
Write-Step 'Original build verified (SHA-256 matches).'

# ---------------------------------------------------------------- copy
$myprojects = Join-Path $WallpaperEnginePath 'projects\myprojects'
New-Item -ItemType Directory -Force -Path $myprojects | Out-Null
$dest = Join-Path $myprojects $Name
if (Test-Path -LiteralPath $dest) {
  if (-not $Force) { Fail ("$dest already exists. Use -Force to rebuild it (the old folder is kept as a backup) or -Name to choose another folder.") }
  $backup = $dest + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
  Move-Item -LiteralPath $dest -Destination $backup
  Write-Step ('Previous folder moved to ' + $backup)
}
Write-Step ('Copying to ' + $dest)
Copy-Item -LiteralPath $WorkshopPath -Destination $dest -Recurse
Get-ChildItem -LiteralPath $dest -Recurse -File | Where-Object { $_.Name -like '*.bak*' } | Remove-Item -Force

try {
  # ------------------------------------------------------------ bundle patches
  $bundle = Join-Path $dest $manifest.bundle
  $text = (Read-Text $bundle).Text
  foreach ($p in $manifest.bundlePatches) {
    $text = Invoke-PatchFile $text (Join-Path $PatchDir $p)
    Write-Step ('Applied ' + $p)
  }
  Write-Text $bundle $text $false
  $outHash = Get-Sha256 $bundle
  if ($outHash -ne $manifest.resultSha256) { throw "Patched bundle does not match the expected result (SHA-256 $outHash)." }
  Write-Step 'Patched build verified (SHA-256 matches).'

  # ------------------------------------------------------------ index.html
  $idx = Join-Path $dest 'index.html'
  $r = Read-Text $idx
  Write-Text $idx (Invoke-PatchFile $r.Text (Join-Path $PatchDir $manifest.htmlPatch)) $r.Bom
  Write-Step 'index.html updated (title + overlay scripts).'

  # ------------------------------------------------------------ archive TXT exports
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
  $t = [regex]::Replace($t, '(?m)^\t"title"\s*:\s*"(?:[^"\\]|\\.)*"', ("`t" + '"title" : "Yan Lab ' + [char]0x00B7 + ' Desktop"'))
  $descJson = $desc.Replace('\', '\\').Replace('"', '\"')
  $t = [regex]::Replace($t, '(?m)^\t"description"\s*:\s*"(?:[^"\\]|\\.)*"', ("`t" + '"description" : "' + $descJson.Replace('$', '$$') + '"'))
  $t = [regex]::Replace($t, '(?m)^\t"visibility"\s*:\s*"public"', ("`t" + '"visibility" : "private"'))
  $t = [regex]::Replace($t, ',\s*\r?\n\t"workshopid"\s*:\s*"[^"]*"', '')
  $t = [regex]::Replace($t, ',\s*\r?\n\t"workshopurl"\s*:\s*"[^"]*"', '')
  # default language -> English (only the property's own "value", not the option list)
  $li = $t.IndexOf('"language"')
  if ($li -ge 0) {
    $ti = $t.IndexOf('"type" : "combo"', $li)
    $vi = $t.IndexOf('"value" : "zh-CN"', [Math]::Max($ti, 0))
    $end = $t.IndexOf("`n`t`t`t}", $li)
    if ($ti -gt $li -and $vi -gt $ti -and $vi -lt $end) { $t = $t.Remove($vi, 17).Insert($vi, '"value" : "en-US"') }
  }
  $check = $t | ConvertFrom-Json
  if ($check.workshopid -or $check.general.properties.language.value -ne 'en-US') { throw 'project.json could not be updated safely.' }
  Write-Text $pj $t $r.Bom
  Write-Step 'project.json: renamed, set to English, unlinked from the Workshop item.'

  # ------------------------------------------------------------ overlay + bridge files
  Copy-Item -Path (Join-Path $OverlayDir '*') -Destination $dest -Force
  $bridgeDest = Join-Path $dest 'yan-bridge'
  New-Item -ItemType Directory -Force -Path $bridgeDest | Out-Null
  Copy-Item -Path (Join-Path $BridgeDir '*') -Destination $bridgeDest -Force
  # placeholder so the page loads cleanly before the bridge is installed
  $cfg = Join-Path $dest 'bridge-config.js'
  if (-not (Test-Path -LiteralPath $cfg)) { [IO.File]::WriteAllText($cfg, "window.rhineBridgeConfig = null;`r`n", $Utf8NoBom) }
  Write-Step 'Overlay scripts and Yan Bridge files added.'
}
catch {
  Write-Host ('  ' + $_.Exception.Message) -ForegroundColor Red
  Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
  Fail 'Setup stopped and the half-built folder was removed. Your Workshop copy was not modified.'
}

if (-not $SkipBridge) {
  Write-Host ''
  & (Join-Path $bridgeDest 'install.ps1')
}

Write-Host ''
Write-Host '  [OK] Yan Lab - Desktop is ready.' -ForegroundColor Green
Write-Host ('       Project folder: ' + $dest)
Write-Host '       In Wallpaper Engine: Open from file... or look under "My Wallpapers" for "Yan Lab - Desktop".'
Write-Host '       If it does not appear yet, restart Wallpaper Engine once.'
Write-Host ''
