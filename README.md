<div align="center">

# Yan Lab · Desktop

**Turn an interactive Wallpaper Engine wallpaper into a working desktop:<br>
launch your apps and games, browse your documents, plan your day and switch backgrounds — from the wallpaper itself.**

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0b1220)
![Wallpaper Engine](https://img.shields.io/badge/Wallpaper%20Engine-web%20wallpaper-1f2937)
![License: MIT](https://img.shields.io/badge/code-MIT-3b82f6)

[English](README.md) · [Español](README.es.md)

</div>

---

Yan Lab · Desktop is a **patch set and local companion** for
[*Rhine Lab · Interactive Desktop*](https://github.com/LBEILC/RhineLabUI) by **LBEILC**
(Steam Workshop item `3799142774`), an unofficial *Arknights* fan wallpaper with a 3D glass
archive and a desktop workspace.

> [!IMPORTANT]
> **This repository does not contain the original wallpaper.** You subscribe to it on the
> Steam Workshop yourself; the setup script copies *your* local copy, verifies it, applies the
> patches and adds the extra features. The Workshop folder is never modified.
> See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for why.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Using it](#using-it)
- [Alternative backgrounds](#alternative-backgrounds)
- [How it works](#how-it-works)
- [Compatibility](#compatibility)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)
- [Credits and licenses](#credits-and-licenses)

## Features

### Your desktop inside the archive
- The five archive **columns** become your own categories: **PC settings**, **Clients**,
  **Apps**, **Games** (folders of shortcuts on your Desktop) and **Documents**.
- The arrows step through the files of each column; the counter, codes and labels follow
  your files.
- **ACCESS FILE** opens a detail sheet with two tabs — *Details* (program, publisher,
  version, size, dates…) and *Access* — plus **LAUNCH / OPEN** and **EXPLORER** buttons.
- Long lists scroll with the wallpaper's own scrollbars (Wallpaper Engine does not deliver
  mouse-wheel or native scrollbar input reliably).

### ARCHIVE INDEX file explorer
- Tabs for each category, breadcrumb navigation into sub-folders, open or reveal any item.
- Updates automatically when you add or remove files.

### Planner
- **Today's tasks** and **Upcoming events** come from a small local planner instead of the
  three fixed text fields.
- **+ ADD** opens an editor window (Microsoft Edge app window) where you type tasks and
  events — Wallpaper Engine does not give the desktop keyboard focus to wallpapers.
- Click a task on the wallpaper to tick it off; completion resets every day.

### Change to Background
- A **↗ Change to Background** button next to *Ripple relay* lists alternative backgrounds
  (native scenes or videos) and switches **only the screen you clicked on**.
- Each alternative background has a **↗ Yan Lab** button to come back.
- [`tools/New-YanLabBackground.ps1`](#alternative-backgrounds) builds such backgrounds from
  any scene or video wallpaper you have.

### Polish and performance
- English interface by default and *YAN LAB* branding.
- Fewer per-frame style writes, so idle CPU use drops with pixel-identical visuals.
- The 3D renders at full resolution only while a detail sheet is open (sharper label,
  lower memory the rest of the time).
- Shaders and GPU uploads are prepared while the boot screen is shown, so **ENTER SYSTEM**
  no longer stutters; unchanged canvas sizes are no longer re-allocated.
- Screws removed from the archive cases; dark theme and UI margins fully supported.

Everything is optional at runtime: without Yan Bridge the wallpaper behaves like the
original (plus the English UI and the performance fixes).

## Requirements

| | |
|---|---|
| OS | Windows 10 or 11 (Windows PowerShell 5.1, included with Windows) |
| Wallpaper Engine | Steam version |
| Original wallpaper | Subscription to Workshop item [`3799142774`](https://steamcommunity.com/sharedfiles/filedetails/?id=3799142774) — the exact build listed in [`patches/manifest.json`](patches/manifest.json) |
| Planner editor | Microsoft Edge (pre-installed on Windows) |
| Optional | [ffmpeg](https://ffmpeg.org/) on `PATH`, to convert video backgrounds |

## Installation

1. **Subscribe** to *Rhine Lab · Interactive Desktop* in the Steam Workshop and wait until
   Wallpaper Engine has downloaded it.
2. **Get this repository** — *Code → Download ZIP* (then right-click the ZIP →
   *Properties* → *Unblock*, and extract it) or `git clone`.
3. **Run `setup\install.bat`.** It will:
   - find Wallpaper Engine and the original wallpaper (or pass `-WorkshopPath` /
     `-WallpaperEnginePath`);
   - check the original's SHA-256 and stop without changing anything if it differs;
   - create `Wallpaper Engine\projects\myprojects\yan-lab-desktop`, patch it and verify the result;
   - install **Yan Bridge** and start it (it also starts automatically when you sign in).
4. In Wallpaper Engine, pick **Yan Lab · Desktop** under *My Wallpapers*
   (restart Wallpaper Engine once if it is not listed yet).

Setup options: `-Name <folder>`, `-Force` (rebuild; the old folder is kept as a backup),
`-SkipBridge` (wallpaper only). Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup\Install-YanLab.ps1 -Force
```

## Using it

### Categories
Create any of these folders **on your Desktop** and put shortcuts in them:
`PC settings`, `Clients`, `Apps`, `Games`. Missing folders are simply skipped;
**Documents** is always available. New files show up on their own.
The list lives in `%LOCALAPPDATA%\RhineBridge\roots.json` and is regenerated when you
re-run the bridge installer.

### What gets launched
In the four Desktop categories, shortcuts, `.exe`, `.jar` and `.appref-ms` files are
launched. Scripts are never executed — they are shown in File Explorer instead. In
*Documents*, files open with their default app, while programs, scripts and shortcuts are
only revealed in File Explorer.
Details in [SECURITY.md](SECURITY.md).

### Recommended Wallpaper Engine properties
| Property | Why |
|---|---|
| **UI margin bottom / left** | Keep the bottom UI above a taskbar (e.g. `80` for a bottom taskbar). |
| **Super performance** | Lower memory use; glass transmission and shadows are simplified. |
| **Model precision: Low** | Lighter 3D models. |

## Alternative backgrounds

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\New-YanLabBackground.ps1 `
  -Source "C:\Program Files (x86)\Steam\steamapps\workshop\content\431960\<item id>" `
  -Title "Night City"
```

- **Scene wallpapers** are unpacked and receive a *↗ Yan Lab* image layer; the first time
  you use one, set its **Return to Yan Lab** property to
  `yan-bridge\Return to Yan Lab.lnk` (inside the Yan Lab · Desktop folder). After that,
  the bridge reuses this setting automatically whenever it switches to a background.
- **Video wallpapers** become a light web wallpaper with the same button, a *Volume*
  property, and pause support. With ffmpeg available the video is converted to 1080p WebM.

Generated backgrounds stay on your computer. **Do not upload them to the Workshop** — they
contain other creators' work.

## How it works

```
Steam Workshop copy ──(setup: verify → copy → patch → verify)──► myprojects\yan-lab-desktop
                                                                    │  overlay/*.js, *.css
                                                                    ▼
  Wallpaper (web page in Wallpaper Engine)  ⇄  Yan Bridge (127.0.0.1, token)  ⇄  your folders,
                                                                              planner.json,
                                                                              Wallpaper Engine CLI
```

| Path | Purpose |
|---|---|
| `patches/` | Exact find/replace operations on the original build, applied in order and checked with SHA-256 (`manifest.json`). |
| `overlay/` | Scripts and styles loaded by the wallpaper: archive mapping, ARCHIVE INDEX explorer, planner, background switcher. |
| `bridge/` | Yan Bridge server, planner editor page and (un)installers. |
| `setup/` | Build script. |
| `tools/` | Alternative-background generator. |
| `backgrounds/` | Button artwork and templates used by the generator. |

More detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Compatibility

The patches match **one exact build** of the original wallpaper (SHA-256 in
[`patches/manifest.json`](patches/manifest.json)). If its author publishes an update, setup
refuses to run instead of producing a broken wallpaper; your existing Yan Lab folder keeps
working because it is an independent copy. Updating the patch set for a new build is welcome
as a pull request.

## Uninstall

1. Run `yan-bridge\uninstall-bridge.bat` inside `...\projects\myprojects\yan-lab-desktop`
   (stops the bridge, removes autostart, the token and your planner data).
2. Delete the `yan-lab-desktop` folder (and any `yan-lab-*` backgrounds you generated).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Setup says *unsupported version* | The Workshop item was updated; see [Compatibility](#compatibility). |
| Categories are empty / "bridge offline" | Run `yan-bridge\install-bridge.bat` again; check `%LOCALAPPDATA%\RhineBridge\bridge.log`. |
| Changes do not show | Reload the wallpaper, or restart Wallpaper Engine (it caches `project.json`). |
| "+ ADD" says OPENING… but nothing opens | Microsoft Edge is required for the editor window. |
| A scene background does not return | Set its *Return to Yan Lab* property once (see above). |

## Credits and licenses

- **Original wallpaper:** *Rhine Lab · Interactive Desktop* by **LBEILC** — code under the
  MIT License; models, images, audio and fonts under their own terms.
  [GitHub](https://github.com/LBEILC/RhineLabUI) ·
  [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3799142774)
- **Fonts:** the button artwork was set in **MiSans** by Xiaomi; no font files are included.
- **This project:** original code and docs under the [MIT License](LICENSE); see
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for everything else.

Unofficial fan project. *Arknights* and *Rhine Lab* belong to Hypergryph / Yostar;
*Wallpaper Engine* to Wallpaper Engine Team; *Steam* to Valve. No affiliation or endorsement.
