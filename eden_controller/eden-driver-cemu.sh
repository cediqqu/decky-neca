#!/usr/bin/env bash
# =============================================================================
#  eden-driver-cemu.sh  --  Cemu (Wii U)
# =============================================================================
#  Cemu guarda cada mando en controllerProfiles/controllerN.xml:
#
#     <emulated_controller>
#         <type>Wii U Pro Controller</type>      <- lo que ve el juego
#         <profile>Deck-P2</profile>             <- etiqueta
#         <controller>                           <- UN dispositivo
#             <api>SDLController</api>
#             <uuid>0_0300b836de280000ff11000001000000</uuid>
#             <display_name>DualSense Wireless Controller 1</display_name>
#             ...mappings...
#         </controller>
#     </emulated_controller>
#
#  El uuid es "<n-esimo mando con ese guid>_<guid>", igual que el Player de
#  Eden, pero el guid lleva el CRC REAL (Eden lo pone a cero). Por eso este
#  driver llama al ayudante con SDL_FUENTE=sistema y SDL_GUID_MODO=cemu.
#
#  Solo se cambia el DISPOSITIVO de cada mando: el <type>, el <profile> y los
#  bindings se conservan. Las ranuras que sobran quedan en "Disconnected".
#
#  Uso (normalmente a traves del despachador):
#     eden-autoconfig.sh --sistema wiiu
#     eden-autoconfig.sh --sistema wiiu --dry-run
#     eden-autoconfig.sh --sistema wiiu --status
#     eden-autoconfig.sh --sistema wiiu --diagnostico
#     eden-autoconfig.sh --sistema wiiu --restore [latest|stock|N]
#
#  Codigos de salida: 0 ok | 1 error | 2 nada que hacer | 3 Cemu abierto |
#                     4 no encuentro la configuracion
# =============================================================================

set -u

CEMU_DIRS=(
    "$HOME/.config/Cemu"
    "$HOME/.config/cemu"
    "$HOME/.local/share/Cemu"
    "$HOME/.var/app/info.cemu.Cemu/data/Cemu"
)

QUIET=0
c_say()  { [ "$QUIET" = "1" ] && return 0; printf '%s\n' "$*"; }
c_warn() { printf 'AVISO: %s\n' "$*" >&2; }
c_err()  { printf 'ERROR: %s\n' "$*" >&2; }

# ------------------------------------------------------------------ rutas ---
c_dir() {
    local d
    if [ -n "${CEMU_DIR:-}" ] && [ -d "$CEMU_DIR/controllerProfiles" ]; then
        printf '%s' "$CEMU_DIR"
        return 0
    fi
    # 1) la que tenga ya perfiles de mando
    for d in "${CEMU_DIRS[@]}"; do
        [ -f "$d/controllerProfiles/controller0.xml" ] && { printf '%s' "$d"; return 0; }
    done
    # 2) la que tenga settings.xml (Cemu la usa aunque no haya mandos)
    for d in "${CEMU_DIRS[@]}"; do
        [ -f "$d/settings.xml" ] && { printf '%s' "$d"; return 0; }
    done
    # 3) cualquiera con controllerProfiles
    for d in "${CEMU_DIRS[@]}"; do
        [ -d "$d/controllerProfiles" ] && { printf '%s' "$d"; return 0; }
    done
    # 4) busqueda (por si EmuDeck la tiene en la tarjeta)
    d="$(find "$HOME" -maxdepth 7 -type d -name controllerProfiles 2>/dev/null | head -n 1)"
    if [ -n "$d" ]; then
        dirname -- "$d"
        return 0
    fi
    return 1
}

c_perfiles() { printf '%s/controllerProfiles' "$1"; }
c_backups()  { printf '%s/cemu' "$(nucleo_base)/backups"; }
# Copia fija del estado anterior a N.E.C.A (la primera vez que se aplica).
c_stock()    { printf '%s/stock' "$(c_backups)"; }

c_en_ejecucion() {
    pgrep -fa . 2>/dev/null \
        | grep -iE 'cemu' \
        | grep -Ev 'eden-autoconfig|eden-driver|eden-nucleo|eden-mandos|pgrep|grep ' \
        >/dev/null
}

# ---------------------------------------------------------------- mandos ----
# La lista y el plan los pone el nucleo (igual que Eden/Dolphin).
c_planificar() { nucleo_planificar cemu; }

