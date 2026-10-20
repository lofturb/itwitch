# iTwitch

Cliente **no oficial** de Twitch para dispositivos de 32 bits con iOS 9
(iPhone 4S/5/5C, iPad 2/3/4, iPad mini 1, iPod touch 5G).

[![Construir IPA](https://github.com/lofturb/itwitch/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/lofturb/itwitch/actions/workflows/build-ipa.yml)

Escrito en Objective-C con Theos. Sin Mac, sin Xcode, sin Swift, sin storyboards
y sin dependencias de terceros. GitHub Actions compila contra el SDK de iOS 9.3,
enlaza para **armv7** y publica un `.ipa` pseudo-firmado con `ldid` para
dispositivos con jailbreak y **AppSync Unified**.

## Estado

La versión **1.0.0** compila y se empaqueta correctamente. El `.ipa` se verifica
con `tools/verificar_ipa.py`:

- arquitectura **ARM / armv7** de 32 bits;
- mínimo **iOS 9.0**, SDK 9.3;
- bundle **`com.lofturb.itwitch`**;
- binario pseudo-firmado con `ldid` y sin cifrar.

La validación en un iPad mini 1 físico está pendiente de instalar el perfil de
certificados y el `.ipa` en el dispositivo.

## Qué necesitas

1. Un dispositivo con **jailbreak**.
2. **AppSync Unified** instalado (Cydia/Sileo), para aceptar apps sin firma de
   Apple.
3. El perfil **`certificados/CertificadosModernos.mobileconfig`** instalado.
   Sin él, iOS 9 no confía en los certificados actuales de Twitch y la app no
   puede cargar datos ni vídeo.
4. El `.ipa` de la sección [Releases](https://github.com/lofturb/itwitch/releases).

> iOS 9 ya no trae las raíces modernas de Amazon, GlobalSign o Let's Encrypt.
> `NSAllowsArbitraryLoads` **no** desactiva la validación de certificados: el
> perfil es obligatorio para que `https://gql.twitch.tv`, `usher.ttvnw.net`,
> `static-cdn.jtvnw.net` e `irc.chat.twitch.tv` funcionen.

## Instalar los certificados

El perfil incluye cuatro raíces:

| Certificado | Se usa para |
|---|---|
| Amazon Root CA 1 | `usher.ttvnw.net`, `id.twitch.tv`, `irc.chat.twitch.tv` |
| GlobalSign Root R46 | `gql.twitch.tv`, `www.twitch.tv`, CDN de imágenes |
| ISRG Root X1 | Compatibilidad con Let's Encrypt |
| ISRG Root X2 | Compatibilidad con Let's Encrypt |

La forma más sencilla, sin depender de que el iPad pueda abrir GitHub por HTTPS:

1. En el ordenador, dentro de esta carpeta, ejecuta:
   `python -m http.server 8000`
2. Averigua la IP local del ordenador (`ipconfig` en Windows).
3. En Safari del iPad abre:
   `http://IP-DEL-ORDENADOR:8000/certificados/CertificadosModernos.mobileconfig`
4. Acepta la descarga y ve a **Ajustes → General → Perfil** (o **Perfiles**)
   para instalarlo. iOS avisará de que el perfil no está firmado; es normal.
5. Comprueba que aparece **CertificadosModernos** en la lista de perfiles.

También puedes pasarlo por AirDrop, correo o Filza. No instales certificados
que no conozcas: este perfil solo contiene las cuatro raíces de la tabla.

## Instalar el `.ipa`

1. Descarga `com.lofturb.itwitch_1.0.0.ipa` desde **Releases**.
2. Ábrelo con **Filza**, **iFile** o el instalador de tu jailbreak.
3. Confirma la instalación. Si el icono aparece en blanco, reinicia el
   SpringBoard.
4. Abre iTwitch.

El `.ipa` no está firmado por Apple. Solo funciona con jailbreak y AppSync
Unified; no sirve para instalar con AltStore, Sideloadly ni una cuenta de
desarrollador.

## Iniciar sesión

Sin cuenta se puede ver Inicio, Explorar, Buscar, canales, VODs, clips y chat
anónimo. Para seguir canales, ver **Siguiendo**, enviar mensajes y recibir avisos
hay que iniciar sesión:

- **Usuario y contraseña:** Perfil → **Entrar**. Se abre la web de Twitch dentro
  de la app y se captura la cookie `auth-token`.
- **Token manual (método garantizado):** en un navegador de escritorio, con la
  sesión de Twitch abierta, abre las herramientas de desarrollo → Application →
  Cookies → `https://www.twitch.tv` → copia el valor de **`auth-token`**.
  Después, en la app: Perfil → **Ajustes** → **Pegar auth-token**.

El token se guarda en el **Keychain** y equivale a la contraseña de la cuenta:
no lo compartas ni lo publiques. El inicio de sesión con Google o Apple dentro
de `UIWebView` suele ser rechazado por Twitch; usa el token manual si falla.

## Funciones incluidas

- **Inicio**: categorías populares, directos destacados y campana de avisos.
- **Explorar**: categorías con búsqueda local y acceso a sus directos.
- **Buscar**: canales y categorías con sugerencias en vivo y búsquedas
  recientes.
- **Siguiendo**: canales seguidos, en directo primero, con refresco automático.
- **Perfil**: cuenta, Siguiendo, Ajustes y enlaces informativos a
  Suscripciones, Bits, Drops y Acerca de iTwitch.
- **Canal**: cabecera, directo, Inicio, Vídeos, Clips, Colecciones y Acerca de.
- **Reproductor propio**: directo, VOD y clips; calidad, velocidad, salto de
  10 s, pantalla completa, AirPlay, compartir, copiar enlace, abrir en Twitch y
  menú de reporte.
- **Chat**: IRC sobre TLS, anónimo o con cuenta; emotes de Twitch y chat replay
  en VODs. En iPad, al girar a horizontal, el chat se coloca al lado del vídeo.
- **Mini reproductor**: sigue sonando al cerrar el reproductor, se arrastra, se
  cierra y vuelve al reproductor grande. Al minimizar se reutiliza el mismo
  `AVPlayer`, sin recargar el vídeo.
- **Reanudación de VOD**: guarda la posición cada 5 segundos y la recupera al
  volver a abrir el vídeo.
- **Colecciones**: reproducir todo y encadenar el siguiente VOD al terminar.
- **Avisos locales**: consulta los canales seguidos y avisa cuando empiezan un
  directo. No son notificaciones push reales.
- **Audio en segundo plano** y controles remotos (play/pausa, siguiente/anterior
  de 10 s).
- **Ajustes**: tema, calidad máxima, chat, reanudación, avisos y diagnóstico.

## Límites conocidos

La API pública de Twitch no permite algunas cosas que sí hace la app oficial:

- No hay búsqueda **global** de vídeos o clips; solo dentro de un canal.
- No se puede seguir o dejar de seguir desde la app (solo leer la lista). El
  botón de seguir del canal abre su página web de Twitch.
- El chat replay se descarga por tramos y se limita a **6000 mensajes** para no
  agotar la memoria de un A5 en VODs muy largos.
- No hay compras, suscripciones, Bits, Drops, predicciones, raids ni whispers.
- No se pueden crear clips ni gestionar el directo.
- No hay notificaciones push reales: haría falta un servidor APNs propio. Los
  avisos son locales y se generan mientras la app está viva.
- No hay Chromecast. AirPlay depende de `MPVolumeView` y de la red local.
- Los anuncios que Twitch inserta en el HLS se reproducen si el reproductor los
  recibe; no se pueden saltar desde la app.

## Compilar

El flujo de GitHub Actions se ejecuta al hacer push a `main` o a mano desde
**Actions → Construir IPA → Run workflow**. El workflow:

1. comprueba fuentes y metadatos con `tools/comprobar_fuentes.py`;
2. instala Theos, el toolchain LLVM y el SDK de iOS 9.3;
3. compila con `ARCHS=armv7`;
4. empaqueta con `make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa`;
5. publica el `.ipa` como artefacto y crea un Release `build-AAAAMMDD-HHMMSS`.

Para compilar en local hace falta Theos, el SDK de iOS 9.3 y el toolchain
compatible con armv7:

```sh
cd app
make clean
make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
```

La guía detallada de compilación sin Mac está en `PROCESO.md`.

## Verificar un `.ipa`

```sh
python tools/verificar_ipa.py dist/iTwitch-1.0.0.ipa
```

Comprueba la cabecera Mach-O (armv7, iOS mínimo, `ldid`), el bundle ID, el
`Info.plist` y los recursos. No necesita Mac ni `otool`.

## Estructura

```text
app/                     Código Objective-C y Makefile
  AppDelegate.m          Arranque, pestañas y notificaciones locales
  ITApi.m                GraphQL público de Twitch
  ITPlayback.m           Tokens y URLs HLS de directo/VOD, clips
  ITPlayerViewController Reproductor propio
  ITMiniPlayer.m         Mini reproductor flotante
  ITChatClient.m         IRC/TLS
  ITChatViewController.m Chat en directo y replay
  ITNotifications.m      Avisos locales de directos
  Resources/             Info.plist, iconos y arranque
certificados/            Perfil de raíces modernas para iOS 9
tools/                   Recursos, verificación y comprobación de fuentes
.github/workflows/       Compilación y publicación del IPA
```

## Diagnóstico

**Perfil → Ajustes → Diagnóstico de conexión** comprueba la sesión, GraphQL,
los certificados TLS, el CDN de imágenes, el token de reproducción, Usher e IRC.
Si algo falla, muestra el error concreto y permite copiarlo para reportarlo.

## Créditos

La estructura de compilación y el tema visual están inspirados en **Tube9**, del
mismo autor. Algunas ideas de consultas y pantallas se contrastaron con
**OpenTwitch**. No se ha copiado código de la app oficial de Twitch.

## Aviso legal

iTwitch no está afiliado a Twitch Interactive, Inc. Es un cliente no oficial
hecho por afición para dispositivos antiguos. Twitch y el logotipo de Twitch son
marcas de Twitch Interactive, Inc.
