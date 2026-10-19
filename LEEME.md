# iTwitch — por dónde empezar

iTwitch es un cliente **no oficial** de Twitch para **iOS 9.3.5 de 32 bits
(armv7)**, escrito en Objective-C con Theos y compilado en GitHub Actions sin
Mac ni Xcode.

La guía de uso, instalación, certificados, inicio de sesión y límites está en
**`README.md`**. La guía detallada de compilación sin Mac (Theos, SDK 9.3,
`liblaunch.tbd`, empaquetado, Releases e instalación) está en **`PROCESO.md`**.

## Resumen rápido

1. Instala el perfil `certificados/CertificadosModernos.mobileconfig` en el
   dispositivo (ver README; sirve un servidor HTTP local para evitar el problema
   de confianza de iOS 9 con GitHub).
2. Instala el `.ipa` del último Release con Filza/iFile y AppSync Unified.
3. Abre la app. Para seguir canales, chat con cuenta y avisos, inicia sesión
   desde Perfil o pega el token `auth-token` en Ajustes.

## Compilar

Push a `main` o **Actions → Construir IPA → Run workflow**. El workflow ejecuta
`tools/comprobar_fuentes.py`, compila con Theos y publica el `.ipa` como
artefacto y Release.

## Verificar

```sh
python tools/verificar_ipa.py dist/iTwitch-1.0.0.ipa
```
