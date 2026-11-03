#requires -version 5.1
<#
  Rhine Bridge - servidor local mínimo para el fondo "Rhine Lab · Documents".

  Qué hace:
    * Escucha SOLO en 127.0.0.1 (loopback); no acepta conexiones de la red.
    * Exige un token secreto (generado por el instalador) en cada petición.
    * GET  /api/ping                        -> estado y lista de ubicaciones (roots.json).
    * GET  /api/list?root=<id>&path=<rel>   -> contenido de una carpeta dentro de una ubicación.
    * POST /api/open {"root":"<id>","path":"<rel>","reveal":false}
                                            -> abre el archivo con su aplicación predeterminada,
                                               la carpeta en el Explorador, o el acceso directo.
  Qué NO hace:
    * No ejecuta comandos arbitrarios ni acepta rutas fuera de las ubicaciones configuradas.
    * En ubicaciones de tipo "launcher" (Apps, Games…) abre accesos directos (.lnk, .url),
      .exe y .jar, porque esa es su función. Los scripts (.bat, .ps1, .vbs…) nunca se
      ejecutan: se muestran seleccionados en el Explorador.
    * En Documents ningún ejecutable ni acceso directo se ejecuta: se muestra en el Explorador.
#>
param(
  [int]$Port = 47831,
  [string]$AppDir = '',
  [string]$Root = '',
  [switch]$DryRun          # solo para pruebas: registra la acción en vez de abrir nada
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

if (-not $AppDir) { $AppDir = Join-Path $env:LOCALAPPDATA 'RhineBridge' }
$Sep      = [IO.Path]::DirectorySeparatorChar
$TokenFile = Join-Path $AppDir 'token.txt'
$RootsFile = Join-Path $AppDir 'roots.json'
$LogFile   = Join-Path $AppDir 'bridge.log'
$Utf8      = New-Object System.Text.UTF8Encoding($false)
$Cmp       = [StringComparison]::OrdinalIgnoreCase
$MaxItems  = 400

$BlockedExt = @('.exe','.com','.bat','.cmd','.ps1','.psm1','.psd1','.vbs','.vbe','.js','.jse',
  '.wsf','.wsh','.msi','.msp','.mst','.scr','.pif','.reg','.lnk','.url','.hta','.cpl','.jar',
  '.appref-ms','.application','.gadget','.inf','.scf','.msc','.settingcontent-ms','.sys','.dll',
  '.ocx','.drv','.lib','.chm','.website','.xbap','.appx','.msix','.appxbundle','.msixbundle')
# Lo que SÍ se abre en ubicaciones "launcher".
$LaunchExt = @('.lnk','.url','.exe','.jar','.appref-ms')

function Write-Log([string]$msg) {
  try {
    if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length -gt 262144)) {
      Set-Content -LiteralPath $LogFile -Value '' -Encoding UTF8
    }
    Add-Content -LiteralPath $LogFile -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg) -Encoding UTF8
  } catch { }
}

if (-not (Test-Path -LiteralPath $TokenFile)) { Write-Log 'token.txt is missing; run the installer.'; exit 1 }
$Token = (Get-Content -LiteralPath $TokenFile -Raw).Trim()
if ($Token.Length -lt 32) { Write-Log 'Invalid token.'; exit 1 }

# ---- Ubicaciones --------------------------------------------------------------
$Roots = New-Object System.Collections.Generic.List[object]
function Add-Root([string]$id, [string]$label, [string]$path, [bool]$launch) {
  if (-not $path) { return }
  if (-not (Test-Path -LiteralPath $path -PathType Container)) { Write-Log "Location not found: $path"; return }
  $Roots.Add([pscustomobject]@{ id = $id; label = $label; full = [IO.Path]::GetFullPath($path).TrimEnd($Sep); launch = $launch })
}
if ($Root) {
  Add-Root 'documents' 'Documents' $Root $false
} elseif (Test-Path -LiteralPath $RootsFile) {
  # PowerShell 5.1 devuelve el arreglo JSON como un solo objeto si se envuelve en @();
  # asignarlo primero a una variable hace que foreach lo recorra elemento por elemento.
  $parsedRoots = (Get-Content -LiteralPath $RootsFile -Raw -Encoding UTF8) | ConvertFrom-Json
  foreach ($r in $parsedRoots) {
    $p = [Environment]::ExpandEnvironmentVariables([string]$r.path)
    Add-Root ([string]$r.id) ([string]$r.label) $p ([bool]$r.launch)
  }
} else {
  Add-Root 'documents' 'Documents' ([Environment]::GetFolderPath('MyDocuments')) $false
}
if ($Roots.Count -eq 0) { Write-Log 'No valid locations.'; exit 1 }
function Get-Root([string]$id) {
  foreach ($r in $Roots) { if ($r.id -eq $id) { return $r } }
  throw [IO.DirectoryNotFoundException]'ubicación desconocida'
}
$Shell = $null
try { $Shell = New-Object -ComObject WScript.Shell } catch { }

