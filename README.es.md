<div align="center">

# Yan Lab · Desktop

**Convierte un fondo interactivo de Wallpaper Engine en un escritorio funcional:<br>
abre tus aplicaciones y juegos, explora tus documentos, organiza tu día y cambia de fondo, todo desde el propio fondo.**

[English](README.md) · [Español](README.es.md)

</div>

---

Yan Lab · Desktop es un **conjunto de parches y un complemento local** para
[*Rhine Lab · Interactive Desktop*](https://github.com/LBEILC/RhineLabUI) de **LBEILC**
(ítem `3799142774` del Steam Workshop), un fondo no oficial de *Arknights* con un archivo
3D de vidrio y un espacio de trabajo.

> [!IMPORTANT]
> **Este repositorio no contiene el fondo original.** Te suscribes a él en el Steam Workshop;
> el instalador copia *tu* copia local, la verifica, aplica los parches y añade las funciones
> nuevas. La carpeta del Workshop nunca se modifica. El motivo está en
> [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Funciones

- **Tu escritorio dentro del archivo:** las cinco columnas pasan a ser tus categorías
  (*PC settings*, *Clients*, *Apps*, *Games* — carpetas de accesos directos en tu Escritorio —
  y *Documents*). **ACCESS FILE** muestra una ficha con *Details* y *Access* y los botones
  **LAUNCH / OPEN** y **EXPLORER**.
- **ARCHIVE INDEX:** explorador por pestañas con navegación por subcarpetas y barras de
  desplazamiento propias; se actualiza solo.
- **Planner:** tareas del día y próximos eventos guardados localmente; **+ ADD** abre una
  ventana de edición (Microsoft Edge), porque Wallpaper Engine no da el teclado al fondo.
- **Change to Background:** cambia a fondos alternativos (escenas o videos) solo en la
  pantalla donde hiciste clic, y vuelve con el botón **↗ Yan Lab**.
- **Rendimiento y detalles:** interfaz en inglés, marca *YAN LAB*, menos trabajo por cuadro,
  3D nítido solo en la ficha de detalle, entrada fluida al pulsar **ENTER SYSTEM**, sin
  tornillos en las cajas, compatible con el tema oscuro y con los márgenes de interfaz.

Sin Yan Bridge, el fondo se comporta como el original, pero con la interfaz en inglés y las
mejoras de rendimiento.

## Requisitos

- Windows 10 u 11 (Windows PowerShell 5.1, incluido en Windows).
- Wallpaper Engine (versión de Steam).
- Suscripción al ítem [`3799142774`](https://steamcommunity.com/sharedfiles/filedetails/?id=3799142774)
  en la versión exacta indicada en [`patches/manifest.json`](patches/manifest.json).
- Microsoft Edge para el editor del planner. Opcional: [ffmpeg](https://ffmpeg.org/) para
  convertir fondos de video.

## Instalación

1. **Suscríbete** a *Rhine Lab · Interactive Desktop* en el Steam Workshop y espera a que
   Wallpaper Engine lo descargue.
2. **Descarga este repositorio** (*Code → Download ZIP*, luego clic derecho en el ZIP →
   *Propiedades* → *Desbloquear*, y extráelo) o clónalo con `git clone`.
3. **Ejecuta `setup\install.bat`.** El instalador busca Wallpaper Engine y el fondo original,
   verifica su SHA-256 (si no coincide, se detiene sin cambiar nada), crea
   `Wallpaper Engine\projects\myprojects\yan-lab-desktop`, aplica y verifica los parches e
   instala **Yan Bridge** (que también arranca solo al iniciar sesión).
4. En Wallpaper Engine elige **Yan Lab · Desktop** en *Mis fondos* (si no aparece, reinicia
   Wallpaper Engine una vez).

Opciones: `-Name <carpeta>`, `-Force` (reconstruye; la carpeta anterior queda como respaldo),
`-SkipBridge` (solo el fondo), `-WorkshopPath` y `-WallpaperEnginePath`.

## Uso

- **Categorías:** crea en tu Escritorio las carpetas `PC settings`, `Clients`, `Apps` o
  `Games` y pon accesos directos dentro; las que no existan se omiten. *Documents* siempre
  está disponible. Configuración: `%LOCALAPPDATA%\RhineBridge\roots.json`.
- **Qué se ejecuta:** en las cuatro categorías del Escritorio se abren accesos directos,
  `.exe`, `.jar` y `.appref-ms`; los scripts nunca se ejecutan, solo se muestran en el
  Explorador. En *Documents* los archivos se abren con su aplicación predeterminada, y los
  programas, scripts y accesos directos solo se muestran. Ver [SECURITY.md](SECURITY.md).
- **Propiedades recomendadas de Wallpaper Engine:** *UI margin bottom/left* para que la
  interfaz no quede detrás de la barra de tareas (por ejemplo `80` con la barra abajo);
  *Super performance* y *Model precision: Low* para usar menos memoria.

## Fondos alternativos

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\New-YanLabBackground.ps1 `
  -Source "C:\Program Files (x86)\Steam\steamapps\workshop\content\431960\<id del ítem>" `
  -Title "Night City"
```

- **Escenas:** se desempaquetan y reciben el botón *↗ Yan Lab*. La primera vez, asigna su
  propiedad **Return to Yan Lab** al archivo `yan-bridge\Return to Yan Lab.lnk` (dentro de la
  carpeta de Yan Lab · Desktop). Después, el puente reutiliza esa configuración solo.
- **Videos:** se convierten en un fondo web liviano con el mismo botón, control de volumen y
  pausa. Si ffmpeg está instalado, el video se convierte a WebM 1080p.

Los fondos generados son para tu uso personal. **No los subas al Workshop**, porque
contienen obras de otras personas.

## Compatibilidad

Los parches corresponden a **una versión exacta** del fondo original. Si su autor lo
actualiza, el instalador se niega a ejecutarse en lugar de producir un fondo roto; tu
carpeta de Yan Lab ya instalada sigue funcionando porque es una copia independiente.

## Desinstalación

1. Ejecuta `yan-bridge\uninstall-bridge.bat` dentro de `...\projects\myprojects\yan-lab-desktop`
   (detiene el puente, quita el inicio automático, el token y los datos del planner).
2. Borra la carpeta `yan-lab-desktop` y los fondos `yan-lab-*` que hayas generado.

## Créditos y licencias

- **Fondo original:** *Rhine Lab · Interactive Desktop* de **LBEILC**. Su código está bajo
  licencia MIT; los modelos, imágenes, audio y fuentes tienen sus propias condiciones.
  [GitHub](https://github.com/LBEILC/RhineLabUI) ·
  [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3799142774)
- **Fuentes:** el botón se dibujó con **MiSans** de Xiaomi; no se incluyen archivos de fuente.
- **Este proyecto:** código y documentación originales bajo [licencia MIT](LICENSE); todo lo
  demás se detalla en [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

Proyecto de fans no oficial. *Arknights* y *Rhine Lab* pertenecen a Hypergryph / Yostar;
*Wallpaper Engine* a Wallpaper Engine Team; *Steam* a Valve. Sin afiliación ni respaldo.
