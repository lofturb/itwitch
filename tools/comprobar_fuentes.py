# -*- coding: utf-8 -*-
"""Comprueba que las fuentes, el Makefile y el Info.plist son coherentes.

Uso:
    python tools/comprobar_fuentes.py

No compila nada: solo evita despistes como olvidar un .m en el Makefile,
dejar un fichero vacio o cambiar el bundle ID en un sitio y no en otro.
"""

import os
import plistlib
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(RAIZ, "app")
MAKEFILE = os.path.join(APP, "Makefile")
INFO = os.path.join(APP, "Resources", "Info.plist")


def error(texto):
    print("  ERROR: %s" % texto)
    return 1


def main():
    problemas = 0
    print("=== Fuentes ===")
    with open(MAKEFILE, encoding="utf-8") as f:
        makefile = f.read()

    bloque = re.search(r"iTwitch_FILES\s*=\s*(.*?)(?:\n\s*\n|\niTwitch_)",
                       makefile, re.S)
    if not bloque:
        print("  ERROR: no se encontro iTwitch_FILES en app/Makefile")
        return 1
    en_make = re.findall(r"([A-Za-z0-9_]+\.m)\b", bloque.group(1))
    en_disco = sorted(f for f in os.listdir(APP) if f.endswith(".m"))

    faltan = [f for f in en_disco if f not in en_make]
    sobran = [f for f in en_make if f not in en_disco]
    if faltan:
        problemas += error("en el disco pero no en Makefile: %s" % ", ".join(faltan))
    if sobran:
        problemas += error("en Makefile pero no en el disco: %s" % ", ".join(sobran))
    print("  .m en disco: %d; en Makefile: %d" % (len(en_disco), len(en_make)))

    for nombre in en_disco:
        ruta = os.path.join(APP, nombre)
        if os.path.getsize(ruta) == 0:
            problemas += error("fichero vacio: app/%s" % nombre)
            continue
        try:
            with open(ruta, encoding="utf-8") as f:
                f.read()
        except UnicodeDecodeError:
            problemas += error("no es UTF-8 valido: app/%s" % nombre)

    print("\n=== Info.plist ===")
    with open(INFO, "rb") as f:
        info = plistlib.load(f)

    esperado = {
        "CFBundleIdentifier": "com.lofturb.itwitch",
        "CFBundleName": "iTwitch",
        "CFBundleDisplayName": "iTwitch",
        "CFBundleShortVersionString": "1.0.0",
        "MinimumOSVersion": "9.0",
    }
    for clave, valor in esperado.items():
        real = info.get(clave)
        if real != valor:
            problemas += error("%s = %r (se esperaba %r)" % (clave, real, valor))
    if info.get("UIRequiredDeviceCapabilities") != ["armv7"]:
        problemas += error("UIRequiredDeviceCapabilities no es [armv7]")
    if "audio" not in info.get("UIBackgroundModes", []):
        problemas += error("falta UIBackgroundModes = audio")

    print("\n=== Certificados ===")
    perfil = os.path.join(RAIZ, "certificados", "CertificadosModernos.mobileconfig")
    if not os.path.isfile(perfil):
        problemas += error("falta certificados/CertificadosModernos.mobileconfig")
    else:
        with open(perfil, encoding="utf-8") as f:
            contenido = f.read()
        for nombre in ("Amazon Root CA 1", "GlobalSign Root R46"):
            if nombre not in contenido:
                problemas += error("el perfil no incluye %s" % nombre)
        print("  perfil: %d bytes" % os.path.getsize(perfil))

    print("\n=== Resultado ===")
    if problemas:
        print("  Hay %d problema(s)." % problemas)
        return 1
    print("  Correcto.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
