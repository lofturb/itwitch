# iTwitch — por dónde empezar

Esta carpeta todavía está vacía: aquí va el cliente de **Twitch** para
**iOS 9.3.5 de 32 bits (armv7)**, en la misma línea que Tube9.

Al lado está **`PROCESO.md`**: la guía de cómo se compila un `.ipa` para iOS 9
**sin Mac** (Theos + GitHub Actions, el SDK, la trampa de `liblaunch.tbd`, cómo
publicarlo en Releases y cómo instalarlo). Es una **copia literal** de la guía
del proyecto Tube9, que vive en `..\ipa\`, porque ese camino es el mismo:
**toda la parte de compilar y empaquetar vale tal cual**; lo que cambia es la
capa de servicio (Twitch en vez de YouTube).

## Se reutiliza sin tocar

* El *workflow* de GitHub Actions y el `Makefile` (sección **7** de la guía).
* `..\ipa\tools\generar_recursos.py` (iconos e imágenes de arranque),
  `..\ipa\tools\verificar_ipa.py` (comprobar el `.ipa` sin Mac) y
  `..\ipa\certificados\CertificadosModernos.mobileconfig`, que **cualquier** app
  de iOS 9 necesita hoy para poder hablar por HTTPS.
* La sección **8** de la guía (errores que ya han pasado y su arreglo) y la
  **10** (chuleta de comandos).

## Hay que hacerlo nuevo

* **La capa de datos**: la API de Twitch (Helix con token de aplicación, o su
  GraphQL público). Nada de lo de YouTube sirve aquí.
* **El directo**: Twitch sirve **HLS con H.264**, y `AVPlayer` de iOS 9 ya
  reproduce HLS. El techo de 360p que cuenta la guía es un problema de YouTube
  (VP9/AV1), no de Twitch: aquí **no debería aplicarse**.
* **La sesión**: el OAuth de Twitch necesita un navegador que comparta cookies
  (`UIWebView`, ver `..\ipa\app\YTLoginViewController.m`) o el flujo de código
  de dispositivo.

## Primer paso recomendado

Abrir una sesión nueva en esta carpeta y pedir, tal cual: *«lee `PROCESO.md` y
`..\ipa\README.md`, y móntame el esqueleto de la app (Theos, CI y un `.ipa`
instalable)»*. Así el punto de partida queda resuelto **antes** de escribir una
línea de Twitch.

---

> Nota: este fichero es sólo un recordatorio para quien empiece aquí; se puede
> borrar sin miedo. La guía de verdad es `PROCESO.md`.
