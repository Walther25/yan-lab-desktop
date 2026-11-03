# Seguridad — Yan Bridge

Yan Bridge es un servidor HTTP pequeño, escrito en PowerShell, que le permite al fondo (una página web aislada dentro de Wallpaper Engine) ver y abrir los archivos de las carpetas que vos elegiste. Como puede abrir programas, está diseñado para hacer **lo mínimo indispensable**.

---

## Medidas de seguridad

| Medida | Detalle |
|---|---|
| Solo local | Escucha en `127.0.0.1:47831`; no se puede acceder desde la red. |
| Clave secreta | Al instalar se genera una clave aleatoria de 256 bits (`%LOCALAPPDATA%\RhineBridge\token.txt`) que se exige en cada petición. Se compara en tiempo constante y nunca se escribe en el log. |
| Control de `Host` | Se rechazan las peticiones cuyo encabezado `Host` no sea `127.0.0.1:<puerto>` o `localhost:<puerto>` (protege contra ataques de *DNS rebinding* desde páginas web). |
| Ubicaciones fijas | Solo se ven las carpetas de `roots.json`. Las rutas se normalizan y se rechaza cualquier cosa que quede fuera de esas carpetas. |
| Acciones limitadas | Los accesos directos (`.lnk`, `.url`, `.appref-ms`), `.exe` y `.jar` se ejecutan **solo** desde ubicaciones marcadas como lanzadores (por defecto, las carpetas del Escritorio *PC settings*, *Clients*, *Apps* y *Games*). Los scripts (`.bat`, `.cmd`, `.ps1`, `.vbs`, `.js`, …) nunca se ejecutan: solo se muestran seleccionados en el Explorador. En *Documents* no se inicia ningún programa, script ni acceso directo; los demás archivos se abren con su aplicación predeterminada. |
| Sin comandos arbitrarios | No existe ninguna ruta que ejecute una línea de comandos. El cambio de fondo solo abre proyectos de la carpeta `myprojects` de Wallpaper Engine, mediante la propia línea de comandos de Wallpaper Engine. |
| Peticiones pequeñas | Se rechazan cuerpos de más de 64 KB. |

---

## Archivos en tu computadora

`%LOCALAPPDATA%\RhineBridge\` guarda la clave, la copia del servidor, `roots.json` (tus carpetas visibles), `planner.json` (tus tareas y eventos) y `bridge.log` (que registra las rutas de los archivos que abrís). La carpeta del fondo recibe `bridge-config.js`, que contiene la clave.

**Ninguno de estos archivos debe subirse a un repositorio ni adjuntarse en un reporte de error.** El `.gitignore` los excluye, pero conviene revisarlo antes de compartir algo.

Para revocar el acceso, ejecutá `yan-bridge\uninstall-bridge.bat` dentro de la carpeta del proyecto (`...\projects\myprojects\yan-lab-desktop`). Eso borra la carpeta anterior, el acceso directo de inicio y `bridge-config.js` (también se borran tus tareas y eventos). Reinstalar después de desinstalar genera una clave nueva; reinstalar sin desinstalar conserva la actual.

---

## Reportar una vulnerabilidad

Por favor, no abras un *issue* público para problemas de seguridad. Usá **Security → Report a vulnerability** (reporte privado de vulnerabilidades) en este repositorio.