# ---- Una sola instancia -----------------------------------------------------
$created = $false
$mutex = New-Object System.Threading.Mutex($true, "RhineBridge_$Port", [ref]$created)
if (-not $created) { Write-Log 'Another instance is already running.'; exit 0 }

# ---- Utilidades de rutas ----------------------------------------------------
function Resolve-DocPath($root, [string]$rel) {
  $RootFull = $root.full
  if ($null -eq $rel) { $rel = '' }
  $rel = $rel.Replace('/', $Sep).Replace('\', $Sep).Trim($Sep)
  if ($rel.Contains(':') -or $rel.Contains([char]0)) { throw [UnauthorizedAccessException]'ruta no permitida' }
  foreach ($seg in $rel.Split($Sep)) { if ($seg -eq '..') { throw [UnauthorizedAccessException]'ruta no permitida' } }
  $full = if ($rel) { [IO.Path]::GetFullPath([IO.Path]::Combine($RootFull, $rel)) } else { $RootFull }
  $full = $full.TrimEnd($Sep)
  if (-not ($full.Equals($RootFull, $Cmp) -or $full.StartsWith($RootFull + $Sep, $Cmp))) {
    throw [UnauthorizedAccessException]'fuera de Documents'
  }
  # No seguir enlaces simbólicos ni uniones (podrían salir de Documents).
  $cur = $RootFull
  if ($rel) {
    foreach ($seg in $rel.Split($Sep)) {
      if (-not $seg) { continue }
      $cur = Join-Path $cur $seg
      $it = Get-Item -LiteralPath $cur -Force -ErrorAction SilentlyContinue
      if ($null -eq $it) { throw [IO.FileNotFoundException]'no existe' }
      if (Test-IsLink $it) { throw [UnauthorizedAccessException]'enlace no permitido' }
    }
  }
  return $full
}

function Test-IsLink($item) {
  $lt = $null
  if ($item.PSObject.Properties['LinkType']) { $lt = $item.LinkType }
  return ($lt -eq 'Junction' -or $lt -eq 'SymbolicLink')
}

function Get-RelPath($root, [string]$full) {
  $RootFull = $root.full
  if ($full.Equals($RootFull, $Cmp)) { return '' }
  return $full.Substring($RootFull.Length + 1)
}

function Get-Kind([string]$ext) {
  switch -Regex ($ext) {
    '^\.pdf$' { return 'pdf' }
    '^\.(docx?|docm|dotx?|odt|rtf|xlsx?|xlsm|xlsb|xltx?|csv|ods|pptx?|pptm|potx|odp|pub|vsdx?|one|accdb|mdb)$' { return 'office' }
    '^\.(jpe?g|png|gif|bmp|webp|svg|tiff?|heic|heif|ico|psd|raw|cr2|nef|avif)$' { return 'image' }
    default { return 'other' }
  }
}

function Get-Target($c, [string]$ext) {
  try {
    if ($ext -eq '.url') {
      foreach ($line in (Get-Content -LiteralPath $c.FullName -TotalCount 40 -ErrorAction Stop)) {
        if ($line -match '^\s*URL\s*=\s*(.+)$') { return $Matches[1].Trim() }
      }
    } elseif ($ext -eq '.lnk' -and $Shell) {
      return [string]$Shell.CreateShortcut($c.FullName).TargetPath
    }
  } catch { }
  return ''
}

function Get-Listing($root, [string]$rel) {
  $full = Resolve-DocPath $root $rel
  if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw [IO.DirectoryNotFoundException]'no es una carpeta' }
  $children = @(Get-ChildItem -LiteralPath $full -Force -ErrorAction SilentlyContinue)
  $visible = New-Object System.Collections.Generic.List[object]
  foreach ($c in $children) {
    $attr = $c.Attributes
    if (($attr -band [IO.FileAttributes]::Hidden) -or ($attr -band [IO.FileAttributes]::System)) { continue }
    if ($c.Name -ieq 'desktop.ini' -or $c.Name.StartsWith('~$')) { continue }
    if (Test-IsLink $c) { continue }
    $visible.Add($c)
  }
  $sorted = @($visible | Sort-Object -Property @{Expression = { -not $_.PSIsContainer }}, @{Expression = { $_.Name }})
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($c in ($sorted | Select-Object -First $MaxItems)) {
    $isDir = [bool]$c.PSIsContainer
    $ext = if ($isDir) { '' } else { $c.Extension.ToLowerInvariant() }
    $launch = (-not $isDir) -and $root.launch -and ($LaunchExt -contains $ext)
    $target = ''; $url = ''; $targetPath = ''; $count = $null
    $company = ''; $product = ''; $description = ''; $version = ''
    if (-not $isDir -and ($ext -eq '.lnk' -or $ext -eq '.url')) {
      $t = Get-Target $c $ext
      if ($ext -eq '.url') {
        $url = $t
        $ix = $t.IndexOf(':'); $target = $(if ($ix -gt 0) { $t.Substring(0, $ix).ToLowerInvariant() } else { '' })
      } elseif ($t) { $target = [IO.Path]::GetFileName($t); $targetPath = $t }
    }
    if (-not $isDir -and $ext -eq '.exe') { $targetPath = $c.FullName }
    if ($targetPath -and $targetPath.ToLowerInvariant().EndsWith('.exe')) {
      try {
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
          $vi = [Diagnostics.FileVersionInfo]::GetVersionInfo($targetPath)
          $company = [string]$vi.CompanyName; $product = [string]$vi.ProductName
          $description = [string]$vi.FileDescription; $version = [string]$vi.ProductVersion
        }
      } catch { }
    }
    if ($isDir) {
      try { $count = [IO.Directory]::GetFileSystemEntries($c.FullName).Length } catch { $count = $null }
    }
    $items.Add([ordered]@{
      name    = $c.Name
      path    = (Get-RelPath $root $c.FullName.TrimEnd($Sep))
      dir     = $isDir
      ext     = $ext
      kind    = $(if ($isDir) { 'folder' } else { Get-Kind $ext })
      size    = $(if ($isDir) { $null } else { [int64]$c.Length })
      mtime   = $c.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss')
      launch  = $launch
      target  = $target
      url     = $url
      targetPath  = $targetPath
      company     = $company.Trim()
      product     = $product.Trim()
      description = $description.Trim()
      version     = $version.Trim()
      count   = $count
      blocked = $(if ($isDir -or $launch) { $false } else { $BlockedExt -contains $ext })
    })
  }
  return [ordered]@{
    ok        = $true
    root      = $root.id
    path      = (Get-RelPath $root $full)
    total     = $sorted.Count
    truncated = ($sorted.Count -gt $MaxItems)
    items     = $items
  }
}

