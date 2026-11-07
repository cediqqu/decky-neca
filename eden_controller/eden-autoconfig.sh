#!/usr/bin/env bash
# =============================================================================
#  eden-autoconfig.sh  --  despachador de N.E.C.A (Nintendo-EmuDeck Controller Autoconf)
# =============================================================================
#  Elige el driver segun el sistema del juego y le pasa todos los argumentos.
#
#  Uso:
#     eden-autoconfig.sh [--sistema switch|wiiu] [opciones del driver]
#
#  Sin --sistema se usa "switch" (Eden), asi que el plugin y el hook de ES-DE
#  siguen funcionando igual que antes de existir el despachador.
#
#  Drivers:
#     switch  -> eden-driver-yuzu.sh     (Eden y sus fork: qt-config.ini)
#     wiiu    -> eden-driver-cemu.sh     (controllerN.xml)
# =============================================================================

set -u

AQUI="$(cd -- "$(dirname -- "$0")" && pwd -P)"
SISTEMA="switch"
ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --sistema|--system)
            SISTEMA="${2:-switch}"
            shift 2
            ;;
        --sistema=*|--system=*)
            SISTEMA="${1#*=}"
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

case "${SISTEMA,,}" in
    switch|nsw|yuzu|eden)     DRIVER="yuzu" ;;
    wiiu|cemu|wii-u)          DRIVER="cemu" ;;
    *)
        echo "N.E.C.A: sistema no soportado: $SISTEMA" >&2
        echo "  validos: switch | wiiu" >&2
        exit 1
        ;;
esac

NUCLEO="$AQUI/eden-nucleo.sh"
DRIVER_FILE="$AQUI/eden-driver-$DRIVER.sh"
for f in "$NUCLEO" "$DRIVER_FILE"; do
    if [ ! -r "$f" ]; then
        echo "N.E.C.A: falta $f" >&2
        exit 1
    fi
done

# shellcheck disable=SC1090
. "$NUCLEO"
# shellcheck disable=SC1090
. "$DRIVER_FILE"

main "${ARGS[@]+"${ARGS[@]}"}"
