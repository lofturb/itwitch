# Entrega por red local (como Tube9)

Esta carpeta es **lo que se sirve**. No es parte de la app: es la página que se
abre en Safari desde el iPad para descargar los dos ficheros.

```
entrega-web/
  index.html                                        <- la página
  servir.py                                         <- el servidor (Python 3)
  servir.ps1                                        <- atajo para Windows
  certificados/CertificadosModernos.mobileconfig    <- PASO 1
  entrega/iTwitch.ipa                               <- PASO 2
```

## Arrancarlo

En el PC, dentro de esta carpeta:

```powershell
powershell -ExecutionPolicy Bypass -File servir.ps1
```

o directamente:

```powershell
python servir.py
```

Averigua la IP con `ipconfig` (aquí es **192.168.1.7**) y abre en **Safari del
iPad**:

```
http://192.168.1.7/
```

## Qué hace cada paso

| Paso | Fichero | Para qué |
|---|---|---|
| 1 | `CertificadosModernos.mobileconfig` | Instala las raíces de Amazon, GlobalSign e ISRG. Sin ellas iOS 9 no puede hablar con `gql.twitch.tv`, `usher.ttvnw.net` ni el CDN de Twitch. Se instala en **Ajustes → General → Perfil**. |
| 2 | `iTwitch.ipa` | La app. Safari la descarga; después se abre con **Filza** y se instala (requiere **AppSync Unified**). |

## Por qué hay un `servir.py` y no `python -m http.server`

Por el tipo MIME. iOS solo ofrece instalar un perfil si llega como
`application/x-apple-aspen-config`; con el servidor de serie llega como
`application/octet-stream` y Safari lo trata como un binario cualquiera.
`servir.py` solo añade esas dos cabeceras y por lo demás es el servidor
estándar de Python (sin dependencias).

## Alternativa: copiar por USB (sin WiFi)

Si la descarga desde Safari da problemas (el botón «Copiar a Filza» de iOS 9
falla a veces), el fichero se puede dejar directamente en el iPad por el cable:

```powershell
python tools\afc_put.py dist\iTwitch-1.0.0-full.ipa /iTwitch.ipa
python tools\afc_ls.py /
```

> Para AFC la raíz `/` **es** `/var/mobile/Media`, así que `/iTwitch.ipa` y
> `/var/mobile/Media/iTwitch.ipa` son el mismo fichero (el script acepta las
> dos formas).

Luego, en el iPad: **Filza → /var/mobile/Media → iTwitch.ipa → Instalar**.

## Actualizar el `.ipa`

Cuando salga una versión nueva, se copia encima:

```powershell
Copy-Item ..\dist\iTwitch-1.0.0-full.ipa .\entrega\iTwitch.ipa -Force
```

No hay que reiniciar el servidor, pero sí conviene cerrar la pestaña de Safari
en el iPad (el servidor manda `Cache-Control: no-store`, así que no se queda
con la versión vieja).
