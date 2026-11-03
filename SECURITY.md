# Security

Yan Bridge is a small PowerShell HTTP server that lets the wallpaper (a sandboxed web page
inside Wallpaper Engine) list and open files you chose to expose. Because it can start
programs, it is designed to be as narrow as possible.

## Design

| Measure | Detail |
|---|---|
| Loopback only | Listens on `127.0.0.1:47831`; it is not reachable from your network. |
| Secret token | A random 256-bit token is generated at install time (`%LOCALAPPDATA%\RhineBridge\token.txt`) and required on every request. It is compared in constant time and never written to the log. |
| Host check | Requests whose `Host` header is not `127.0.0.1:<port>` or `localhost:<port>` are rejected (protects against DNS-rebinding attacks from web pages). |
| Fixed locations | Only the folders listed in `roots.json` are visible. Paths are normalised and anything that resolves outside those folders is refused. |
| Limited actions | Shortcuts (`.lnk`, `.url`, `.appref-ms`), `.exe` and `.jar` are launched **only** from locations marked as launchers (by default the Desktop folders *PC settings*, *Clients*, *Apps*, *Games*). Scripts (`.bat`, `.cmd`, `.ps1`, `.vbs`, `.js`, …) are never executed; they are only shown selected in File Explorer. In *Documents* no program, script or shortcut is started; other files open in their default app. |
| No arbitrary commands | There is no endpoint that runs a command line. Wallpaper switching only opens projects found in Wallpaper Engine's `myprojects` folder through Wallpaper Engine's own command-line interface. |
| Small requests | Request bodies above 64 KB are refused. |

### Files on your computer

`%LOCALAPPDATA%\RhineBridge\` holds the token, the server copy, `roots.json` (your exposed
folders), `planner.json` (your tasks and events) and `bridge.log` (which records the paths of files you open). The wallpaper folder gets
`bridge-config.js`, which contains the token. **None of these files belong in a repository or
in a bug report** — `.gitignore` excludes them, but double-check before sharing anything.

To revoke access, run `yan-bridge\uninstall-bridge.bat` inside the project folder that setup
created (`...\projects\myprojects\yan-lab-desktop`). It removes the folder above, the startup
shortcut and `bridge-config.js`; your tasks and events are deleted with it. Reinstalling
after uninstalling creates a new token (a plain reinstall keeps the existing one).

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's
**Security → Report a vulnerability** (private vulnerability reporting) on this repository.
