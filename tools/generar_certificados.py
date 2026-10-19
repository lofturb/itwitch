# -*- coding: utf-8 -*-
"""
Genera el perfil de certificados que necesita iOS 9 para confiar en Twitch.

iOS 9.3.5 trae un almacen de raices de 2016. Twitch usa cadenas modernas:
  * gql.twitch.tv, www.twitch.tv y static-cdn.jtvnw.net -> GlobalSign Root R46
  * usher.ttvnw.net, id.twitch.tv e irc.chat.twitch.tv   -> Amazon Root CA 1

El perfil incluye esas dos raices y las de Let's Encrypt (por si acaso), y se
instala en el dispositivo como cualquier otro perfil. No hay dependencias
externas: solo la biblioteca estandar de Python 3.

Uso:
    python tools/generar_certificados.py
"""

import base64
import os
import plistlib
import ssl
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "certificados")

# (nombre visible, URL, identificador corto)
RAICES = [
    ("Amazon Root CA 1", "https://www.amazontrust.com/repository/AmazonRootCA1.cer", "amazonrootca1"),
    ("GlobalSign Root R46", "https://secure.globalsign.com/cacert/rootr46.crt", "globalsignr46"),
    ("ISRG Root X1 (Let's Encrypt)", "https://letsencrypt.org/certs/isrgrootx1.der", "isrgx1"),
    ("ISRG Root X2 (Let's Encrypt)", "https://letsencrypt.org/certs/isrg-root-x2.der", "isrgx2"),
]


def descargar(url):
    peticion = urllib.request.Request(url, headers={"User-Agent": "iTwitch/1.0"})
    with urllib.request.urlopen(peticion, timeout=30) as respuesta:
        return respuesta.read()


def a_der(datos):
    """Acepta DER o PEM y devuelve siempre DER."""
    if b"-----BEGIN CERTIFICATE-----" in datos:
        texto = datos.decode("ascii", "ignore")
        cuerpo = texto.split("-----BEGIN CERTIFICATE-----", 1)[1]
        cuerpo = cuerpo.split("-----END CERTIFICATE-----", 1)[0]
        return base64.b64decode("".join(cuerpo.split()))
    return datos


def main():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)

    contenido = []
    for indice, (nombre, url, clave) in enumerate(RAICES, start=1):
        print("Descargando %s..." % nombre)
        datos = a_der(descargar(url))
        if len(datos) < 400:
            raise RuntimeError("La raiz %s parece vacia o no es un certificado" % nombre)

        # Comprobacion basica de que el DER se puede leer como certificado.
        contexto = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        contexto.check_hostname = False
        contexto.verify_mode = ssl.CERT_NONE
        contexto.load_verify_locations(cadata=datos)

        contenido.append({
            "PayloadCertificateFileName": clave + ".cer",
            "PayloadContent": datos,
            "PayloadDescription": "Raiz de confianza necesaria para que iOS 9 valide HTTPS.",
            "PayloadDisplayName": nombre,
            "PayloadIdentifier": "com.lofturb.itwitch.cert." + clave,
            "PayloadType": "com.apple.security.root",
            "PayloadUUID": "7A1E4C10-0001-4B00-9E10-54B3901A%04d" % indice,
            "PayloadVersion": 1,
        })
        print("  %d bytes" % len(datos))

    perfil = {
        "PayloadContent": contenido,
        "PayloadDescription": "Raices modernas para Twitch en iOS 9.3.5 (iTwitch).",
        "PayloadDisplayName": "Certificados modernos para iTwitch",
        "PayloadIdentifier": "com.lofturb.itwitch.certificados",
        "PayloadOrganization": "lofturb",
        "PayloadRemovalDisallowed": False,
        "PayloadType": "Configuration",
        "PayloadUUID": "7A1E4C10-0000-4B00-9E10-54B3901A0000",
        "PayloadVersion": 1,
    }

    ruta = os.path.join(DESTINO, "CertificadosModernos.mobileconfig")
    with open(ruta, "wb") as f:
        plistlib.dump(perfil, f, fmt=plistlib.FMT_XML, sort_keys=False)
    print("Perfil escrito en %s" % ruta)

    # Tambien se guardan los .cer sueltos, utiles para revisarlos con openssl.
    for entrada in contenido:
        nombre = entrada["PayloadCertificateFileName"]
        with open(os.path.join(DESTINO, nombre), "wb") as f:
            f.write(entrada["PayloadContent"])


if __name__ == "__main__":
    main()