# -------------------------------------------------------------- plantilla ---
# Para el jugador N: Deck-PN.xml -> fichero actual -> controllerTemplates/pro.xml
# -> plantilla que viaja con el plugin.
c_plantilla() { # $1 = jugador (1..), $2 = dir de perfiles, $3 = fichero actual
    local n="$1" dir="$2" actual="$3" f
    for f in "$dir/Deck-P$n.xml" "$actual" "$dir/controllerTemplates/pro.xml" \
             "${AQUI:-.}/eden-plantilla-cemu.xml" \
             "$(nucleo_base)/eden-plantilla-cemu.xml"; do
        [ -n "$f" ] && [ -f "$f" ] || continue
        grep -q '<api>SDLController</api>' "$f" 2>/dev/null || continue
        printf '%s' "$f"
        return 0
    done
    return 1
}

# ---------------------------------------------------------------- parche ----
# Escribe en stdout el XML resultante. Codigos: 0 ok, 1 error.
c_python() {
    local base="$1" uuid="$2" nombre="$3" plantilla="$4" accion="$5" perfil="$6" nuevo="$7"
    python3 - "$base" "$uuid" "$nombre" "$plantilla" "$accion" "$perfil" "$nuevo" <<'PYEOF'
import re
import sys
import xml.etree.ElementTree as ET

base, uuid, nombre, plantilla, accion, perfil, nuevo = sys.argv[1:8]
nuevo = (nuevo == "1")

def leer(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()

texto = leer(base)
lineas = texto.splitlines(keepends=True)
if lineas and not lineas[-1].endswith("\n"):
    lineas[-1] += "\n"

RE_CTRL = re.compile(r'^(\s*)<controller>\s*$')
RE_END = re.compile(r'^(\s*)</controller>\s*$')
RE_API = re.compile(r'<api>\s*(.*?)\s*</api>')

def bloques(lines):
    res, ini = [], None
    for i, l in enumerate(lines):
        if ini is None and RE_CTRL.match(l):
            ini = i
        elif ini is not None and RE_END.match(l):
            res.append((ini, i))
            ini = None
    return res

def api(blk):
    for l in blk:
        m = RE_API.search(l)
        if m:
            return m.group(1)
    return ""

def pon_tag(blk, tag, valor):
    pat = re.compile(r'^(\s*)<%s>.*</%s>\s*$' % (tag, tag))
    for i, l in enumerate(blk):
        m = pat.match(l)
        if m:
            blk[i] = "%s<%s>%s</%s>\n" % (m.group(1), tag, valor, tag)
            return
    # no estaba: se inserta tras <api> (misma sangria)
    for i, l in enumerate(blk):
        m = RE_API.search(l)
        if m:
            sangria = re.match(r'^(\s*)', l).group(1)
            blk.insert(i + 1, "%s<%s>%s</%s>\n" % (sangria, tag, valor, tag))
            return
    raise SystemExit("ERROR: no encuentro <api> en el bloque")

def con_uuid(blk, u, n):
    blk = list(blk)
    pon_tag(blk, "uuid", u)
    pon_tag(blk, "display_name", n)
    return blk

def n_mappings(blk):
    return sum(1 for l in blk if "<mapping>" in l)

def bloque_sdl(lines):
    for (i, f) in bloques(lines):
        if api(lines[i:f + 1]) == "SDLController":
            return (i, f)
    return None

# --- bloque de la plantilla (para ranuras vacias / ficheros nuevos) ---------
blk_plantilla = None
if plantilla:
    try:
        pl = leer(plantilla).splitlines(keepends=True)
        b = bloque_sdl(pl)
        if b:
            blk_plantilla = pl[b[0]:b[1] + 1]
    except OSError:
        blk_plantilla = None

# --- editar ----------------------------------------------------------------
if accion == "vacio":
    b = bloque_sdl(lineas)
    if not b:
        sys.stdout.write("".join(lineas))
        sys.exit(0)
    i, f = b
    lineas[i:f + 1] = con_uuid(lineas[i:f + 1],
                               "0_" + "0" * 32, "Disconnected")
else:
    b = bloque_sdl(lineas)
    if b and n_mappings(lineas[b[0]:b[1] + 1]) >= 10:
        # ya tiene bindings: se respetan, solo se cambia el dispositivo
        i, f = b
        lineas[i:f + 1] = con_uuid(lineas[i:f + 1], uuid, nombre)
        # sobrantes: cualquier otro bloque SDL se elimina
        for (i2, f2) in sorted(bloques(lineas), key=lambda x: -x[0]):
            if i2 == i:
                continue
            blk = lineas[i2:f2 + 1]
            if api(blk) == "SDLController":
                del lineas[i2:f2 + 1]
    else:
        if blk_plantilla is None:
            raise SystemExit("ERROR: no hay bindings ni plantilla para el SDL")
        nuevo_blk = con_uuid(blk_plantilla, uuid, nombre)
        if b:
            i, f = b
            lineas[i:f + 1] = nuevo_blk
            for (i2, f2) in sorted(bloques(lineas), key=lambda x: -x[0]):
                if i2 == i:
                    continue
                blk = lineas[i2:f2 + 1]
                if api(blk) == "SDLController":
                    del lineas[i2:f2 + 1]
        else:
            idx = None
            for i, l in enumerate(lineas):
                if re.match(r'^\s*</emulated_controller>\s*$', l):
                    idx = i
                    break
            if idx is None:
                raise SystemExit("ERROR: el XML no tiene </emulated_controller>")
            lineas[idx:idx] = nuevo_blk

if nuevo:
    pat = re.compile(r'^(\s*)<profile>.*</profile>\s*$')
    puesto = False
    for i, l in enumerate(lineas):
        m = pat.match(l)
        if m:
            lineas[i] = "%s<profile>%s</profile>\n" % (m.group(1), perfil)
            puesto = True
            break
    if not puesto:
        for i, l in enumerate(lineas):
            if re.match(r'^\s*<type>.*</type>\s*$', l):
                sangria = re.match(r'^(\s*)', l).group(1)
                lineas.insert(i + 1, "%s<profile>%s</profile>\n" % (sangria, perfil))
                break

salida = "".join(lineas)

# --- validar ---------------------------------------------------------------
try:
    raiz = ET.fromstring(salida)
except ET.ParseError as e:
    raise SystemExit("ERROR: el XML resultante no es valido: %s" % e)

if raiz.tag != "emulated_controller":
    raise SystemExit("ERROR: la raiz no es <emulated_controller>")

sl = salida.splitlines(keepends=True)
b = bloque_sdl(sl)
if not b:
    raise SystemExit("ERROR: el resultado no tiene ningun dispositivo SDL")
n_sdl = sum(1 for (i, f) in bloques(sl) if api(sl[i:f + 1]) == "SDLController")
if n_sdl != 1:
    raise SystemExit("ERROR: quedan %d dispositivos SDL (debe haber 1)" % n_sdl)

if accion != "vacio":
    valores = dict(re.findall(r'<(\w+)>\s*(.*?)\s*</\1>', "".join(sl[b[0]:b[1] + 1])))
    if valores.get("uuid") != uuid:
        raise SystemExit("ERROR: el uuid escrito no coincide")

sys.stdout.write(salida)
PYEOF
}

# Escribe una ranura: backup + parche + validacion + escritura atomica.
c_escribir() { # $1 jugador, $2 fichero, $3 uuid, $4 nombre, $5 accion, $6 dir
    local n="$1" fichero="$2" uuid="$3" nombre="$4" accion="$5" dir="$6"
    local plantilla base tmp bk stamp nuevo=0

    if [ -f "$fichero" ]; then
        base="$fichero"
    else
        plantilla="$(c_plantilla "$n" "$dir" "$fichero")" || {
            c_err "no encuentro plantilla para el mando $n"
            return 1
        }
        base="$plantilla"
        nuevo=1
    fi
    plantilla="$(c_plantilla "$n" "$dir" "$fichero" 2>/dev/null || true)"

    tmp="$fichero.tmp.$$"
    if ! c_python "$base" "$uuid" "$nombre" "${plantilla:-}" "$accion" "Deck-P$n" "$nuevo" >"$tmp"; then
        rm -f "$tmp"
        c_err "no pude preparar $fichero"
        return 1
    fi

    # backup del original (si existe)
    bk="$(c_backups)"
    if [ -f "$fichero" ]; then
        local stock
        stock="$(c_stock)"
        mkdir -p "$bk" "$stock" \
            || { rm -f "$tmp"; c_err "no puedo crear $bk"; return 1; }
        stamp="$(date +%Y%m%d-%H%M%S)"
        cp -p "$fichero" "$bk/$(basename "$fichero").$stamp" || {
            rm -f "$tmp"; c_err "no puedo hacer backup de $fichero"; return 1
        }
        [ -f "$stock/$(basename "$fichero")" ] \
            || cp -p "$fichero" "$stock/$(basename "$fichero")" || {
                rm -f "$tmp"; c_err "no puedo guardar el original de $fichero"; return 1
            }
    fi

    chmod --reference="$base" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$fichero" || { rm -f "$tmp"; c_err "no puedo escribir $fichero"; return 1; }
    return 0
}

# Retencion de backups (por fichero)
c_retencion() {
    local bk ret f base clave
    bk="$(c_backups)"
    ret="${RETENCION_BACKUPS:-10}"
    [ -d "$bk" ] || return 0
    [ "$ret" -gt 0 ] 2>/dev/null || return 0
    for f in "$bk"/controller*.xml; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        # nombre sin la marca de tiempo final
        clave="${base%.*}"
        ls -1t "$bk/$clave".* 2>/dev/null | tail -n +$((ret + 1)) | while read -r viejo; do
            rm -f "$viejo"
        done
    done
}

# --------------------------------------------------------------- acciones ---
c_cmd_status() {
    local dir
    dir="$(c_dir)" || { c_err "no encuentro la configuracion de Cemu"; return 4; }
    c_say "Cemu               : $dir"
    c_say "perfiles           : $(c_perfiles "$dir")"
    c_say "en ejecucion       : $(c_en_ejecucion && echo SI || echo no)"
    c_planificar || true
    nucleo_imprimir_plan
    local f
    for f in "$(c_perfiles "$dir")"/controller[0-9]*.xml; do
        [ -f "$f" ] || continue
        c_say "--- $(basename "$f")"
        grep -E '<type>|<profile>|<uuid>|<display_name>' "$f" | sed 's/^[[:space:]]*/  /'
    done
    return 0
}

c_cmd_diagnostico() {
    c_say "carpetas de Cemu:"
    local d p
    for d in "${CEMU_DIRS[@]}"; do
        if [ -d "$d" ]; then
            c_say "  [SI] $d"
            [ -f "$d/settings.xml" ] && c_say "       settings.xml $(date -r "$d/settings.xml" '+%Y-%m-%d %H:%M' 2>/dev/null)"
            if [ -d "$d/controllerProfiles" ]; then
                c_say "       controllerProfiles/ $(ls -1 "$d/controllerProfiles" 2>/dev/null | tr '\n' ' ')"
            fi
        else
            c_say "  [no] $d"
        fi
    done
    d="$(c_dir)" && c_say "elegida            : $d"
    c_say "Cemu en ejecucion  : $(c_en_ejecucion && echo SI || echo no)"
    if c_planificar; then
        c_say "plan:"
        local i
        for i in "${!PLAN_UUID[@]}"; do
            c_say "  Mando $((i + 1)) = ${PLAN_NOMBRE[$i]}  ->  ${PLAN_UUID[$i]}"
        done
    else
        c_say "plan               : ninguno (¿Cemu abierto? ¿mandos apagados?)"
    fi
    return 0
}

c_cmd_dryrun() {
    local dir
    dir="$(c_dir)" || { c_err "no encuentro la configuracion de Cemu"; return 4; }
    c_planificar || {
        nucleo_imprimir_plan
        nucleo_guardar_plan wiiu dry-run
        return 2
    }
    c_say "Cemu: $dir"
    nucleo_imprimir_plan
    local i n f
    for i in "${!PLAN_UUID[@]}"; do
        n=$((i + 1))
        f="$(c_perfiles "$dir")/controller$i.xml"
        c_say "  Mando $n  ($(basename "$f"))"
        c_say "    uuid         = ${PLAN_UUID[$i]}"
        c_say "    display_name = ${PLAN_SDL[$i]}"
    done
    for n in $(seq $(( ${#PLAN_UUID[@]} + 1 )) 8); do
        f="$(c_perfiles "$dir")/controller$((n - 1)).xml"
        [ -f "$f" ] && c_say "  Mando $n  ($(basename "$f")) -> a Disconnected"
    done
    c_say "(dry-run: no se ha escrito nada)"
    nucleo_guardar_plan wiiu dry-run
    nucleo_registrar wiiu dry-run
    return 0
}

c_cmd_aplicar() {
    local dir
    dir="$(c_dir)" || { c_err "no encuentro la configuracion de Cemu"; return 4; }

    if c_en_ejecucion; then
        c_err "Cemu esta en ejecucion. Cierralo y vuelve a intentarlo."
        return 3
    fi

    c_planificar || {
        [ "$QUIET" = "1" ] || nucleo_imprimir_plan
        nucleo_guardar_plan wiiu aplicar
        nucleo_registrar wiiu aplicar
        c_warn "no hay mandos que asignar: dejo la configuracion como estaba"
        return 2
    }

    local i n f
    for i in "${!PLAN_UUID[@]}"; do
        n=$((i + 1))
        f="$(c_perfiles "$dir")/controller$i.xml"
        c_escribir "$n" "$f" "${PLAN_UUID[$i]}" "${PLAN_SDL[$i]}" poner "$dir" \
            || return 1
        c_say "Mando $n -> ${PLAN_SDL[$i]}"
    done

    # ranuras sobrantes -> Disconnected (no se borran ficheros)
    for n in $(seq $(( ${#PLAN_UUID[@]} + 1 )) 8); do
        f="$(c_perfiles "$dir")/controller$((n - 1)).xml"
        [ -f "$f" ] || continue
        c_escribir "$n" "$f" "0_$(printf '%032d' 0)" "Disconnected" vacio "$dir" \
            && c_say "Mando $n -> Disconnected"
    done

    c_retencion
    nucleo_guardar_plan wiiu aplicar
    nucleo_registrar wiiu aplicar
    return 0
}

c_cmd_restore() {
    local cual="${1:-latest}" bk stock origen dir
    bk="$(c_backups)"
    stock="$(c_stock)"
    [ -d "$bk" ] || { c_err "no hay copias de Cemu"; return 1; }
    dir="$(c_dir)" || { c_err "no encuentro la configuracion de Cemu"; return 4; }

    local nombres
    nombres="$(ls -1 "$bk" 2>/dev/null | sed -n 's/^\(controller[0-9]*\.xml\)\..*/\1/p' | sort -u)"
    [ -n "$nombres" ] || nombres="$(ls -1 "$stock" 2>/dev/null | sed -n 's/^\(controller[0-9]*\.xml\)$/\1/p' | sort -u)"
    [ -n "$nombres" ] || { c_err "no hay copias de Cemu"; return 1; }
    local nombre
    for nombre in $nombres; do
        if [ "$cual" = "stock" ] || [ "$cual" = "original" ]; then
            # estado anterior a N.E.C.A; si no hay copia fija, la mas antigua
            origen="$stock/$nombre"
            [ -f "$origen" ] || origen="$(ls -1t "$bk/$nombre".* 2>/dev/null | tail -n 1)"
        elif [ "$cual" = "latest" ]; then
            origen="$(ls -1t "$bk/$nombre".* 2>/dev/null | head -n 1)"
        else
            origen="$(ls -1t "$bk/$nombre".* 2>/dev/null | sed -n "${cual}p")"
        fi
        if [ -z "${origen:-}" ] || [ ! -f "$origen" ]; then
            c_warn "no hay copia de $nombre"
            continue
        fi
        cp -f "$origen" "$(c_perfiles "$dir")/$nombre" \
            && c_say "restaurado $nombre <- $(basename "$origen")"
    done
    return 0
}

# ------------------------------------------------------------------- CLI ----
c_usage() {
    cat <<EOF
driver Cemu (Wii U)

USO
  eden-autoconfig.sh --sistema wiiu                aplica
  eden-autoconfig.sh --sistema wiiu --dry-run      enseña el plan, sin escribir
  eden-autoconfig.sh --sistema wiiu --status       estado y dispositivos actuales
  eden-autoconfig.sh --sistema wiiu --diagnostico  carpetas y ficheros de Cemu
  eden-autoconfig.sh --sistema wiiu --restore [latest|stock|N]
  eden-autoconfig.sh --sistema wiiu --help

Opcional en ~/eden-autoconfig/eden-autoconfig.conf:
  CEMU_DIR=/ruta/a/Cemu     (si la deteccion automatica no acierta)
EOF
}

main() {
    local modo="aplicar" restore_arg="latest"
    while [ $# -gt 0 ]; do
        case "$1" in
            --status)   modo="status" ;;
            --dry-run|--dryrun) modo="dryrun" ;;
            --diagnostico|--diagnostic) modo="diagnostico" ;;
            --restore)
                modo="restore"
                case "${2:-}" in
                    ''|--*) : ;;
                    *) restore_arg="$2"; shift ;;
                esac
                ;;
            --help|-h) c_usage; return 0 ;;
            --quiet|-q) QUIET=1 ;;
            --verbose|-v) : ;;
            *)
                c_err "opcion no reconocida: $1"
                c_usage >&2
                return 1
                ;;
        esac
        shift
    done

    case "$modo" in
        status)      c_cmd_status ;;
        dryrun)      c_cmd_dryrun ;;
        diagnostico) c_cmd_diagnostico ;;
        restore)     c_cmd_restore "$restore_arg" ;;
        *)           c_cmd_aplicar ;;
    esac
}
