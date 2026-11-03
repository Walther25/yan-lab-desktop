# THIRD-PARTY-NOTICES.md — Créditos, licencias y contenido excluido

Yan Lab · Desktop es un **conjunto de parches y herramientas complementarias**. No contiene ni descarga ningún archivo del fondo original ni de otros ítems del Workshop. Todo lo que aparece abajo está **incluido** bajo las condiciones indicadas, o bien **lo obtiene cada persona** por su cuenta a través de Steam.

---

## Incluido en este repositorio

### Fragmentos del código de "Rhine Lab · Interactive Desktop" — MIT

Los archivos `src/patches/*.json` contienen fragmentos cortos del JavaScript compilado del fondo original, necesarios para ubicar y modificar el código. Ese código lo publica su autor bajo la licencia MIT ([repositorio fuente](https://github.com/LBEILC/RhineLabUI)):

```
MIT License

Copyright (c) 2026 LBEILC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Botón "↗ Yan Lab" — hecho con MiSans

`src/backgrounds/video/yanlab_button.png` y `src/backgrounds/scene/materials/yanlab_button.tex` (la misma imagen en el formato de textura de Wallpaper Engine) son un diseño propio cuyo texto se escribió con la tipografía **MiSans** de Xiaomi. El acuerdo de licencia de MiSans permite distribuir obras creadas con la fuente y pide indicar que se usó MiSans, cosa que hace este aviso. **No se incluye ningún archivo de fuente.**
MiSans © Beijing Xiaomi Mobile Software Co., Ltd. — https://hyperos.mi.com/font/download

### Capturas de pantalla

`docs/capturas/*.jpg` son capturas tomadas por el autor del fondo en funcionamiento, con las modificaciones de este proyecto. Muestran el archivo 3D y el diseño visual de "Rhine Lab · Interactive Desktop" (LBEILC), que **no** se licencian bajo la MIT de este repositorio; se incluyen solo como ilustración del proyecto, con atribución. Si el autor original prefiere que no se muestren, se retiran.

---

## No incluido (cada persona lo obtiene por su cuenta)

| Material | Titular / condiciones | Por qué no está aquí |
|---|---|---|
| Paquete del fondo "Rhine Lab · Interactive Desktop" (ítem 3799142774 del Workshop): aplicación compilada, modelos 3D, imágenes, textos de los archivos, audio | LBEILC. Su licencia MIT cubre solo el código; los modelos, imágenes y demás recursos no se declaran bajo MIT. Los ítems del Workshop se licencian a los suscriptores para uso personal y no comercial según el Acuerdo de Suscriptor de Steam. | El instalador arma tu versión a partir de tu propia suscripción. |
| Fuentes web MiSans incluidas en ese paquete | Xiaomi, licencia MiSans (prohíbe redistribuir los archivos de fuente por separado) | Se usan solo desde tu copia local. |
| Letras Novecento Sans dibujadas en ese paquete | Jan Tonellato / Synthview; LBEILC las usa como gráficos | Se usan solo desde tu copia local. |
| Sonido corto de escritura de ese paquete | Fragmento de un video oficial de *Arknights*; el autor original lo excluye de su licencia | Se usa solo desde tu copia local. |
| three.js y @kitlangton/rolling-number (dentro de ese paquete) | MIT, de sus autores | Son parte del original, no de este repositorio. |
| Fondos que conviertas con `New-YanLabBackground.ps1` | Sus respectivos autores | La herramienta trabaja sobre tu copia local; no se redistribuye nada. |

---

## Nombres y marcas

*Arknights*, *Rhine Lab* y los personajes, nombres y ambientación relacionados pertenecen a Hypergryph / Yostar y a sus respectivos titulares. *Wallpaper Engine* pertenece a Wallpaper Engine Team y *Steam* a Valve Corporation. Este es un proyecto de fans **no oficial**, sin afiliación ni respaldo de ninguno de ellos.