function Open-DocPath($root, [string]$rel, [bool]$reveal) {
  $full = Resolve-DocPath $root $rel
  if (-not (Test-Path -LiteralPath $full)) { throw [IO.FileNotFoundException]'no existe' }
  $item = Get-Item -LiteralPath $full -Force
  $isDir = [bool]$item.PSIsContainer
  $ext = if ($isDir) { '' } else { $item.Extension.ToLowerInvariant() }
  $action = 'open'
  $canLaunch = $root.launch -and ($LaunchExt -contains $ext)
  if (-not $isDir -and ($reveal -or (($BlockedExt -contains $ext) -and -not $canLaunch))) { $action = 'reveal' }
  elseif ($canLaunch) { $action = 'launch' }
  if ($DryRun) { Write-Log "DRYRUN $action $full"; return [ordered]@{ ok = $true; action = $action; dryRun = $true } }
  if ($action -eq 'reveal') {
    Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList ('/select,"' + $full + '"')
  } elseif ($isDir) {
    Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList ('"' + $full + '"')
  } else {
    Invoke-Item -LiteralPath $full   # ShellExecute: aplicación predeterminada
  }
  Write-Log "$action $full"
  return [ordered]@{ ok = $true; action = $action }
}

# ---- Planner (tasks & events) --------------------------------------------------
$PlannerFile = Join-Path $AppDir 'planner.json'
$EditorFile  = Join-Path $AppDir 'editor.html'

