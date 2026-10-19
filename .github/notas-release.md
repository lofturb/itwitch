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
- Chat en directo por IRC/TLS y chat replay en VODs.
- Mini reproductor flotante que reutiliza el mismo `AVPlayer`.
- Reanudación de VOD y reproducción encadenada en colecciones.
- Avisos locales de nuevos directos de canales seguidos.
- Audio en segundo plano y controles remotos.
- Diagnóstico de conexión y ajustes de tema, calidad y chat.

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
  gestionar el directo.
- Los avisos son locales: no hay push real porque haría falta un servidor APNs.
- No hay Chromecast; AirPlay depende de la red local.

## Verificación

El `.ipa` se comprueba con `tools/verificar_ipa.py`: armv7, iOS 9.0 mínimo,
bundle `com.lofturb.itwitch`, binario pseudo-firmado con `ldid`.

## Aviso legal

iTwitch no está afiliado a Twitch Interactive, Inc. Es un cliente no oficial
hecho por afición para dispositivos antiguos. Twitch y el logotipo de Twitch son
marcas de Twitch Interactive, Inc.
