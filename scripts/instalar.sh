#!/usr/bin/env bash
# =============================================================================
#  instalar.sh  --  copia los scripts a $HOME y deja los permisos bien
# =============================================================================
#  No borra nada y no toca nada que ya exista sin avisar.
#  Uso:   bash instalar.sh            (instala/actualiza)
#         bash instalar.sh --dry-run  (solo dice lo que haria)
#
#  Instala:
#     ~/eden-autoconfig/eden-autoconfig.sh          (+x)
#     ~/eden-autoconfig/eden-autoconfig.conf        (solo si no existe)
#     ~/eden-autoconfig/eden-diagnostico.sh         (+x)
#     ~/eden-autoconfig/{templates,backups}/
#     ~/ES-DE/scripts/game-start/10-eden-autoconfig.sh  (+x)
# =============================================================================

set -u
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

AQUI="$(cd -- "$(dirname -- "$0")" && pwd -P)"

DEST_CFG="$HOME/eden-autoconfig"
DEST_HOOK="$HOME/ES-DE/scripts/game-start"

say() { printf '%s\n' "$*"; }
haz()  { if [ "$DRY" -eq 1 ]; then say "[dry-run] $*"; else eval "$@"; fi; }

say "origen: $AQUI"
say ""

# --- comprobaciones de origen ------------------------------------------------
faltan=0
for f in eden-autoconfig.sh eden-nucleo.sh eden-driver-yuzu.sh \
         eden-driver-cemu.sh eden-plantilla-cemu.xml \
         eden-diagnostico.sh eden-mandos-sdl.sh \
         eden-autoconfig.conf.example es-de-hooks/10-eden-autoconfig.sh; do
    if [ ! -r "$AQUI/$f" ]; then say "FALTA: $AQUI/$f"; faltan=1; fi
done
[ "$faltan" -eq 0 ] || { say "ejecuta esto desde la carpeta del proyecto"; exit 1; }

# El ayudante tiene que ser la version que busca la libSDL3 de Eden dentro de su
# namespace (si es una copia antigua, la copia de la lib fallara siempre).
if ! grep -q 'raices_de_pid' "$AQUI/eden-mandos-sdl.sh" 2>/dev/null; then
    say ""
    say "ERROR: $AQUI/eden-mandos-sdl.sh es una version ANTIGUA."
    say "       Copia la carpeta actualizada del proyecto y vuelve a ejecutar esto."
    exit 1
fi

# --- 1) carpeta de trabajo ---------------------------------------------------
say "1) $DEST_CFG"
haz "mkdir -p '$DEST_CFG' '$DEST_CFG/templates' '$DEST_CFG/backups'"
haz "cp -f '$AQUI/eden-autoconfig.sh' '$DEST_CFG/eden-autoconfig.sh'"
haz "cp -f '$AQUI/eden-nucleo.sh' '$DEST_CFG/eden-nucleo.sh'"
haz "cp -f '$AQUI/eden-driver-yuzu.sh' '$DEST_CFG/eden-driver-yuzu.sh'"
haz "cp -f '$AQUI/eden-driver-cemu.sh' '$DEST_CFG/eden-driver-cemu.sh'"
haz "cp -f '$AQUI/eden-plantilla-cemu.xml' '$DEST_CFG/eden-plantilla-cemu.xml'"
[ -f "$AQUI/VERSION" ] && haz "cp -f '$AQUI/VERSION' '$DEST_CFG/VERSION'"
haz "cp -f '$AQUI/eden-diagnostico.sh' '$DEST_CFG/eden-diagnostico.sh'"
haz "cp -f '$AQUI/eden-mandos-sdl.sh' '$DEST_CFG/eden-mandos-sdl.sh'"
haz "chmod 755 '$DEST_CFG/eden-autoconfig.sh' '$DEST_CFG/eden-nucleo.sh' '$DEST_CFG/eden-driver-yuzu.sh' '$DEST_CFG/eden-driver-cemu.sh' '$DEST_CFG/eden-diagnostico.sh' '$DEST_CFG/eden-mandos-sdl.sh'"

if [ -e "$DEST_CFG/eden-autoconfig.conf" ]; then
    say "   (ya existe $DEST_CFG/eden-autoconfig.conf: no lo toco)"
else
    haz "cp -f '$AQUI/eden-autoconfig.conf.example' '$DEST_CFG/eden-autoconfig.conf'"
    say "   conf creado desde el ejemplo (revísalo si quieres cambiar reglas)"
fi

# --- 2) hook de ES-DE --------------------------------------------------------
say "2) $DEST_HOOK/10-eden-autoconfig.sh"
if [ -d "$HOME/ES-DE" ]; then
    haz "mkdir -p '$DEST_HOOK'"
    haz "cp -f '$AQUI/es-de-hooks/10-eden-autoconfig.sh' '$DEST_HOOK/10-eden-autoconfig.sh'"
    haz "chmod 755 '$DEST_HOOK/10-eden-autoconfig.sh'"
else
    say "   NO existe ~/ES-DE: copia el hook a mano cuando lo tengas"
    say "   (fichero origen: $AQUI/es-de-hooks/10-eden-autoconfig.sh)"
fi

# --- 3) preparar la deteccion por SDL (extrae libSDL3 del AppImage, una vez) --
say "3) deteccion de mandos por SDL"
if [ "$DRY" -eq 1 ]; then
    say "   [dry-run] bash $DEST_CFG/eden-mandos-sdl.sh"
else
    # Se usa la SDL del sistema normalizando el CRC del GUID a 0, que es como lo
    # calcula la SDL que lleva Eden dentro (comprobado con sus guids reales).
    if out="$(bash "$DEST_CFG/eden-mandos-sdl.sh" 2>&1)"; then
        n="$(printf '%s\n' "$out" | grep -c '^[^#].*|' || true)"
        lib="$(printf '%s\n' "$out" | grep -m1 '^#lib ' | sed 's/^#lib //')"
        say "   OK: SDL responde y ve $n mando(s)."
        say "   libSDL3: ${lib:-?}"
    else
        say "   AVISO: no he podido interrogar a SDL. Detalle:"
        printf '   %s\n' "$out" | head -n 5
        say "   (el script seguira funcionando, pero usando el metodo de respaldo /sys)"
    fi
fi

say ""
say "Listo. Pasos siguientes en la Ally:"
say "  1) bash $DEST_CFG/eden-diagnostico.sh      # y guarda la salida"
say "  2) En Eden: Ajustes > Controles, carga el perfil 'emudeck' en el Player 1"
say "     con un DualSense conectado, pulsa OK y sal. Luego:"
say "        bash $DEST_CFG/eden-autoconfig.sh --save-template dualsense"
say "  3) Repite con el mando integrado (sin DualSense) y:"
say "        bash $DEST_CFG/eden-autoconfig.sh --save-template ally"
say "  4) bash $DEST_CFG/eden-autoconfig.sh --mandos     # lo que ve Eden + puertos"
say "     bash $DEST_CFG/eden-autoconfig.sh --status"
say "     bash $DEST_CFG/eden-autoconfig.sh --dry-run --verbose"
say "  5) En ES-DE: Other settings > Enable custom event scripts  (ACTIVAR)"
