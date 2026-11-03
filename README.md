# Yan Lab · Desktop — escritorio interactivo para Wallpaper Engine

Un fondo de pantalla interactivo que funciona como **escritorio**: desde el propio fondo se pueden **abrir aplicaciones y juegos**, **explorar documentos**, **organizar las tareas del día** y **cambiar a otros fondos animados**.

---

## ¿De qué trata este proyecto?

[Wallpaper Engine](https://store.steampowered.com/app/431960/Wallpaper_Engine/) permite usar páginas web, escenas y videos como fondo de pantalla. Uno de esos fondos, **[*Rhine Lab · Interactive Desktop*](https://github.com/LBEILC/RhineLabUI)** de **LBEILC** (un fondo no oficial inspirado en *Arknights*), muestra un archivo de cajas de vidrio en 3D y un pequeño espacio de trabajo con reloj, tareas y temporizador. Es muy vistoso, pero su contenido es decorativo: los "archivos" son textos de ficción y las tareas son tres campos fijos.

Este proyecto lo convierte en algo **útil en el día a día**:

- Las cinco columnas del archivo pasan a mostrar **tus propias carpetas**: accesos directos de programas, clientes y juegos, y tus documentos.
- Cada "archivo" muestra la información real del programa o documento y permite **abrirlo** con un clic.
- Las tareas y eventos se escriben en una ventana propia y se guardan en tu computadora.
- Un menú permite **cambiar a otro fondo** más liviano (una escena o un video) en la pantalla que elijas, y volver cuando quieras.

Es un **proyecto personal**: modifica una aplicación web ya compilada sin tocar el original y conecta una página web con el sistema operativo **de forma segura**.

> **Importante:** este repositorio **no incluye el fondo original**. Cada persona se suscribe a él en el Steam Workshop y el instalador arma la versión modificada a partir de **su propia copia**. Más detalles en [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

---

## ¿Cómo funciona? (en palabras simples)

Un fondo de Wallpaper Engine es, en el fondo, una **página web**. Por seguridad, una página web no puede ver los archivos de la computadora ni abrir programas. Por eso el proyecto tiene tres partes:

- **Parches** — pequeños cambios de texto, aplicados en orden sobre el código del fondo original, que le agregan "enchufes" donde se conectan las funciones nuevas. Antes y después de aplicarlos se compara una **huella digital** (SHA-256) para asegurar que todo quedó exactamente como debe.
- **Overlay** — scripts y estilos propios que el fondo carga: el mapeo de carpetas al archivo, el explorador, el planner y el menú de fondos.
- **Yan Bridge** — un servidor muy pequeño que corre **solo dentro de tu computadora** (`127.0.0.1`). El fondo le pide "¿qué hay en la carpeta *Games*?" o "abrí este acceso directo", y el puente responde solo si la petición trae una **clave secreta** que se genera al instalar. No acepta conexiones de la red ni ejecuta comandos arbitrarios.

```
Copia del Workshop (original, no se toca)
        │
        ▼
instalador  →  verifica  →  copia  →  aplica parches  →  verifica  →  myprojects\yan-lab-desktop
                                                                              │
                                                                              ▼
            Fondo en Wallpaper Engine  ⇄  Yan Bridge (127.0.0.1 + clave)  ⇄  tus carpetas, tareas
                                                                             y Wallpaper Engine
```

---

## Funcionalidades

| Función | Qué hace |
|---|---|
| **Archivo = tu escritorio** | Las columnas muestran *PC settings*, *Clients*, *Apps*, *Games* (carpetas de accesos directos en tu Escritorio) y *Documents*. Las flechas recorren los archivos de cada columna. |
| **Ficha de detalle** | **ACCESS FILE** muestra *Details* (programa, editor, versión, tamaño, fechas…) y *Access*, con los botones **LAUNCH / OPEN** y **EXPLORER**. |
| **ARCHIVE INDEX** | Explorador por pestañas con navegación por subcarpetas y barras de desplazamiento propias. Se actualiza solo al agregar o quitar archivos. |
| **Planner** | *Today's tasks* y *Upcoming events* salen de un planner local. **+ ADD** abre una ventana para escribirlas (Wallpaper Engine no le da el teclado al fondo). Las tareas completadas se reinician cada día. |
| **Change to Background** | Lista fondos alternativos y cambia **solo la pantalla donde hiciste clic**. Cada fondo alternativo tiene un botón **↗ Yan Lab** para volver. |
| **Generador de fondos** | Convierte cualquier escena o video de Wallpaper Engine que tengas en un fondo alternativo con su botón de regreso. |
| **Rendimiento** | Menos trabajo por cuadro sin cambiar la imagen, 3D en resolución completa solo en la ficha de detalle y preparación del 3D durante la pantalla de inicio, para que **ENTER SYSTEM** no se trabe. |
| **Detalles visuales** | Interfaz en inglés, marca *YAN LAB*, cajas sin tornillos, compatible con el tema oscuro y con los márgenes de interfaz. |

Sin Yan Bridge el fondo funciona igual que el original, con la interfaz en inglés y las mejoras de rendimiento.

---

## Estructura del repositorio

```
.
├── src/
│   ├── patches/             # Cambios sobre el fondo original (JSON) + manifest.json con las huellas SHA-256
│   ├── overlay/             # Scripts y estilos que carga el fondo
│   │   ├── desktop-archive.js       # Columnas del archivo y ficha de detalle
│   │   ├── documents-explorer.js    # Explorador ARCHIVE INDEX
│   │   ├── documents-explorer.css   # Todos los estilos agregados
│   │   ├── planner.js               # Tareas y eventos
│   │   └── wallpaper-switch.js      # Menú "Change to Background"
│   ├── bridge/              # Yan Bridge: servidor local, editor del planner e (des)instaladores
│   ├── backgrounds/         # Botón "↗ Yan Lab" y plantillas para fondos alternativos
│   │   ├── scene/
│   │   └── video/
│   └── script/              # Lo que se ejecuta
│       ├── install.bat                  # 1) Instalación (doble clic)
│       ├── Install-YanLab.ps1           #    Instalador completo
│       └── New-YanLabBackground.ps1     # 2) Crear fondos alternativos
├── ARQUITECTURA.md          # Cómo está construido por dentro
├── SECURITY.md              # Qué puede y qué no puede hacer Yan Bridge
├── THIRD-PARTY-NOTICES.md   # Créditos, licencias y qué no se incluye
├── README.md
└── LICENSE
```

---

## Requisitos

| Requisito | Detalle |
|---|---|
| Sistema | Windows 10 u 11 (usa Windows PowerShell 5.1, que ya viene con Windows) |
| Wallpaper Engine | Versión de Steam |
| Fondo original | Suscripción al ítem [`3799142774`](https://steamcommunity.com/sharedfiles/filedetails/?id=3799142774) del Workshop, en la versión exacta indicada en `src/patches/manifest.json` |
| Editor del planner | Microsoft Edge (ya viene con Windows) |
| Opcional | [ffmpeg](https://ffmpeg.org/) en el `PATH`, para convertir fondos de video |

---

## ¿Cómo usarlo?

### 1. Instalar

1. **Suscribite** a *Rhine Lab · Interactive Desktop* en el Steam Workshop y esperá a que Wallpaper Engine lo descargue.
2. **Descargá este repositorio**: *Code → Download ZIP*. Antes de descomprimirlo, clic derecho en el ZIP → *Propiedades* → marcá *Desbloquear*.
3. Ejecutá **`src\script\install.bat`** (doble clic). El instalador:
   - busca Wallpaper Engine y el fondo original;
   - verifica la versión del original y, si no coincide, **se detiene sin cambiar nada**;
   - crea `Wallpaper Engine\projects\myprojects\yan-lab-desktop`, aplica los parches y verifica el resultado;
   - instala **Yan Bridge**, que además arranca solo cada vez que iniciás sesión.
4. En Wallpaper Engine elegí **Yan Lab · Desktop** en tus fondos. Si no aparece, reiniciá Wallpaper Engine una vez.

Opciones del instalador:

| Opción | Uso |
|---|---|
| `-Name <carpeta>` | Otro nombre para la carpeta del proyecto (útil para probar sin tocar tu instalación) |
| `-Force` | Reconstruye el proyecto; la carpeta anterior queda como respaldo |
| `-SkipBridge` | Solo arma el fondo, sin Yan Bridge |
| `-WorkshopPath` / `-WallpaperEnginePath` | Rutas manuales si no se detectan solas |

```powershell
powershell -ExecutionPolicy Bypass -File .\src\script\Install-YanLab.ps1 -Name yan-lab-prueba
```

### 2. Configurar tus categorías

Creá en tu **Escritorio** las carpetas que quieras de esta lista y poné accesos directos dentro:

| Carpeta | Ejemplo de contenido |
|---|---|
| `PC settings` | Panel de control, antivirus, utilidades |
| `Clients` | Steam, Discord, Epic Games |
| `Apps` | Navegador, Office, editores |
| `Games` | Accesos directos de juegos |

Las carpetas que no existan simplemente no se muestran; **Documents** siempre está disponible. Los archivos que agregues dentro aparecen solos, pero si creás una **carpeta de categoría nueva** después de instalar, ejecutá otra vez `yan-bridge\install-bridge.bat` (dentro de la carpeta del proyecto) para que el puente la incluya. La lista se guarda en `%LOCALAPPDATA%\RhineBridge\roots.json`.

> En las cuatro carpetas del Escritorio se abren accesos directos, `.exe`, `.jar` y `.appref-ms`. Los scripts (`.bat`, `.ps1`, `.vbs`…) **nunca** se ejecutan: solo se muestran en el Explorador. En *Documents* los archivos se abren con su aplicación predeterminada y los programas solo se muestran. Detalles en [SECURITY.md](SECURITY.md).

### 3. Crear fondos alternativos

```powershell
powershell -ExecutionPolicy Bypass -File .\src\script\New-YanLabBackground.ps1 `
  -Source "C:\Program Files (x86)\Steam\steamapps\workshop\content\431960\<id del ítem>" `
  -Title "Night City"
```

- **Escenas:** se desempaquetan y reciben el botón *↗ Yan Lab*. La primera vez, en las propiedades del fondo asigná **Return to Yan Lab** al archivo `yan-bridge\Return to Yan Lab.lnk` (dentro de la carpeta de Yan Lab · Desktop). Después el puente lo reutiliza solo.
- **Videos:** se convierten en un fondo web liviano con el mismo botón, volumen ajustable y pausa automática. Con ffmpeg instalado, el video se convierte a WebM 1080p.

Los fondos generados son **para uso personal**: no los subas al Workshop, porque contienen el trabajo de otras personas.

### 4. Ajustes recomendados en Wallpaper Engine

| Propiedad | Para qué |
|---|---|
| **UI margin bottom / left** | Que la interfaz no quede detrás de la barra de tareas (por ejemplo `80` con la barra abajo) |
| **Super performance** | Menos memoria; el vidrio y las sombras se simplifican |
| **Model precision: Low** | Modelos 3D más livianos |

---

## Tecnologías

- **PowerShell 5.1** — instalador, generador de fondos y Yan Bridge (servidor HTTP con `TcpListener`)
- **JavaScript / CSS** — overlay que corre dentro del fondo
- **Wallpaper Engine** — fondos web, escenas y SceneScript (botón de regreso)
- **three.js** — motor 3D del fondo original (no incluido en este repositorio)
- **ffmpeg** — conversión opcional de videos a WebM (VP9 / Opus)

---

## Limitaciones

- Funciona solo en **Windows** y solo con la **versión exacta** del fondo original. Si su autor lo actualiza, el instalador se niega a correr hasta que se actualicen los parches; la instalación que ya tenés sigue funcionando porque es una copia independiente.
- El editor del planner necesita **Microsoft Edge**.
- En los fondos de escena hay que asignar el botón de regreso **una vez** a mano (Wallpaper Engine lo exige por seguridad).
- Las categorías del Escritorio tienen nombres fijos (*PC settings*, *Clients*, *Apps*, *Games*).
- Es un **proyecto personal**: está probado en mi equipo, no en todas las configuraciones posibles.

---

## Créditos y licencias

- **Fondo original:** *Rhine Lab · Interactive Desktop* de **LBEILC** — [GitHub](https://github.com/LBEILC/RhineLabUI) · [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3799142774). Su código está bajo licencia MIT; los modelos, imágenes, audio y fuentes tienen sus propias condiciones y **no** se incluyen aquí.
- **Botón "↗ Yan Lab":** diseño propio, con la tipografía **MiSans** de Xiaomi (no se incluyen archivos de fuente).
- *Arknights* y *Rhine Lab* pertenecen a Hypergryph / Yostar; *Wallpaper Engine* a Wallpaper Engine Team; *Steam* a Valve. Proyecto de fans **no oficial**, sin afiliación con ninguno de ellos.

Todos los detalles en [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

---

## Contexto

Proyecto personal de personalización de escritorio, desarrollado con asistencia de IA.

Autor: **Walther Barrantes**.

---

## Licencia

El código y la documentación propios están bajo licencia MIT. Ver el archivo [`LICENSE`](LICENSE).
