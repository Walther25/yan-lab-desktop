# ARQUITECTURA.md — Yan Lab · Desktop

## Resumen

| Parte | Carpeta | Qué hace |
|---|---|---|
| Parches | `src/patches/` | Cambios exactos (buscar/reemplazar) sobre el código compilado del fondo original |
| Overlay | `src/overlay/` | Scripts y estilos propios que el fondo carga |
| Yan Bridge | `src/bridge/` | Servidor local en `127.0.0.1:47831` que conecta el fondo con el sistema |
| Instalador | `src/script/Install-YanLab.ps1` | Arma el proyecto desde la copia del Workshop |
| Generador | `src/script/New-YanLabBackground.ps1` | Crea fondos alternativos con botón de regreso |

---

## Instalación paso a paso

1. Busca Wallpaper Engine y el ítem `3799142774` en las bibliotecas de Steam (registro de Windows + `libraryfolders.vdf`).
2. Compara `assets/index-DGZ5gDxu.js` con `sourceSha256` de `src/patches/manifest.json`.
3. Copia el ítem a `projects\myprojects\<Name>` (sin archivos de respaldo).
4. Aplica `bundlePatches` en orden y compara con `resultSha256`. Si algo no coincide, borra la carpeta a medio armar.
5. Parchea `index.html` (`10-index-html.json`), cambia *Rhine Lab* por *Yan Lab* en los TXT exportables y edita `project.json` como texto: título, descripción, `visibility: private`, sin `workshopid`/`workshopurl`, idioma por defecto `en-US`. Después vuelve a leer el JSON como control.
6. Copia `src/overlay/*` y `src/bridge/*` (como `yan-bridge/`) y ejecuta `yan-bridge/install.ps1`.

---

## Formato de los parches

```json
{ "target": "assets/index-DGZ5gDxu.js",
  "operations": [
    { "op": "replace", "find": "…", "replace": "…", "count": 1 },
    { "op": "regex",   "pattern": "…", "replace": "…" },
    { "op": "prepend", "text": "…" } ] }
```

`count` es la cantidad exacta de coincidencias que tiene que haber (`-1` = cualquier cantidad). Las operaciones son literales salvo `regex` (sintaxis de .NET).

| Archivo | Cambio |
|---|---|
| `01-archive-hooks` | `window.rhineArchiveOverride` (`view`, `detail`, `detailActive`) permite que el overlay controle la vista del archivo y la ficha de detalle; `window.rhineArchiveRefresh()` la redibuja. |
| `02-branding` | *Rhine Lab* → *Yan Lab* en los textos visibles. Se conservan las definiciones de letras dibujadas a mano para que el fondo use su modo de respaldo con el nombre nuevo. |
| `03-planner-hooks` | `window.rhinePlanner` (`text`, `slots`, `tasksHTML`, `eventHTML`) y `window.rhineWorkbench`. |
| `04-performance` | `__yanSetStyle` / `__yanSetData`: los estilos que se escriben en cada cuadro solo se escriben si cambian. |
| `05-detail-quality` | Oculta el material `Titanium_Fasteners` (tornillos). 3D a resolución completa mientras hay una ficha abierta (`window.__yanSharp`). |
| `06-smooth-entry` | No vuelve a crear el lienzo si el tamaño no cambió. Compila los shaders y dibuja un cuadro oculto durante la pantalla de inicio (`window.__yanWarm`). |

Todos los enchufes son opcionales: si falta un script del overlay, el fondo se comporta como el original.

---

## Overlay

| Archivo | Función |
|---|---|
| `desktop-archive.js` | Asocia las cinco columnas a las ubicaciones del puente y arma la ficha de detalle (Details / Access, LAUNCH / OPEN, EXPLORER). |
| `documents-explorer.js` / `.css` | Pestañas de ARCHIVE INDEX, ruta de carpetas, barras de desplazamiento propias y todos los estilos agregados. |
| `planner.js` | Tareas y eventos desde el puente, botones "+ ADD" y reinicio diario. |
| `wallpaper-switch.js` | Botón y menú "Change to Background". |

`bridge-config.js` (generado por el instalador, excluido de git) define `window.rhineBridgeConfig = { port, token }`.

---

## Yan Bridge

PowerShell 5.1 con `TcpListener` en `127.0.0.1:47831`. Cada petición necesita la clave y un encabezado `Host` local (ver [SECURITY.md](SECURITY.md)).

| Ruta | Para qué |
|---|---|
| `GET /api/ping` | Estado y ubicaciones configuradas |
| `GET /api/list?root=&path=` | Contenido de una carpeta dentro de una ubicación (con datos del programa) |
| `POST /api/open` | Abrir, ejecutar o mostrar un elemento (reglas en SECURITY.md) |
| `GET/POST /api/planner` | Leer y guardar `planner.json` |
| `POST /api/editor` y `GET /editor` | Abrir y servir el editor del planner (ventana de Edge) |
| `GET /api/backgrounds` | Proyectos de `myprojects` con la propiedad de acceso directo `yanlab` |
| `POST /api/wallpaper?target=` | Cambia el fondo del monitor donde está el cursor (con la línea de comandos de Wallpaper Engine) y vuelve a aplicar el acceso directo de regreso |

Archivos en `%LOCALAPPDATA%\RhineBridge\`: `token.txt`, `roots.json`, `planner.json`, `wallpapers.json`, `return-to-yanlab.vbs`, `launch.vbs` y `bridge.log`, más un acceso directo *Yan Bridge* en la carpeta de Inicio. El nombre `RhineBridge` se mantiene por compatibilidad con instalaciones anteriores.

---

## Fondos alternativos

- **Escena:** desempaqueta `scene.pkg` (tabla `PKGVxxxx` de nombre/posición/tamaño), copia `src/backgrounds/scene/{materials,models}`, agrega `button-object.json` a `scene.json` (7,5 % del ancho, centrado en 8,94 % × 10,68 % desde abajo a la izquierda) y la propiedad `yanlab`. El SceneScript llama a `engine.openUserShortcut('yanlab')`.
- **Video:** `src/backgrounds/video/index.html` reproduce el video a pantalla completa y hace `POST /api/wallpaper?target=yanlab`. ffmpeg (opcional) lo convierte a WebM VP9/Opus.

---

## Actualizar para una versión nueva del original

1. Conseguir la versión nueva y ajustar los textos `find` de cada parche.
2. Recalcular `sourceSha256` (original nuevo) y `resultSha256` (resultado parcheado), por ejemplo con `Get-FileHash -Algorithm SHA256`.
3. Probar el instalador con `-Name` de prueba y revisar el fondo en Wallpaper Engine.