function Clean-Text($v, [int]$max) {
  if ($null -eq $v) { return '' }
  $t = ([string]$v) -replace '[\x00-\x1F\x7F]', ' '
  $t = $t.Trim()
  if ($t.Length -gt $max) { $t = $t.Substring(0, $max) }
  return $t
}

function Get-Planner {
  if (-not (Test-Path -LiteralPath $PlannerFile)) {
    return [ordered]@{ ok = $true; initialized = $false; tasks = @(); events = @() }
  }
  $raw = Get-Content -LiteralPath $PlannerFile -Raw -Encoding UTF8
  $data = $raw | ConvertFrom-Json
  $tasks = New-Object System.Collections.Generic.List[object]
  $events = New-Object System.Collections.Generic.List[object]
  if ($data.PSObject.Properties['tasks'])  { foreach ($t in $data.tasks)  { $tasks.Add($t) } }
  if ($data.PSObject.Properties['events']) { foreach ($e in $data.events) { $events.Add($e) } }
  return [ordered]@{ ok = $true; initialized = $true; tasks = $tasks; events = $events }
}

function Save-Planner([string]$body) {
  $data = $body | ConvertFrom-Json
  $tasks = New-Object System.Collections.Generic.List[object]
  $events = New-Object System.Collections.Generic.List[object]
  if ($data.PSObject.Properties['tasks']) {
    foreach ($t in $data.tasks) {
      $text = Clean-Text $t.text 120
      if ($text -and $tasks.Count -lt 6) { $tasks.Add([ordered]@{ text = $text }) }
    }
  }
  if ($data.PSObject.Properties['events']) {
    foreach ($e in $data.events) {
      $name = Clean-Text $e.name 80
      $date = Clean-Text $e.date 10
      $time = Clean-Text $e.time 5
      if ($date -notmatch '^\d{4}-\d{2}-\d{2}$') { continue }
      if ($time -and $time -notmatch '^\d{2}:\d{2}$') { $time = '' }
      if ($events.Count -lt 30) { $events.Add([ordered]@{ name = $name; date = $date; time = $time }) }
    }
  }
  $out = [ordered]@{ tasks = $tasks; events = $events }
  [IO.File]::WriteAllText($PlannerFile, (ConvertTo-Json -InputObject $out -Depth 5), $Utf8)
  return (Get-Planner)
}

function Open-Editor([string]$view) {
  if ($view -ne 'events') { $view = 'tasks' }
  $url = "http://127.0.0.1:$Port/editor?view=$view#token=$Token"
  if ($DryRun) { Write-Log "DRYRUN editor $view"; return [ordered]@{ ok = $true; dryRun = $true } }
  $edge = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
  if ($edge) {
    Start-Process -FilePath $edge -ArgumentList @("--app=$url", '--window-size=720,860')
  } else {
    Start-Process -FilePath $url
  }
  return [ordered]@{ ok = $true }
}

# ---- Cambio de fondo (Yan Lab <-> Reshiram) con el control oficial de WE -----
$WallpapersFile = Join-Path $AppDir 'wallpapers.json'

function Get-WEExe {
  $p = Get-Process -Name 'wallpaper64', 'wallpaper32' -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
  if ($p) { return $p.Path }
  return $null
}

