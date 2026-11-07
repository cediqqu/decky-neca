#!/usr/bin/env bash
# =============================================================================
#  build.sh -- sincroniza los scripts y genera el zip instalable del plugin
# =============================================================================
#  Uso:   bash build.sh
#         EDEN_SCRIPTS_DIR=/otra/ruta bash build.sh     (origen de los scripts)
#         SCRIPTS_VERSION=1.2.0 bash build.sh
#
#  Lo que hace:
#    1. Copia los scripts de Nintendo-EmuDeck Controller Autoconf (proyecto eden_controller) a
#       scripts/  -- NUNCA se editan aqui: esta carpeta es solo una copia
#       generada. La fuente de verdad sigue siendo ./eden_controller.
#    2. Escribe scripts/VERSION (version + hash + fecha) para que el panel
#       pueda avisar si lo instalado esta desactualizado.
#    3. Compila el frontend (rollup -> dist/index.js).
#    4. Genera neca-decky.zip listo para Decky > Developer.
#
#  Si falta ./eden_controller, se salta el paso 1 y usa la
#  copia ya incluida en el repo (asi funciona tambien en GitHub Actions).
# =============================================================================

set -u

AQUI="$(cd -- "$(dirname -- "$0")" && pwd -P)"
ORIGEN="${EDEN_SCRIPTS_DIR:-$AQUI/eden_controller}"
DEST="$AQUI/scripts"
ZIP="$AQUI/neca-decky.zip"
VERSION_SCRIPTS="${SCRIPTS_VERSION:-2.0.0}"

NOMBRE_ZIP="neca-decky.zip"

say() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

FICHEROS=(
    eden-autoconfig.sh
    eden-nucleo.sh
    eden-driver-yuzu.sh
    eden-driver-cemu.sh
    eden-plantilla-cemu.xml
    eden-mandos-sdl.sh
    eden-diagnostico.sh
    eden-autoconfig.conf.example
    instalar.sh
)

# --- 1) sincronizar scripts --------------------------------------------------
say "== 1) scripts"
if [ -d "$ORIGEN" ]; then
    faltan=0
    for f in "${FICHEROS[@]}" es-de-hooks/10-eden-autoconfig.sh; do
        [ -r "$ORIGEN/$f" ] || { err "falta $ORIGEN/$f"; faltan=1; }
    done
    if [ "$faltan" -ne 0 ]; then
        err "el proyecto de scripts esta incompleto en $ORIGEN"
        exit 1
    fi

    mkdir -p "$DEST/es-de-hooks"
    for f in "${FICHEROS[@]}"; do
        cp -f "$ORIGEN/$f" "$DEST/$f"
    done
    cp -f "$ORIGEN/es-de-hooks/10-eden-autoconfig.sh" "$DEST/es-de-hooks/"

    chmod 755 "$DEST"/*.sh "$DEST/es-de-hooks"/*.sh 2>/dev/null
    chmod 644 "$DEST/eden-autoconfig.conf.example" 2>/dev/null

    # hash informativo de TODO lo que se instala (los .sh + la plantilla)
    HASH="$(for f in "${FICHEROS[@]}"; do cat "$DEST/$f" 2>/dev/null; done \
            | sha256sum | cut -c1-12)"
    {
        printf 'version: %s\n' "$VERSION_SCRIPTS"
        printf 'hash: %s\n' "$HASH"
        printf 'origen: %s\n' "$(cd -- "$ORIGEN" && pwd -P)"
    } >"$DEST/VERSION"

    say "   copiados desde $ORIGEN"
    say "   version $VERSION_SCRIPTS  hash $HASH"
else
    if [ -f "$DEST/VERSION" ]; then
        say "   no encuentro $ORIGEN: uso la copia incluida en scripts/"
        sed 's/^/   /' "$DEST/VERSION"
    else
        err "no encuentro $ORIGEN ni una copia en scripts/"
        err "pon el proyecto eden_controller al lado o ejecuta con EDEN_SCRIPTS_DIR=..."
        exit 1
    fi
fi

# --- 2) compilar el frontend -------------------------------------------------
say ""
say "== 2) frontend"
if [ ! -d "$AQUI/node_modules" ]; then
    say "   instalando dependencias (npm install)..."
    ( cd -- "$AQUI" && npm install --no-audit --no-fund ) || {
        err "npm install ha fallado"
        exit 1
    }
fi
( cd -- "$AQUI" && npm run build ) || { err "la compilacion ha fallado"; exit 1; }
[ -f "$AQUI/dist/index.js" ] || { err "no se ha generado dist/index.js"; exit 1; }
say "   dist/index.js listo"

# --- 3) zip ------------------------------------------------------------------
say ""
say "== 3) zip"
rm -f "$ZIP"
python3 - "$AQUI" "$ZIP" <<'PY' || exit 1
import os
import sys
import zipfile

base, salida = sys.argv[1], sys.argv[2]
suelto = ["plugin.json", "package.json", "main.py", "LICENSE", "README.md",
          "dist/index.js"]

ficheros = []
for f in suelto:
    ruta = os.path.join(base, f)
    if not os.path.isfile(ruta):
        sys.exit("ERROR: falta %s (no puedo hacer el zip)" % f)
    ficheros.append(f)

for raiz, _dirs, nombres in os.walk(os.path.join(base, "scripts")):
    for n in nombres:
        if n.endswith(".pyc"):
            continue
        ficheros.append(os.path.relpath(os.path.join(raiz, n), base))

with zipfile.ZipFile(salida, "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(set(ficheros)):
        # OJO: el loader hace extractall() directamente en ~/homebrew/plugins,
        # asi que todo el contenido debe ir dentro de UNA carpeta raiz.
        z.write(os.path.join(base, f), "NecaAutoconfig/" + f)

print("   %s (%d ficheros, %.1f KB)" % (
    os.path.basename(salida), len(ficheros),
    os.path.getsize(salida) / 1024.0))
PY

say ""
say "Listo: $ZIP"
say "Instalalo en la consola con: Decky > Developer > Install Plugin from ZIP"
