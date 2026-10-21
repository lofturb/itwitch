# iTwitch para iOS 9.3.5 (32 bits)

Cliente **no oficial** de Twitch para iPhone/iPad de 32 bits con iOS 9.

## Qué necesitas

- Un dispositivo con **jailbreak** y **AppSync Unified**.
- El perfil **`CertificadosModernos.mobileconfig`** de este repositorio
  instalado. Sin él, iOS 9 no confía en los certificados de Twitch.
- Descargar el `.ipa` de este Release y abrirlo con Filza, iFile o similar.

### Instalar los certificados sin que falle GitHub en iOS 9

En el ordenador, dentro de la carpeta del repositorio:

```sh
python -m http.server 8000
```

Averigua la IP local del ordenador y abre en Safari del iPad:

```text
http://IP-DEL-ORDENADOR:8000/certificados/CertificadosModernos.mobileconfig
```

Instala el perfil desde **Ajustes → General → Perfil**. También sirve pasarlo
por AirDrop, correo o Filza.

## Qué trae esta versión

- Inicio, Explorar, Buscar (con sugerencias), Siguiendo y Perfil.
- Canal con Inicio, Vídeos, Clips, Colecciones y Acerca de.
- Reproductor propio: directo, VOD y clips, con calidad, velocidad, chat,
  pantalla completa, AirPlay, compartir y menú de opciones.
- Chat en directo por IRC/TLS, emotes de Twitch y chat replay en VODs. En iPad
  se muestra al lado del vídeo cuando la pantalla está en horizontal.
- Mini reproductor flotante que reutiliza el mismo `AVPlayer`.
- Reanudación de VOD y reproducción encadenada en colecciones.
- Avisos locales de nuevos directos de canales seguidos.
- Audio en segundo plano y controles remotos.
- Diagnóstico de conexión y ajustes de tema, calidad y chat.

### Novedades de esta versión

- **Sin el cartel «Commercial break in progress»**: al entrar en un directo,
  Twitch metía el anuncio previo del reproductor web; en el iPad ese anuncio no
  se rellena y el cartel se quedaba encima del vídeo. Ahora se pide el directo
  como el reproductor incrustado, que no inserta ese anuncio, con las mismas
  calidades y sin tocar la reproducción.
- **Reproductor rediseñado**: los controles ocupan toda la pantalla y cada
  botón lleva su icono y su nombre (Calidad, Velocidad, Chat, Bajar, Pantalla),
  así que ya no hay iconos invisibles ni funciones escondidas.
- **Chat ocultable**: el botón **Chat** lo muestra u oculta y el vídeo ocupa
  todo el espacio libre. En horizontal sigue al lado del vídeo.
- **Descargas de VOD** a la carpeta que elijas, por defecto
  `/var/mobile/Media/iTwitch` (visible desde Filza). Se elige la calidad, se
  pueden cancelar, reintentar y borrar, y se guardan en MP4 (o `.ts` si el
  sistema no puede convertirlos). Lista en **Perfil → Descargas**.
- **Temporizador de apagado** (15, 30, 60 o 90 minutos).
- **Copiar enlace en este minuto** para compartir un VOD desde el punto exacto.
- **Velocidad recordada** entre vídeos y **calidad de solo audio**.
- **Reproducción de las descargas** dentro de la propia app.

## Método de inicio de sesión

La web de Twitch dentro de la app puede aceptar usuario y contraseña, pero
Google/Apple suelen rechazar el `UIWebView`. El método garantizado es pegar el
token manual:

1. En un navegador de escritorio, con la sesión iniciada, abre las herramientas
   de desarrollo → Application → Cookies → `https://www.twitch.tv`.
2. Copia el valor de **`auth-token`**.
3. En la app: Perfil → Ajustes → **Pegar auth-token**.

El token se guarda en el Keychain. No lo compartas.

## Límites

- La API pública no permite buscar vídeos o clips globalmente, solo dentro de
  cada canal.
- No se puede seguir/dejar de seguir, comprar Bits, suscribirse, crear clips ni
  gestionar el directo. El botón de seguir del canal abre su página web.
- El chat replay se descarga por tramos y se limita a 6000 mensajes.
- Los avisos son locales: no hay push real porque haría falta un servidor APNs.
- No hay Chromecast; AirPlay depende de la red local.

## Verificación

El `.ipa` se comprueba con `tools/verificar_ipa.py`: armv7, iOS 9.0 mínimo,
bundle `com.lofturb.itwitch`, binario pseudo-firmado con `ldid`.

## Aviso legal

iTwitch no está afiliado a Twitch Interactive, Inc. Es un cliente no oficial
hecho por afición para dispositivos antiguos. Twitch y el logotipo de Twitch son
marcas de Twitch Interactive, Inc.
