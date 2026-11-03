# Architecture

## Build pipeline (`setup/Install-YanLab.ps1`)

1. Locate Wallpaper Engine and Workshop item `3799142774` through Steam's library folders.
2. Compare `assets/index-DGZ5gDxu.js` with `sourceSha256` in `patches/manifest.json`.
3. Copy the item to `projects\myprojects\<Name>` (backup files are skipped).
4. Apply `bundlePatches` in order and compare with `resultSha256`; any mismatch removes the
   half-built folder.
5. Patch `index.html` (`10-index-html.json`), replace the *Rhine Lab* name in exported archive
   TXT files, and edit `project.json` textually: title, description, `visibility: private`,
   no `workshopid`/`workshopurl`, default language `en-US`. The JSON is re-parsed afterwards
   as a safety check.
6. Copy `overlay/*` and `bridge/*` (as `yan-bridge/`), then run `yan-bridge/install.ps1`.

### Patch format

```json
{ "target": "assets/index-DGZ5gDxu.js",
  "operations": [
    { "op": "replace", "find": "…", "replace": "…", "count": 1 },
    { "op": "regex",   "pattern": "…", "replace": "…" },
    { "op": "prepend", "text": "…" } ] }
```

`count` is the exact number of matches required (`-1` = any number). Operations are literal
(no regex) unless `op` is `regex` (.NET syntax).

| File | Change |
|---|---|
| `01-archive-hooks` | `window.rhineArchiveOverride` (`view`, `detail`, `detailActive`) lets the overlay drive the archive view and the detail sheet; `window.rhineArchiveRefresh()` redraws it. |
| `02-branding` | *Rhine Lab* → *Yan Lab* in visible text; the hand-lettered artwork definitions are kept so the fallback renderer draws the new name. |
| `03-planner-hooks` | `window.rhinePlanner` (`text`, `slots`, `tasksHTML`, `eventHTML`) and `window.rhineWorkbench`. |
| `04-performance` | `__yanSetStyle` / `__yanSetData`: per-frame style writes only happen when the value changes. |
| `05-detail-quality` | Hides the `Titanium_Fasteners` material (screws); full-resolution 3D while a detail sheet is open (`window.__yanSharp`). |
| `06-smooth-entry` | Skips no-op canvas re-allocations; compiles shaders and renders one hidden frame during the boot screen (`window.__yanWarm`). |

All hooks are optional: if an overlay script is missing, the wallpaper keeps the original
behaviour.

## Overlay (`overlay/`)

| File | Role |
|---|---|
| `desktop-archive.js` | Maps the five archive columns to the bridge locations, builds the detail sheet (Details / Access, LAUNCH / OPEN, EXPLORER). |
| `documents-explorer.js` / `.css` | ARCHIVE INDEX tabs, breadcrumbs, custom scrollbars; all extra styles. |
| `planner.js` | Tasks and events from the bridge, "+ ADD" buttons, daily completion. |
| `wallpaper-switch.js` | "Change to Background" button and menu. |

`bridge-config.js` (generated, git-ignored) provides `window.rhineBridgeConfig = { port, token }`.

## Yan Bridge (`bridge/rhine-bridge.ps1`)

Windows PowerShell 5.1, `TcpListener` on `127.0.0.1:47831`. Every request needs the token
and a loopback `Host` header (see [SECURITY.md](../SECURITY.md)).

| Endpoint | Purpose |
|---|---|
| `GET /api/ping` | Status and configured locations |
| `GET /api/list?root=&path=` | Folder listing inside a location (with shortcut/program metadata) |
| `POST /api/open` | Launch, open or reveal an item (rules in SECURITY.md) |
| `GET/POST /api/planner` | Read/write `planner.json` |
| `POST /api/editor` and `GET /editor` | Open and serve the planner editor (Edge app window) |
| `GET /api/backgrounds` | Projects in `myprojects` that have a `yanlab` user-shortcut property |
| `POST /api/wallpaper?target=` | Switch the monitor under the mouse cursor (via Wallpaper Engine's CLI) and re-apply the saved return shortcut |

Files: `%LOCALAPPDATA%\RhineBridge\` (`token.txt`, `roots.json`, `planner.json`,
`wallpapers.json`, `return-to-yanlab.vbs`, `launch.vbs`, `bridge.log`) and a *Yan Bridge*
shortcut in the Startup folder. The `RhineBridge` folder name is kept for compatibility with
existing installs.

## Alternative backgrounds (`tools/New-YanLabBackground.ps1`)

* **Scene:** unpacks `scene.pkg` (`PKGVxxxx` table of name/offset/size), copies
  `backgrounds/scene/{materials,models}`, appends `button-object.json` to `scene.json`
  (7.5 % of the width, centred at 8.94 % × 10.68 % from the bottom-left), adds the
  `yanlab` user-shortcut property. The SceneScript calls `engine.openUserShortcut('yanlab')`.
* **Video:** `backgrounds/video/index.html` plays the video full screen and POSTs
  `/api/wallpaper?target=yanlab`; ffmpeg (optional) converts to VP9/Opus WebM.

## Updating for a new upstream build

1. Get the new build and adapt the `find` strings of each patch file.
2. Recompute `sourceSha256` (new original) and `resultSha256` (patched result), e.g. with
   `Get-FileHash -Algorithm SHA256`.
3. Run setup against a test copy and check the wallpaper in Wallpaper Engine.
