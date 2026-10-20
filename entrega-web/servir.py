# -*- coding: utf-8 -*-
"""
iTwitch  --  servidor de entrega para el iPad.

Hace lo mismo que el servidor de Tube9: sirve esta carpeta por HTTP plano
dentro de la red local, para que Safari del dispositivo pueda descargar:

    /                                        -> esta pagina
    /certificados/CertificadosModernos.mobileconfig
    /entrega/iTwitch.ipa

La diferencia con "python -m http.server" a secas es que aqui se declara el
tipo MIME correcto de los dos ficheros. Sin eso, iOS 9 se descarga el perfil
como binario y no ofrece instalarlo:

    .mobileconfig -> application/x-apple-aspen-config
    .ipa          -> application/octet-stream

Solo usa la biblioteca estandar de Python 3. No necesita pip.

Uso:
    python servir.py
    python servir.py --puerto 8080
"""

import argparse
import os
import socket
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

TIPOS = {
    ".mobileconfig": "application/x-apple-aspen-config",
    ".ipa": "application/octet-stream",
}


class Manejador(SimpleHTTPRequestHandler):
    extensions_map = dict(SimpleHTTPRequestHandler.extensions_map)
    extensions_map.update(TIPOS)

    def end_headers(self):
        # Que Safari no reutilice una version vieja del .ipa
        self.send_header("Cache-Control", "no-store")
        SimpleHTTPRequestHandler.end_headers(self)

    def log_message(self, formato, *args):
        sys.stderr.write("  %s - %s\n" % (self.address_string(), formato % args))


def ip_local():
    """IP de este PC dentro de la red local (la que debe usar el iPad)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:  # noqa: BLE001
        return "127.0.0.1"
    finally:
        s.close()


def main():
    analizador = argparse.ArgumentParser(description="Servidor de entrega de iTwitch")
    analizador.add_argument("--puerto", type=int, default=80)
    args = analizador.parse_args()

    raiz = os.path.dirname(os.path.abspath(__file__))
    os.chdir(raiz)

    ipa = os.path.join(raiz, "entrega", "iTwitch.ipa")
    perfil = os.path.join(raiz, "certificados", "CertificadosModernos.mobileconfig")
    for fichero, origen in ((ipa, "dist/iTwitch-1.0.0-full.ipa"),
                            (perfil, "certificados/CertificadosModernos.mobileconfig")):
        if not os.path.isfile(fichero):
            print("  FALTA: %s" % fichero)
            print("  Copialo desde %s" % origen)
            return 1

    ip = ip_local()
    print("")
    print("  iTwitch - servidor de entrega")
    print("  " + "-" * 52)
    print("  Carpeta         %s" % raiz)
    print("  En este PC      http://127.0.0.1:%d/" % args.puerto)
    print("  En el iPad      http://%s:%d/" % (ip, args.puerto))
    print("  " + "-" * 52)
    print("  1. Conecta el iPad a la misma WiFi que este PC.")
    print("  2. Abre Safari y entra en la direccion de arriba.")
    print("  3. Toca PASO 1 (certificados) e instalalo en Ajustes.")
    print("  4. Toca PASO 2 (iTwitch.ipa) y abrelo con Filza.")
    print("  " + "-" * 52)
    print("  Deja esta ventana abierta. Para parar: Ctrl+C")
    print("")

    servidor = ThreadingHTTPServer(("0.0.0.0", args.puerto), Manejador)
    servidor.daemon_threads = True
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\n  Servidor detenido.")
        servidor.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