# Pantallas (ubicaciones internas de WE) que ahora muestran un fondo cuyo archivo contiene $needle.
function Get-WELocations([string]$weDir, [string]$needle) {
  $found = New-Object System.Collections.Generic.List[string]
  try {
    $cfg = Get-Content -LiteralPath (Join-Path $weDir 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($user in $cfg.PSObject.Properties) {
      $u = $user.Value
      if (-not ($u -is [System.Management.Automation.PSCustomObject])) { continue }
      if (-not $u.PSObject.Properties['general']) { continue }
      if ($null -eq $u.general) { continue }
      $wc = $u.general.PSObject.Properties['wallpaperconfig']
      if (-not $wc -or $null -eq $wc.Value) { continue }
      $sel = $wc.Value.PSObject.Properties['selectedwallpapers']
      if (-not $sel -or $null -eq $sel.Value) { continue }
      foreach ($m in $sel.Value.PSObject.Properties) {
        $f = [string]$m.Value.file
        if ($f -and $f.ToLowerInvariant().Contains($needle.ToLowerInvariant())) { $found.Add($m.Name) }
      }
    }
  } catch { Write-Log ("config.json: " + $_.Exception.Message) }
  return ,$found
}

# Pantalla (ubicación de WE, p. ej. "Monitor1") donde está el cursor en este momento.
# Al presionar un botón del fondo, el cursor está sobre esa pantalla.
function Get-CursorLocation([string]$weDir) {
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $pos = [System.Windows.Forms.Cursor]::Position
    $screen = [System.Windows.Forms.Screen]::FromPoint($pos)
    if (-not $screen) { return $null }
    $dev = ([string]$screen.DeviceName).Replace('\', '/')          # \\.\DISPLAY1 -> //./DISPLAY1
    $cfg = Get-Content -LiteralPath (Join-Path $weDir 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($user in $cfg.PSObject.Properties) {
      $u = $user.Value
      if (-not ($u -is [System.Management.Automation.PSCustomObject])) { continue }
      if (-not $u.PSObject.Properties['general']) { continue }
      if ($null -eq $u.general) { continue }
      $usr = $u.general.PSObject.Properties['user']
      if (-not $usr -or $null -eq $usr.Value) { continue }
      $map = $usr.Value.PSObject.Properties['monitormap']
      if (-not $map -or $null -eq $map.Value) { continue }
      foreach ($m in $map.Value.PSObject.Properties) {
        if ($m.Name -ieq $dev) { return ('Monitor' + [int]$m.Value.location) }
      }
    }
  } catch { Write-Log ("cursor: " + $_.Exception.Message) }
  return $null
}

# Fondos alternativos: proyectos de myprojects que tienen la propiedad "yanlab" (acceso directo de regreso).
function Get-Backgrounds([string]$myprojects) {
  $list = New-Object System.Collections.Generic.List[object]
  foreach ($dir in (Get-ChildItem -LiteralPath $myprojects -Directory -ErrorAction SilentlyContinue)) {
    $pj = Join-Path $dir.FullName 'project.json'
    if (-not (Test-Path -LiteralPath $pj)) { continue }
    try {
      $p = Get-Content -LiteralPath $pj -Raw -Encoding UTF8 | ConvertFrom-Json
      if (-not $p.PSObject.Properties['general'] -or $null -eq $p.general) { continue }
      $props = $p.general.PSObject.Properties['properties']
      if (-not $props -or $null -eq $props.Value) { continue }
      $y = $props.Value.PSObject.Properties['yanlab']
      if (-not $y -or $null -eq $y.Value -or [string]$y.Value.type -ne 'usershortcut') { continue }
      $title = [string]$p.title
      $list.Add([ordered]@{ id = $dir.Name; name = ($title -replace '^Yan Lab\s*·\s*', ''); title = $title; project = $pj })
    } catch { }
  }
  return ,$list
}

# Valor del acceso directo de regreso que el usuario ya autorizó en alguna pantalla (para reutilizarlo).
function Get-ReturnBinding([string]$weDir) {
  try {
    $cfg = Get-Content -LiteralPath (Join-Path $weDir 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($user in $cfg.PSObject.Properties) {
      $u = $user.Value
      if (-not ($u -is [System.Management.Automation.PSCustomObject])) { continue }
      $wp = $u.PSObject.Properties['wproperties']
      if (-not $wp -or $null -eq $wp.Value) { continue }
      foreach ($w in $wp.Value.PSObject.Properties) {
        if ($null -eq $w.Value) { continue }
        foreach ($m in $w.Value.PSObject.Properties) {
          if ($null -eq $m.Value) { continue }
          $y = $m.Value.PSObject.Properties['yanlab']
          if ($y -and ([string]$y.Value).StartsWith('cmd:') -and ([string]$y.Value).Contains('return-to-yanlab.vbs')) { return [string]$y.Value }
        }
      }
    }
  } catch { }
  return $null
}

# Escapa un argumento según las reglas de línea de comandos de Windows (CommandLineToArgvW).
function Format-WinArg([string]$a) {
  $r = [regex]::Replace($a, '(\\*)"', { param($m) ($m.Groups[1].Value * 2) + '\"' })
  $r = [regex]::Replace($r, '(\\+)$', { param($m) $m.Groups[1].Value * 2 })
  return '"' + $r + '"'
}

$script:PendingProps = New-Object System.Collections.Generic.List[object]
function Invoke-PendingProps {
  if ($script:PendingProps.Count -eq 0) { return }
  $jobs = $script:PendingProps.ToArray(); $script:PendingProps.Clear()
  foreach ($delay in @(2500, 4000)) {
    Start-Sleep -Milliseconds $delay
    foreach ($j in $jobs) {
      if ($DryRun) { Write-Log ("DRYRUN props " + ($j.args -join ' ')) }
      else { Start-Process -FilePath $j.exe -ArgumentList $j.args -WindowStyle Hidden }
    }
  }
  Write-Log 'return shortcut applied'
}

function Switch-Wallpaper([string]$target) {
  if (-not (Test-Path -LiteralPath $WallpapersFile)) { throw [IO.FileNotFoundException]'wallpapers.json' }
  $wp = Get-Content -LiteralPath $WallpapersFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $yanlab = [string]$wp.yanlab
  $myprojects = Split-Path -Parent (Split-Path -Parent $yanlab)
  $bgs = Get-Backgrounds $myprojects
  if ($target -eq 'yanlab') {
    $file = $yanlab
    $needles = @($bgs | ForEach-Object { $_.id })
    $bg = $null
  } else {
    $bg = $bgs | Where-Object { $_.id -eq $target } | Select-Object -First 1
    if (-not $bg) { throw [UnauthorizedAccessException]'target' }
    $file = [string]$bg.project
    $needles = @((Split-Path -Leaf (Split-Path -Parent $yanlab)))
  }
  if (-not (Test-Path -LiteralPath $file)) { throw [IO.FileNotFoundException]'project' }
  $exe = Get-WEExe
  if (-not $exe) { $exe = [string]$wp.weExe }
  if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { throw [IO.FileNotFoundException]'wallpaper engine' }
  $weDir = Split-Path -Parent $exe
  # Solo la pantalla donde se hizo clic; si no se puede saber, las que muestran el fondo de origen.
  $here = if ($DryRun -and $env:YAN_TEST_CURSOR) { $env:YAN_TEST_CURSOR } else { Get-CursorLocation $weDir }
  if ($here) { $targets = @($here) }
  else {
    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($n in $needles) { foreach ($l in (Get-WELocations $weDir $n)) { if (-not $targets.Contains($l)) { $targets.Add($l) } } }
    $targets = @($targets); if ($targets.Count -eq 0) { $targets = @('') }
  }
  $binding = if ($bg) { Get-ReturnBinding $weDir } else { $null }
  foreach ($loc in $targets) {
    $cliArgs = @('-control', 'openWallpaper', '-file', ('"' + $file + '"'))
    if ($loc) { $cliArgs += @('-location', $loc) }
    if ($DryRun) { Write-Log ("DRYRUN wallpaper " + ($cliArgs -join ' ')) }
    else { Start-Process -FilePath $exe -ArgumentList $cliArgs -WindowStyle Hidden }
    Write-Log ("wallpaper -> $target on " + $(if ($loc) { $loc } else { 'first monitor' }))
    # Reutilizar el acceso directo de regreso ya autorizado (se aplica después de responder, cuando la escena ya cargó).
    if ($binding -and $loc) {
      $json = ConvertTo-Json -InputObject ([ordered]@{ yanlab = $binding }) -Compress
      $raw = Format-WinArg ('RAW~(' + $json + ')~END')
      $script:PendingProps.Add(@{ exe = $exe; args = @('-control', 'applyProperties', '-properties', $raw, '-location', $loc) })
      $mi = $loc -replace '^Monitor', ''
      if ($mi -match '^\d+$') { $script:PendingProps.Add(@{ exe = $exe; args = @('-control', 'applyProperties', '-properties', $raw, '-monitor', $mi) }) }
    }
  }
  return [ordered]@{ ok = $true; target = $target; locations = $targets }
}

# ---- HTTP mínimo sobre TcpListener (solo loopback) --------------------------
function Send-Response($stream, [int]$code, [string]$status, [string]$body, [string]$ctype = 'application/json; charset=utf-8') {
  $bytes = $Utf8.GetBytes($body)
  $head = "HTTP/1.1 $code $status`r`n" +
          "Content-Type: $ctype`r`n" +
          "Content-Length: $($bytes.Length)`r`n" +
          "Access-Control-Allow-Origin: *`r`n" +
          "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n" +
          "Access-Control-Allow-Headers: Content-Type`r`n" +
          "Access-Control-Allow-Private-Network: true`r`n" +
          "Cache-Control: no-store`r`n" +
          "X-Content-Type-Options: nosniff`r`n" +
          "Connection: close`r`n`r`n"
  $hb = [Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($hb, 0, $hb.Length)
  if ($bytes.Length) { $stream.Write($bytes, 0, $bytes.Length) }
  $stream.Flush()
}

function Send-Json($stream, [int]$code, $obj) {
  $status = switch ($code) { 200 {'OK'} 400 {'Bad Request'} 403 {'Forbidden'} 404 {'Not Found'} 405 {'Method Not Allowed'} default {'Error'} }
  Send-Response $stream $code $status (ConvertTo-Json -InputObject $obj -Depth 6 -Compress)
}

function Read-Request($stream) {
  $buf = New-Object byte[] 8192
  $ms = New-Object System.IO.MemoryStream
  $headerEnd = -1
  while ($headerEnd -lt 0) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { return $null }
    $ms.Write($buf, 0, $n)
    if ($ms.Length -gt 16384) { return $null }
    $all = $ms.ToArray()
    for ($i = 3; $i -lt $all.Length; $i++) {
      if ($all[$i-3] -eq 13 -and $all[$i-2] -eq 10 -and $all[$i-1] -eq 13 -and $all[$i] -eq 10) { $headerEnd = $i + 1; break }
    }
  }
  $all = $ms.ToArray()
  $headText = [Text.Encoding]::ASCII.GetString($all, 0, $headerEnd)
  $lines = $headText -split "`r`n"
  $parts = $lines[0].Split(' ')
  if ($parts.Length -lt 2) { return $null }
  $headers = @{}
  foreach ($l in $lines[1..($lines.Length - 1)]) {
    $ix = $l.IndexOf(':')
    if ($ix -gt 0) { $headers[$l.Substring(0, $ix).Trim().ToLowerInvariant()] = $l.Substring($ix + 1).Trim() }
  }
  $len = 0
  if ($headers.ContainsKey('content-length')) { [void][int]::TryParse($headers['content-length'], [ref]$len) }
  if ($len -gt 65536) { return $null }
  $body = New-Object System.IO.MemoryStream
  $body.Write($all, $headerEnd, $all.Length - $headerEnd)
  while ($body.Length -lt $len) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { break }
    $body.Write($buf, 0, $n)
  }
  $target = $parts[1]
  $path = $target; $query = @{}
  $q = $target.IndexOf('?')
  if ($q -ge 0) {
    $path = $target.Substring(0, $q)
    foreach ($pair in $target.Substring($q + 1).Split('&')) {
      if (-not $pair) { continue }
      $kv = $pair.Split('=', 2)
      $k = [Uri]::UnescapeDataString($kv[0])
      $v = if ($kv.Length -gt 1) { [Uri]::UnescapeDataString($kv[1]) } else { '' }
      $query[$k] = $v
    }
  }
  return @{
    Method  = $parts[0].ToUpperInvariant()
    Path    = $path
    Query   = $query
    Headers = $headers
    Body    = $Utf8.GetString($body.ToArray())
  }
}

function Test-Token([string]$t) {
  if (-not $t -or $t.Length -ne $Token.Length) { return $false }
  $diff = 0
  for ($i = 0; $i -lt $t.Length; $i++) { $diff = $diff -bor ([int]$t[$i] -bxor [int]$Token[$i]) }
  return ($diff -eq 0)
}

function Handle-Client($client) {
  $client.ReceiveTimeout = 4000
  $client.SendTimeout = 4000
  $stream = $client.GetStream()
  $req = Read-Request $stream
  if ($null -eq $req) { return }

  $hostHeader = ''
  if ($req.Headers.ContainsKey('host')) { $hostHeader = $req.Headers['host'] }
  if ($hostHeader -ne "127.0.0.1:$Port" -and $hostHeader -ne "localhost:$Port") {
    Send-Json $stream 403 @{ ok = $false; error = 'host' }; return
  }
  if ($req.Method -eq 'OPTIONS') { Send-Response $stream 204 'No Content' '' 'text/plain'; return }
  if ($req.Path -eq '/editor' -and $req.Method -eq 'GET') {
    if (Test-Path -LiteralPath $EditorFile) {
      Send-Response $stream 200 'OK' (Get-Content -LiteralPath $EditorFile -Raw -Encoding UTF8) 'text/html; charset=utf-8'
    } else { Send-Response $stream 404 'Not Found' 'editor.html missing' 'text/plain' }
    return
  }

  $tok = ''
  if ($req.Query.ContainsKey('token')) { $tok = $req.Query['token'] }
  if (-not (Test-Token $tok)) { Send-Json $stream 403 @{ ok = $false; error = 'token' }; return }

  try {
    switch ($req.Path) {
      '/api/ping' {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($r in $Roots) { $list.Add([ordered]@{ id = $r.id; label = $r.label; launch = $r.launch; path = $r.full }) }
        Send-Json $stream 200 ([ordered]@{ ok = $true; name = 'Yan Bridge'; version = 2; roots = $list })
      }
      '/api/list' {
        if ($req.Method -ne 'GET') { Send-Json $stream 405 @{ ok = $false; error = 'method' }; return }
        $rel = ''; $rid = $Roots[0].id
        if ($req.Query.ContainsKey('path')) { $rel = $req.Query['path'] }
        if ($req.Query.ContainsKey('root')) { $rid = $req.Query['root'] }
        Send-Json $stream 200 (Get-Listing (Get-Root $rid) $rel)
      }
      '/api/open' {
        if ($req.Method -ne 'POST') { Send-Json $stream 405 @{ ok = $false; error = 'method' }; return }
        $data = $req.Body | ConvertFrom-Json
        $rel = [string]$data.path
        $rid = $Roots[0].id
        if ($data.PSObject.Properties['root'] -and $data.root) { $rid = [string]$data.root }
        $reveal = $false
        if ($data.PSObject.Properties['reveal']) { $reveal = [bool]$data.reveal }
        Send-Json $stream 200 (Open-DocPath (Get-Root $rid) $rel $reveal)
      }
      '/api/planner' {
        if ($req.Method -eq 'GET') { Send-Json $stream 200 (Get-Planner) }
        elseif ($req.Method -eq 'POST') { Send-Json $stream 200 (Save-Planner $req.Body) }
        else { Send-Json $stream 405 @{ ok = $false; error = 'method' } }
      }
      '/api/backgrounds' {
        $wpc = Get-Content -LiteralPath $WallpapersFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($b in (Get-Backgrounds (Split-Path -Parent (Split-Path -Parent ([string]$wpc.yanlab))))) { $items.Add([ordered]@{ id = $b.id; name = $b.name }) }
        Send-Json $stream 200 ([ordered]@{ ok = $true; items = $items })
      }
      '/api/wallpaper' {
        if ($req.Method -ne 'POST') { Send-Json $stream 405 @{ ok = $false; error = 'method' }; return }
        $t = ''
        if ($req.Query.ContainsKey('target')) { $t = $req.Query['target'] }
        Send-Json $stream 200 (Switch-Wallpaper $t)
        $stream.Flush(); $client.Close()
        Invoke-PendingProps
      }
      '/api/editor' {
        if ($req.Method -ne 'POST') { Send-Json $stream 405 @{ ok = $false; error = 'method' }; return }
        $view = 'tasks'
        if ($req.Query.ContainsKey('view')) { $view = $req.Query['view'] }
        Send-Json $stream 200 (Open-Editor $view)
      }
      default { Send-Json $stream 404 @{ ok = $false; error = 'not-found' } }
    }
  } catch [UnauthorizedAccessException] {
    Send-Json $stream 403 @{ ok = $false; error = 'forbidden' }
  } catch [IO.FileNotFoundException], [IO.DirectoryNotFoundException] {
    Send-Json $stream 404 @{ ok = $false; error = 'missing' }
  } catch {
    Write-Log ("Error: " + $_.Exception.Message)
    Send-Json $stream 400 @{ ok = $false; error = 'bad-request' }
  }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
try {
  $listener.Start()
} catch {
  Write-Log "Could not open port $Port : $($_.Exception.Message)"
  exit 1
}
Write-Log ("Yan Bridge listening on 127.0.0.1:$Port · locations: " + (($Roots | ForEach-Object { $_.label }) -join ', '))

while ($true) {
  $client = $listener.AcceptTcpClient()
  try { Handle-Client $client }
  catch { Write-Log ("Connection: " + $_.Exception.Message) }
  finally { $client.Close() }
}
