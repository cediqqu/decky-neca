#!/usr/bin/env bash
# =============================================================================
#  eden-autoconfig.sh  --  Configura automaticamente los mandos de Eden
#                          (fork de Yuzu) segun los DualSense conectados.
# =============================================================================
#
#  QUE HACE
#    Cuenta los mandos conectados y deja <config>/eden/qt-config.ini listo:
#
#      0 DualSense  ->  Player 1 = mando integrado de la Ally (u orden
#                       configurable), resto desconectados.
#      1..4 DualSense -> Player 1..N = DualSense (mapeo clonado del perfil
#                       'emudeck'), resto desconectados.
#
#    El mapeo de cada jugador se clona de una plantilla (por defecto el
#    perfil de Eden llamado 'emudeck', en <config>/input/). Solo se reescriben:
#      - el prefijo   player_0_  ->  player_K_
#      - el puerto    port:0     ->  port:K        (dentro de cada binding)
#      - connected / type
#      - opcionalmente el guid (si GUID_DUALSENSE / GUID_INTEGRADO estan seteados)
#    El resto del archivo NO se toca. Jerarquia de la seccion [Controls] se
#    conserva; las claves de jugador se reemplazan por completo.
#
#  POR QUE NO SE FIJA UN MANDO CONCRETO POR MAC
#    Eden identifica un mando por 'guid' + 'port'. El guid de SDL se construye
#    con bus+vendor+product+version+nombre: NO incluye la MAC ni el serial
#    (verificado en el codigo de SDL y de Eden). Y 'port' es "el n-esimo mando
#    con ese mismo guid", en el orden en que SDL los enumera. Por tanto, dos
#    DualSense identicos comparten guid y solo se distinguen por su orden de
#    conexion. Ver la seccion ORDEN en el README.
#
#  SEGURIDAD
#    - Nunca se ejecuta si Eden esta en marcha.
#    - Copia de seguridad con fecha ANTES de cada cambio (no borra nada).
#    - Escritura atomica + validacion posterior; si algo no cuadra, aborta
#      sin tocar el original.
#    - Solo escribe bajo $HOME.
#
#  USO
#    eden-autoconfig.sh                 # aplica la configuracion
#    eden-autoconfig.sh --status        # que ha detectado y que haria
#    eden-autoconfig.sh --dry-run       # genera y muestra el diff, sin tocar
#    eden-autoconfig.sh --who           # quien sera P1/P2/... (con MACs)
#    eden-autoconfig.sh --save-template dualsense|ally [--from-profile emudeck]
#    eden-autoconfig.sh --restore [latest|N]
#    eden-autoconfig.sh --list-backups
#    eden-autoconfig.sh --help
#
#  CODIGOS DE SALIDA
#    0 ok | 1 error | 2 nada que hacer | 3 Eden en ejecucion
#    4 no se encontro qt-config.ini | 5 no se encontro plantilla
#
# =============================================================================

set -u
set -o pipefail

PROG="${0##*/}"
HERE="$(cd -- "$(dirname -- "$0")" && pwd -P 2>/dev/null || echo "$PWD")"
# version real: la escribe build.sh en scripts/VERSION (y copia instalar.sh)
VERSION="$(sed -n 's/^version:[[:space:]]*//p' "$HERE/VERSION" 2>/dev/null | head -n1)"
[ -n "$VERSION" ] || VERSION="$(sed -n 's/^version:[[:space:]]*//p' "${EDEN_AUTOCONFIG_DIR:-$HOME/eden-autoconfig}/VERSION" 2>/dev/null | head -n1)"
VERSION="${VERSION:-desconocida}"
HASH="$(sed -n 's/^hash:[[:space:]]*//p' "$HERE/VERSION" 2>/dev/null | head -n1)"
[ -n "$HASH" ] || HASH="$(sed -n 's/^hash:[[:space:]]*//p' "${EDEN_AUTOCONFIG_DIR:-$HOME/eden-autoconfig}/VERSION" 2>/dev/null | head -n1)"
HASH="${HASH:-?}"

# --------------------------------------------------------------- rutas base
BASE_DIR="${EDEN_AUTOCONFIG_DIR:-$HOME/eden-autoconfig}"
LOG_FILE="$BASE_DIR/log.txt"
TPL_DIR="$BASE_DIR/templates"
BK_DIR="$BASE_DIR/backups"
CONF_FILE="${EDEN_AUTOCONFIG_CONF:-$BASE_DIR/eden-autoconfig.conf}"

# ------------------------------------------------------- valores por defecto
# (se pueden sobreescribir en $BASE_DIR/eden-autoconfig.conf y, algunos, por CLI)

EDEN_CONFIG="${EDEN_CONFIG:-}"           # ruta explicita a qt-config.ini (opcional)
EDEN_APPIMAGE="${EDEN_APPIMAGE:-}"       # ruta explicita al AppImage de Eden (opcional)

PERFIL="${PERFIL:-emudeck}"              # nombre del perfil de Eden a clonar
USAR_PERFIL="${USAR_PERFIL:-auto}"       # auto|si|no  (auto: usar plantilla guardada si existe, si no el perfil)
JUGADORES_MAX="${JUGADORES_MAX:-4}"      # numero maximo de DualSense a asignar (1..4)
ORDEN_INTEGRADO="${ORDEN_INTEGRADO:-primero}"   # ignorar | primero | ultimo
TIPO_CONTROLADOR="${TIPO_CONTROLADOR:-0}"       # 0 = Pro Controller (valor de player_N_type)

GUID_DUALSENSE="${GUID_DUALSENSE:-}"     # si no esta vacio, se fuerza ese guid en los jugadores DualSense
GUID_INTEGRADO="${GUID_INTEGRADO:-}"     # si no esta vacio, se fuerza ese guid en el jugador integrado

INTEGRADO_PATRON="${INTEGRADO_PATRON:-*ROG*|*Ally*|*ASUS*|*Asus*|*hid-asus*}"
DUALSENSE_PATRON="${DUALSENSE_PATRON:-*DualSense*|*DualShock*}"
IGNORAR_PATRON="${IGNORAR_PATRON:-*Touchpad*|*Motion Sensors*|*Consumer Control*|*Keyboard*|*Mouse*|*Video Bus*|*Power Button*|*Sleep Button*|*PC Speaker*|*HD-Audio*|*Lid Switch*|*Sensors*}"

EXIGIR_P1_MAC="${EXIGIR_P1_MAC:-}"       # si no esta vacio: MAC que deberia ser P1; si no coincide, avisa fuerte
AVISAR_SIN_NEGOCIAR="${AVISAR_SIN_NEGOCIAR:-0}"  # 1 = si EXIGIR_P1_MAC no coincide, NO aplicar

EDEN_PROCESOS_PATRON="${EDEN_PROCESOS_PATRON:-\.mount_[^/]*[Ee]den|[Ee]den[-_A-Za-z0-9.]*\.AppImage|/[Ee]den([[:space:]]|$)|AppRun.*[Ee]den}"

RETENCION_BACKUPS="${RETENCION_BACKUPS:-0}"   # 0 = no borrar nunca copias antiguas

# ------------------------------------------------------------------ (testing)
# Permiten simular la deteccion para probar el script sin los mandos reales.
EDEN_FAKE_INPUT_DEVICES="${EDEN_FAKE_INPUT_DEVICES:-}"   # fichero con "NOMBRE|UNIQ|VENDOR|PRODUCT|EVENT|SYSFS" por linea
EDEN_FAKE_BT="${EDEN_FAKE_BT:-}"                         # fichero con "MAC|NOMBRE" por linea

# ----------------------------------------------------------- estado interno
QUIET=0
VERBOSE=0
DRY_RUN=0
FORCE=0
MODO="aplicar"        # aplicar | status | dryrun | who | save-template | restore | list-backups | help
ASUMIR_INTEGRADO=0    # solo --who: mostrar el integrado aunque SDL no lo exponga
TMPDIR_RUN=""

# =============================================================================
#  UTILIDADES
# =============================================================================

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn() { printf 'AVISO: %s\n' "$*" >&2; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }

preparar_dirs() {
    mkdir -p "$BASE_DIR" "$TPL_DIR" "$BK_DIR" 2>/dev/null || {
        err "no puedo crear $BASE_DIR (¿permisos?)"; exit 1; }
    [ -w "$BASE_DIR" ] || { err "$BASE_DIR no es escribible"; exit 1; }
}

LOG_QUIET=0
log() { # log NIVEL mensaje...
    [ "$LOG_QUIET" -eq 1 ] && return 0
    local nivel="$1"; shift
    printf '%s [%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$nivel" "$$" "$*" >>"$LOG_FILE" 2>/dev/null
    [ "$VERBOSE" -eq 1 ] && printf '  log[%s] %s\n' "$nivel" "$*" >&2
    return 0
}

rotar_log() {
    local max=$((1024 * 1024))
    [ -f "$LOG_FILE" ] || return 0
    local tam
    tam="$(stat -c '%s' "$LOG_FILE" 2>/dev/null || echo 0)"
    if [ "${tam:-0}" -gt "$max" ]; then
        mv -f "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
    fi
    return 0
}

limpiar() {
    # Borra SOLO el directorio temporal que hemos creado nosotros.
    # Guarda de seguridad: debe estar dentro de BASE_DIR y llamarse .tmp.*
    case "${TMPDIR_RUN:-}" in
        "$BASE_DIR"/.tmp.*) [ -n "$TMPDIR_RUN" ] && rm -rf -- "$TMPDIR_RUN" ;;
    esac
    return 0
}
trap 'limpiar' EXIT INT TERM

# ---- bloqueo para evitar dos ejecuciones simultaneas -----------------------
tomar_lock() {
    if command -v flock >/dev/null 2>&1; then
        exec 9>"$BASE_DIR/.lock" || return 0
        if ! flock -n 9; then
            warn "ya hay otra ejecucion de $PROG en curso; no hago nada"
            log WARN "lock ocupado, salgo"
            exit 0
        fi
        return 0
    fi
    log WARN "flock no disponible: continuo sin bloqueo"
    return 0
}

# =============================================================================
#  LOCALIZACION DE FICHEROS DE EDEN
# =============================================================================

appimage_de_eden() {
    [ -n "$EDEN_APPIMAGE" ] && [ -e "$EDEN_APPIMAGE" ] && { printf '%s' "$EDEN_APPIMAGE"; return 0; }
    local f
    for f in "$HOME"/Applications/*[Ee]den*.AppImage "$HOME"/AppImages/*[Ee]den*.AppImage \
             "$HOME"/*[Ee]den*.AppImage "$HOME"/Emulation/*[Ee]den*.AppImage; do
        [ -f "$f" ] && { printf '%s' "$f"; return 0; }
    done
    if command -v find >/dev/null 2>&1; then
        f="$(find "$HOME" -maxdepth 5 -type f -iname '*eden*.appimage' \
             -not -path '*/.cache/*' 2>/dev/null | head -n 1)"
        [ -n "$f" ] && { printf '%s' "$f"; return 0; }
    fi
    return 1
}

# Devuelve la ruta de qt-config.ini de Eden (y "candidates" en $CANDIDATOS)
localizar_qconfig() {
    local appim
    if [ -n "$EDEN_CONFIG" ] && [ -r "$EDEN_CONFIG" ]; then
        printf '%s' "$EDEN_CONFIG"; return 0
    fi
    appim="$(appimage_de_eden || true)"

    CANDIDATOS=(
        "$HOME/.config/eden/qt-config.ini"
        "$HOME/.config/Eden/qt-config.ini"
        "$HOME/.local/share/eden/config/qt-config.ini"
        "$HOME/.local/share/eden/qt-config.ini"
        "$HOME/.var/app/dev.eden.Eden/config/eden/qt-config.ini"
    )
    if [ -n "$appim" ]; then
        CANDIDATOS=(
            "$(dirname -- "$appim")/user/config/qt-config.ini"
            "$(dirname -- "$appim")/user/qt-config.ini"
            "${CANDIDATOS[@]}"
        )
    fi
    local c
    for c in "${CANDIDATOS[@]}"; do
        if [ -r "$c" ] && grep -q '^\[Controls\]' "$c" 2>/dev/null; then
            printf '%s' "$c"; return 0
        fi
    done
    # ultimo recurso
    if command -v find >/dev/null 2>&1; then
        c="$(find "$HOME" -maxdepth 5 -type f -name 'qt-config.ini' -ipath '*eden*' \
             -not -path '*/.cache/*' 2>/dev/null | while read -r f; do
                 if grep -q '^\[Controls\]' "$f" 2>/dev/null; then printf '%s' "$f"; break; fi
             done)"
        [ -n "$c" ] && { printf '%s' "$c"; return 0; }
    fi
    return 1
}

config_dir_de() { dirname -- "$1"; }

# =============================================================================
#  DETECCION DE MANDOS
# =============================================================================
# Salida: lineas "NOMBRE|UNIQ(MAC)|VENDOR|PRODUCT|HANDLERS|SYSFS"
# El ORDEN de esta lista es el orden de registro del kernel y se usa como
# prediccion del orden de puertos de SDL.
# HANDLERS es la lista de handlers del kernel ("kbd event15 js0"): sirve para
# distinguir un mando de verdad (tiene un nodo js*) de un teclado o un raton.

listar_dispositivos() {
    if [ -n "$EDEN_FAKE_INPUT_DEVICES" ] && [ -r "$EDEN_FAKE_INPUT_DEVICES" ]; then
        grep -v '^[[:space:]]*$' "$EDEN_FAKE_INPUT_DEVICES"
        return 0
    fi
    local din nombre uniqv vend prod handlers h lista
    # OJO: el glob se expande alfabeticamente (input10 antes que input2), asi
    # que ordenamos numericamente por el sufijo: eso da el orden de registro
    # del kernel, que es la mejor aproximacion al orden de puertos de SDL.
    lista="$(ls -1d /sys/class/input/input[0-9]* 2>/dev/null \
             | awk -F'input' '{print $NF" "$0}' | sort -n | cut -d' ' -f2-)"
    for din in $lista; do
        [ -d "$din" ] || continue
        nombre="$(cat "$din/name" 2>/dev/null || echo '')"
        uniqv="$(cat "$din/uniq" 2>/dev/null || echo '')"
        vend="$(cat "$din/id/vendor" 2>/dev/null || echo '')"
        prod="$(cat "$din/id/product" 2>/dev/null || echo '')"
        handlers=""
        for h in "$din"/event* "$din"/js*; do
            [ -e "$h" ] || continue
            handlers="$handlers $(basename -- "$h")"
        done
        printf '%s|%s|%s|%s|%s|%s\n' \
            "$nombre" "$uniqv" "$vend" "$prod" "${handlers# }" "$(basename -- "$din")"
    done
}

# ¿esta lista de handlers indica un mando de verdad?
#   tiene_js  = hay un nodo /dev/input/jsN (el kernel lo trata como joystick)
#   tiene_km  = hay un nodo de teclado (kbd) o raton (mouse*)
tiene_joystick() { # $1 = handlers ("kbd event15 js0")
    local h
    for h in $1; do
        case "$h" in js[0-9]*) return 0 ;; esac
    done
    return 1
}
tiene_teclado_raton() { # $1 = handlers
    local h
    for h in $1; do
        case "$h" in kbd|mouse[0-9]*) return 0 ;; esac
    done
    return 1
}

# clasifica: dualsense | steam_virtual | integrado | auxiliar | otro
# Se le pasan NOMBRE, UNIQ, VENDOR, PRODUCT
# Comprueba un patron configurable tipo "*uno*|*dos*" contra un texto en
# minusculas. Devuelve 0 si coincide.
_extra_match() { # $1 = patrones, $2 = texto (minusculas)
    local pat t p
    pat="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    t="$2"
    local IFS='|'
    for p in $pat; do
        case "$t" in $p) return 0 ;; esac
    done
    return 1
}

# clasifica: dualsense | steam_virtual | integrado | auxiliar | otro
#   $1 = NOMBRE  $3 = VENDOR  $5 = HANDLERS
# El ORDEN de las comprobaciones importa (ver el comentario del final).
clasificar() {
    local nombre="$1" vend="$3" handlers="${5:-}"
    local n
    n="$(printf '%s' "$nombre" | tr '[:upper:]' '[:lower:]')"

    # 1) nombres claramente auxiliares
    case "$n" in
        *touchpad*|*"motion sensors"*|*"consumer control"*|*keyboard*|*mouse*|*"video bus"*|\
        *"power button"*|*"sleep button"*|*"pc speaker"*|*"hd-audio"*|*"lid switch"*|*sensors*)
            printf 'auxiliar'; return ;;
    esac
    _extra_match "$IGNORAR_PATRON" "$n" && { printf 'auxiliar'; return; }

    # 2) DualSense por nombre (antes del filtro de handlers: su nodo gamepad
    #    tiene js, pero por si acaso no fiarse solo del handler)
    case "$n" in
        *"wireless controller"*|*dualsense*) printf 'dualsense'; return ;;
    esac

    # 3) teclados, ratones y dispositivos "raros" de 0x28de/0x0b05 SIN nodo js.
    #    Ejemplos reales en la Ally:
    #      "steamos-manager"   28de  Handlers=kbd        -> NO es un mando
    #      "ASUSTeK ... N-KEY Device" 0b05 Handlers=mouse -> NO es un mando
    #      "ASUS ROG Ally X Gamepad"  0b05 Handlers=kbd event15 js0 -> SI es mando
    if ! tiene_joystick "$handlers" && tiene_teclado_raton "$handlers"; then
        printf 'auxiliar'; return
    fi

    [ "$vend" = "054c" ] && { printf 'dualsense'; return; }
    _extra_match "$DUALSENSE_PATRON" "$n" && { printf 'dualsense'; return; }

    # 4) pads virtuales de Steam (la Ally expone "Microsoft X-Box 360 pad N"
    #    con vendor 28de:11ff; por eso el vendor va ANTES que el nombre, que
    #    tambien casaria con el patron del integrado)
    case "$n" in
        *"steam virtual gamepad"*|*"steam controller"*|*"steam deck controller"*)
            printf 'steam_virtual'; return ;;
    esac
    [ "$vend" = "28de" ] && { printf 'steam_virtual'; return; }

    # 5) mando integrado de la Ally (hid-asus / xpad / ASUS)
    case "$n" in
        *rog*|*ally*|*asus*|*"hid-asus"*)
            printf 'integrado'; return ;;
    esac
    [ "$vend" = "0b05" ] && { printf 'integrado'; return; }
    _extra_match "$INTEGRADO_PATRON" "$n" && { printf 'integrado'; return; }

    printf 'otro'
}

# --- Bluetooth --------------------------------------------------------------
# Salida: lineas "MAC|NOMBRE" de los dispositivos CONECTADOS
bt_conectados() {
    if [ -n "$EDEN_FAKE_BT" ] && [ -r "$EDEN_FAKE_BT" ]; then
        grep -v '^[[:space:]]*$' "$EDEN_FAKE_BT"
        return 0
    fi
    command -v bluetoothctl >/dev/null 2>&1 || return 0
    local mac nom
    while read -r _dev mac _rest; do
        [ -n "${mac:-}" ] || continue
        nom="$(bluetoothctl info "$mac" 2>/dev/null | grep -m1 -E '^[[:space:]]*Name:' | sed 's/.*Name:[[:space:]]*//')"
        [ -n "$nom" ] || nom="(sin nombre)"
        printf '%s|%s\n' "$mac" "$nom"
    done <<EOF
$(bluetoothctl devices Connected 2>/dev/null | head -n 30)
EOF
}

# --- estado global de deteccion --------------------------------------------
# Rellena: DS_SDL_N, DS_SDL_MACS, DS_BT_N, DS_BT_MACS, INTEGRADO_N,
#          INTEGRADO_NOMBRES, VIRT_N, OTROS_LISTA, ESCENARIO, ORDEN_DS
# =============================================================================
#  DETECCION VIA SDL  (lo que Eden ve de verdad)
# =============================================================================
# Por que: cuando Steam Input esta activo (habitual al lanzar desde ES-DE),
# Eden NO ve los mandos nativos: ve los pads VIRTUALES de Steam (guid de Valve)
# "disfrazados" con el nombre del mando fisico ("DualSense Controller N",
# "Asus Rog Ally Controller N"). Leer /sys no basta: hay que preguntarle a SDL,
# que es quien se lo cuenta a Eden. Ademas los PUERTOS cambian entre sesiones,
# asi que hay que leerlos en el momento de lanzar el juego.

SDL_OK=0
SDL_LISTA=""
SDL_DS_LISTA=""     # "puerto:guid" de cada DualSense, ordenado por puerto
SDL_INT_PAR=""      # "puerto:guid" del mando integrado
MODO_RED=""         # nativo | virtual  (segun el guid que usa SDL)

# Carga la lista de mandos segun SDL en $SDL_LISTA. Devuelve 0 si se pudo.
cargar_mandos_sdl() {
    SDL_OK=0; SDL_LISTA=""
    local f="$TMPDIR_RUN/sdl.txt" helper="" err
    : >"$f" 2>/dev/null || return 1

    if [ -n "${EDEN_FAKE_SDL:-}" ] && [ -r "$EDEN_FAKE_SDL" ]; then
        grep -v '^[[:space:]]*$' "$EDEN_FAKE_SDL" >"$f" 2>/dev/null
        SDL_LISTA="$f"; SDL_OK=1
    else
        local c
        for c in "$HERE/eden-mandos-sdl.sh" "$BASE_DIR/eden-mandos-sdl.sh"; do
            [ -r "$c" ] && { helper="$c"; break; }
        done
        if [ -z "$helper" ]; then
            log WARN "no encuentro eden-mandos-sdl.sh (uso el metodo /sys)"
            return 1
        fi
        # se pasan al ayudante las variables que puede necesitar del .conf
        if ! SDL_CRC_CERO="${SDL_CRC_CERO:-}" \
             EDEN_SDL_LIB="${EDEN_SDL_LIB:-}" \
             EDEN_SDL_LIB_DIR="${EDEN_SDL_LIB_DIR:-}" \
             EDEN_APPIMAGE="${EDEN_APPIMAGE:-}" \
             bash "$helper" >"$f" 2>"$TMPDIR_RUN/sdl.err"; then
            err="$(tr '\n' ' ' <"$TMPDIR_RUN/sdl.err" 2>/dev/null | cut -c1-300)"
            log WARN "eden-mandos-sdl.sh fallo: ${err:-sin detalle}"
            return 1
        fi
        SDL_LISTA="$f"; SDL_OK=1
    fi

    # ---- comun a los dos caminos ----
    SDL_INFO="$(grep -m1 '^#lib ' "$f" 2>/dev/null | sed 's/^#lib //')"
    SDL_ORIGEN="$(grep -m1 '^#origen ' "$f" 2>/dev/null | sed 's/^#origen //')"
    log INFO "mandos segun SDL: $(grep -c '|' "$f") dispositivos; lib: ${SDL_INFO:-?} (${SDL_ORIGEN:-?})"
    case "${SDL_ORIGEN:-}" in
        sistema*) log INFO "SDL del sistema: CRC del guid normalizado a 0 (asi coincide con Eden)" ;;
    esac
    return 0
}

# Clasifica un dispositivo de SDL: dualsense | integrado | steam_virtual | otro
# Se clasifica por el NOMBRE que muestra Eden y por el guid (no por el nombre
# del kernel, que en modo virtual es generico: "Microsoft X-Box 360 pad N").
clasificar_sdl() { # $1 = nombre Eden, $2 = guid
    local n
    n="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$n" in
        *dualsense*|*dualshock*) printf 'dualsense'; return 0 ;;
        *"wireless controller"*)
            case "$n" in
                *xbox*|*x-box*) ;;
                *) printf 'dualsense'; return 0 ;;
            esac
            ;;
    esac
    case "$2" in *4c05*) printf 'dualsense'; return 0 ;; esac
    case "$n" in *asus*|*ally*|*rog*) printf 'integrado'; return 0 ;; esac
    case "$2" in *050b*) printf 'integrado'; return 0 ;; esac
    case "$n" in *steam*|*valve*) printf 'steam_virtual'; return 0 ;; esac
    case "$2" in *de28*) printf 'steam_virtual'; return 0 ;; esac
    _extra_match "$DUALSENSE_PATRON" "$n" && { printf 'dualsense'; return 0; }
    _extra_match "$INTEGRADO_PATRON" "$n" && { printf 'integrado'; return 0; }
    printf 'otro'
}

# Rellena todos los globals de deteccion a partir de la lista de SDL.
# Devuelve 0 si ha podido (aunque no haya ningun mando: eso es un resultado
# valido y significa "no hay nada que asignar").
detectar_mandos_sdl() {
    local nombre guid port tipo esgp sdlname serial cat lista_ds=""
    DS_SDL_N=0; DS_SDL_MACS=""; INTEGRADO_N=0; INTEGRADO_NOMBRES=""; INTEGRADO_DETALLE=""
    VIRT_N=0; AUX_N=0; OTROS_LISTA=""; ORDEN_DS=""
    SDL_DS_LISTA=""; SDL_INT_PAR=""; MODO_RED=""
    local hay_de28=0
    local virt_par="" virt_nombre="" virt_n=0

    [ -n "$SDL_LISTA" ] && [ -s "$SDL_LISTA" ] || return 0

    while IFS='|' read -r nombre guid port tipo esgp sdlname serial _indice; do
        [ -n "${nombre:-}" ] || continue
        case "$nombre" in '#'*) continue ;; esac   # linea de informacion de la lib
        [ -n "${guid:-}" ] || continue
        case "$guid" in *de28*) hay_de28=1 ;; esac
        cat="$(clasificar_sdl "$nombre" "$guid")"
        case "$cat" in
            dualsense)
                DS_SDL_N=$((DS_SDL_N + 1))
                lista_ds="$lista_ds ${port:-0}|$guid|${serial:-}"
                DS_SDL_MACS="$DS_SDL_MACS ${serial:-$guid}"
                ;;
            integrado)
                INTEGRADO_N=$((INTEGRADO_N + 1))
                [ -n "$SDL_INT_PAR" ] || SDL_INT_PAR="${port:-0}:$guid"
                INTEGRADO_NOMBRES="${INTEGRADO_NOMBRES:+$INTEGRADO_NOMBRES, }$nombre"
                INTEGRADO_DETALLE="$INTEGRADO_DETALLE
      - $nombre (port ${port:-?}, guid ${guid:0:12}...)"
                ;;
            steam_virtual)
                VIRT_N=$((VIRT_N + 1))
                virt_n=$((virt_n + 1))
                virt_par="${port:-0}:$guid"
                virt_nombre="$nombre"
                ;;
            *) OTROS_LISTA="$OTROS_LISTA
      - $nombre (port ${port:-?}, guid ${guid:0:12}...)" ;;
        esac
    done <"$SDL_LISTA"

    # Un pad virtual de Steam que NO es un DualSense, y ademas es el unico, es el
    # mando integrado de la Ally: al virtualizarlo, Steam no le pone el nombre
    # "Asus...", asi que no se puede reconocer por nombre. Con un solo pad
    # sobrante no hay ambiguedad posible.
    if [ "$INTEGRADO_N" -eq 0 ] && [ "$virt_n" -eq 1 ] && [ -n "$virt_par" ]; then
        INTEGRADO_N=1
        SDL_INT_PAR="$virt_par"
        INTEGRADO_NOMBRES="$virt_nombre"
        INTEGRADO_DETALLE="
      - $virt_nombre (pad virtual de Steam; se toma como integrado)"
        VIRT_N=0
        log INFO "pad virtual sobrante -> mando integrado ($virt_nombre)"
    fi

    # Orden de los DualSense para asignar P1..PN:
    #   conexion (por defecto) = el orden en que los enumera el sistema
    #   mac                    = por numero de serie (un DualSense concreto es
    #                            siempre P1, aunque cambie el orden de conexion)
    if [ -n "$lista_ds" ]; then
        local orden="${ORDEN_DUALSENSE:-conexion}" lista_ord
        if [ "$orden" = "mac" ]; then
            if printf '%s\n' $lista_ds | awk -F'|' '$3==""{e=1} END{exit !e}'; then
                warn "ORDEN_DUALSENSE=mac pero los mandos no dan numero de serie; uso el orden de conexion"
                log WARN "orden mac pedido sin seriales disponibles"
                orden="conexion"
            fi
        fi
        if [ "$orden" = "mac" ]; then
            lista_ord="$(printf '%s\n' $lista_ds | sort -t'|' -k3,3)"
        else
            lista_ord="$(printf '%s\n' $lista_ds | sort -n -t'|' -k1,1)"
        fi
        # P1_SERIE: ese mando concreto va SIEMPRE primero (P1)
        if [ -n "${P1_SERIE:-}" ]; then
            local pk="" resto="" e
            for e in $lista_ord; do
                case "$e" in
                    *"|$P1_SERIE") pk="$e" ;;
                    *) resto="$resto $e" ;;
                esac
            done
            if [ -n "$pk" ]; then
                lista_ord="$pk $(printf '%s' "$resto" | sed 's/^ *//')"
                log INFO "P1_SERIE=$P1_SERIE -> forzado como P1"
            else
                warn "P1_SERIE=$P1_SERIE no coincide con ningun DualSense detectado"
                log WARN "P1_SERIE no encontrado entre los seriales"
            fi
        fi
        SDL_DS_LISTA="$(printf '%s\n' $lista_ord | awk -F'|' 'NF{printf "%s:%s ", $1, $2}')"
        SDL_DS_LISTA="${SDL_DS_LISTA% }"
    fi

    # modo: si algun dispositivo usa el guid de Valve (de28), Steam Input manda
    if [ "$hay_de28" -eq 1 ]; then MODO_RED="virtual"; else MODO_RED="nativo"; fi

    # ---- escenario ----
    if [ "$DS_SDL_N" -gt 0 ]; then
        [ "$MODO_RED" = "virtual" ] && ESCENARIO="steam_input" || ESCENARIO="nativo"
    elif [ "$INTEGRADO_N" -gt 0 ]; then
        [ "$MODO_RED" = "virtual" ] && ESCENARIO="steam_input_integrado" || ESCENARIO="solo_integrado"
    else
        ESCENARIO="desconocido"
    fi

    # ---- cuantos DualSense por Bluetooth (para avisar si Eden no los ve) ----
    DS_BT_N=0; DS_BT_MACS=""
    local btmac btnom
    while IFS='|' read -r btmac btnom; do
        [ -n "${btmac:-}" ] || continue
        case "$btnom" in
            *"Wireless Controller"*|*DualSense*)
                DS_BT_N=$((DS_BT_N + 1)); DS_BT_MACS="$DS_BT_MACS $btmac" ;;
        esac
    done <<EOF
$(bt_conectados)
EOF
    DS_BT_MACS="${DS_BT_MACS# }"

    DS_N="$DS_SDL_N"
    [ "$DS_N" -gt "$JUGADORES_MAX" ] && DS_N="$JUGADORES_MAX"
    DS_FUENTE="SDL (lo que ve Eden)"
    return 0
}

detectar_mandos() {
    # 1) intento preferente: preguntar a SDL (lo que ve Eden)
    if cargar_mandos_sdl; then
        if detectar_mandos_sdl; then
            log INFO "deteccion SDL: modo=$MODO_RED escenario=$ESCENARIO ds=$((${DS_SDL_N:-0})) integrado=$((${INTEGRADO_N:-0})) otros=$((${VIRT_N:-0}))"
            return 0
        fi
        log WARN "no he podido interpretar la lista de SDL; uso el metodo /sys"
    fi
    SDL_OK=0
    # 2) respaldo: leer /sys (puede equivocarse con Steam Input activo)
    DS_SDL_N=0; DS_SDL_MACS=""; INTEGRADO_N=0; INTEGRADO_NOMBRES=""; INTEGRADO_DETALLE=""
    VIRT_N=0; OTROS_LISTA=""; AUX_N=0; ORDEN_DS=""
    local nombre uniqv vend prod cat
    local nombres_vistos=""

    while IFS='|' read -r nombre uniqv vend prod handlers _sys; do
        [ -n "$nombre" ] || continue
        cat="$(clasificar "$nombre" "$uniqv" "$vend" "$prod" "$handlers")"
        case "$cat" in
            auxiliar) AUX_N=$((AUX_N + 1)) ;;
            dualsense)
                DS_SDL_N=$((DS_SDL_N + 1))
                # de-duplicar MAC (un mando puede exponer varios nodos)
                DS_SDL_MACS="$DS_SDL_MACS $uniqv"
                ;;
            steam_virtual) VIRT_N=$((VIRT_N + 1)) ;;
            integrado)
                INTEGRADO_N=$((INTEGRADO_N + 1))
                case " $nombres_vistos " in
                    *" $nombre "*) ;;
                    *) nombres_vistos="$nombres_vistos $nombre"
                       if [ -n "$INTEGRADO_NOMBRES" ]; then
                           INTEGRADO_NOMBRES="$INTEGRADO_NOMBRES, $nombre"
                       else
                           INTEGRADO_NOMBRES="$nombre"
                       fi
                       INTEGRADO_DETALLE="$INTEGRADO_DETALLE
      - $nombre ($vend:$prod)" ;;
                esac
                ;;
            *) OTROS_LISTA="$OTROS_LISTA
      - $nombre ($vend:$prod)" ;;
        esac
    done <<EOF
$(listar_dispositivos)
EOF

    # de-duplicar MACs conservando el orden (prediccion del orden de puertos)
    local mac lista="" visto
    ORDEN_DS=""
    for mac in $DS_SDL_MACS; do
        [ -n "$mac" ] || continue
        visto=0
        case " $lista " in *" $mac "*) visto=1 ;; esac
        [ "$visto" -eq 0 ] && lista="$lista $mac" && ORDEN_DS="$ORDEN_DS $mac"
    done
    DS_SDL_MACS="${lista# }"
    # si no hay MACs (p.ej. USB), el numero de nodos es la cuenta
    if [ -z "$DS_SDL_MACS" ]; then
        DS_SDL_N=0
    else
        DS_SDL_N=0
        for mac in $DS_SDL_MACS; do DS_SDL_N=$((DS_SDL_N + 1)); done
    fi

    # Bluetooth (cuenta DualSense aunque Steam Input los oculte a Eden)
    DS_BT_N=0; DS_BT_MACS=""
    local btmac btnom
    while IFS='|' read -r btmac btnom; do
        [ -n "${btmac:-}" ] || continue
        case "$btnom" in
            *"Wireless Controller"*|*DualSense*)
                DS_BT_N=$((DS_BT_N + 1)); DS_BT_MACS="$DS_BT_MACS $btmac" ;;
        esac
    done <<EOF
$(bt_conectados)
EOF
    DS_BT_MACS="${DS_BT_MACS# }"

    # --- escenario -----------------------------------------------------------
    if [ "$DS_SDL_N" -gt 0 ]; then
        ESCENARIO="nativo"
    elif [ "$DS_BT_N" -gt 0 ] && [ "$VIRT_N" -gt 0 ]; then
        ESCENARIO="steam_input"
    elif [ "$VIRT_N" -gt 0 ]; then
        ESCENARIO="steam_input"
    elif [ "$INTEGRADO_N" -gt 0 ]; then
        ESCENARIO="solo_integrado"
    else
        ESCENARIO="desconocido"
    fi

    # numero efectivo de DualSense a asignar
    if [ "$DS_SDL_N" -ge "$DS_BT_N" ]; then
        DS_N="$DS_SDL_N"; DS_FUENTE="sysfs/SDL"
    else
        DS_N="$DS_BT_N"; DS_FUENTE="bluetoothctl"
    fi
    [ "$DS_N" -gt "$JUGADORES_MAX" ] && DS_N="$JUGADORES_MAX"
}

# =============================================================================
#  PLANTILLAS
# =============================================================================

perfil_path() { # $1 = nombre del perfil
    local d
    for d in "$(config_dir_de "$QC")/input" "$HOME/.config/eden/input" \
             "$HOME/.config/Eden/input" "$HOME/.local/share/eden/config/input"; do
        [ -r "$d/$1.ini" ] && { printf '%s' "$d/$1.ini"; return 0; }
    done
    return 1
}

plantilla_path() { printf '%s/%s.player0.txt' "$TPL_DIR" "$1"; }

# Comprueba que un fichero de plantilla/perfil tiene pinta de bloque player_
validar_plantilla() {
    local f="$1"
    [ -r "$f" ] || return 1
    grep -qE '^player_[0-9]+_' "$f" 2>/dev/null
}

# Normaliza un origen (perfil sin prefijo player_N_ o plantilla con el) a un
# fichero temporal con el prefijo player_0_ y sin lineas \default duplicadas.
normalizar_origen() { # $1 = fichero origen  $2 = fichero destino
    local src="$1" dst="$2"
    awk '
        {
            sub(/\r$/, "")
            if ($0 ~ /^[ \t]*$/) next
            if ($0 ~ /^#/) next
            if ($0 ~ /^player_[0-9]+_/) {
                sub(/^player_[0-9]+_/, "player_0_", $0)
                print
                next
            }
            # perfil sin prefijo: le anadimos player_0_ si parece una clave
            if ($0 ~ /^[A-Za-z0-9_]+(\\default)?=/) {
                print "player_0_" $0
                next
            }
        }
    ' "$src" >"$dst" 2>/dev/null
    validar_plantilla "$dst"
}

# Heuristica: ¿el guid de la plantilla parece de DualSense?
guid_de_plantilla() { # $1 = fichero
    grep -o 'guid:[0-9a-fA-F]\+' "$1" 2>/dev/null | head -n 1 | sed 's/^guid://'
}

resolver_fuente() { # $1 = dualsense|ally  -> imprime ruta de fichero normalizado
    local tipo="$1" tpl prof out
    tpl="$(plantilla_path "$tipo")"
    if [ "$USAR_PERFIL" = "auto" ] || [ "$USAR_PERFIL" = "si" ]; then
        if [ "$tipo" = "dualsense" ] && [ -r "$tpl" ]; then
            printf '%s' "$tpl"; return 0
        fi
        if [ "$tipo" = "ally" ] && [ -r "$tpl" ]; then
            printf '%s' "$tpl"; return 0
        fi
        prof="$(perfil_path "$PERFIL" || true)"
        if [ -n "${prof:-}" ] && [ -r "$prof" ]; then
            out="$TMPDIR_RUN/fuente.$tipo.txt"
            if normalizar_origen "$prof" "$out"; then
                printf '%s' "$out"; return 0
            fi
        fi
    fi
    [ -r "$tpl" ] && { printf '%s' "$tpl"; return 0; }
    return 1
}

# =============================================================================
#  CONFIGURACION ACTUAL: jugadores existentes
# =============================================================================

# lineas player_ del fichero

# indices de jugador presentes (0 1 2 ...)
indices_jugador() {
    awk '/^\[/{i=($0=="[Controls]")}
         i && /^player_[0-9]+_/ { n=$0; sub(/^player_/,"",n); sub(/_.*/,"",n); print n }
    ' "$1" | sort -n -u
}

# extra: lineas player_K_ del original (para conservar claves desconocidas)
extra_de_jugador() { # $1 = fichero, $2 = k, $3 = destino
    awk -v k="$2" '
        /^\[/ { i = ($0 == "[Controls]"); next }
        i && index($0, "player_" k "_") == 1 { print }
    ' "$1" >"$3" 2>/dev/null
}

# =============================================================================
#  RENDERIZADO DE UN JUGADOR
# =============================================================================
# render_player K CONNECTED GUID PORT TYPE EXTRA_FILE > salida
#   GUID=""  -> no se toca el guid de la plantilla
render_player() {
    local k="$1" conn="$2" guid="$3" port="$4" type="$5" extra="$6"
    awk -v k="$k" -v conn="$conn" -v guid="$guid" -v port="$port" -v type="$type" \
        -v tpl="$FUENTE" -v extra="$extra" '
    # d = "" escribe \default=false (lo correcto cuando TOCAMOS el valor).
    # Si el valor no cambia respecto al original, se conserva su \default
    # original y el fichero queda identico byte a byte.
    function emit(n, v, d) {
        print "player_" k "_" n "=" v
        print "player_" k "_" n "\\default=" ((d == "") ? "false" : d)
    }
    function def_de(n, v) {
        if ((n in odef) && (oval[n] == v)) return odef[n]
        return ""
    }
    function keyname(line,  eq, key) {
        eq = index(line, "=")
        if (eq > 0) key = substr(line, 1, eq - 1); else key = line
        sub(/^player_[0-9]+_/, "", key)
        sub(/\\default$/, "", key)
        return key
    }
    function valueof(line,  eq) {
        eq = index(line, "=")
        return (eq > 0) ? substr(line, eq + 1) : ""
    }
    # OJO: el formato es "clave\\default=valor", el \\default va en la CLAVE
    function isdef(line,  eq, key) {
        eq = index(line, "=")
        if (eq <= 0) return 0
        key = substr(line, 1, eq - 1)
        return (key ~ /\\default$/)
    }
    function xform(v, n, ov, tok, tokv) {
        if (guid != "") gsub(/guid:[0-9a-fA-F]+/, "guid:" guid, v)
        if (port != "") gsub(/port:[0-9]+/, "port:" port, v)
        # la calibracion del stick es de cada mando concreto: no se copia
        if (n in oval && oval[n] ~ /offset_x:/) {
            ov = oval[n]
            if (match(ov, /offset_x:[-0-9.]+/)) {
                tokv = substr(ov, RSTART, RLENGTH)
                gsub(/offset_x:[-0-9.]+/, tokv, v)
            }
            if (match(ov, /offset_y:[-0-9.]+/)) {
                tokv = substr(ov, RSTART, RLENGTH)
                gsub(/offset_y:[-0-9.]+/, tokv, v)
            }
        }
        return v
    }
    BEGIN {
        # 0) valores originales del jugador (para conservar su calibracion)
        if (extra != "") {
            while ((getline e0 < extra) > 0) {
                sub(/\r$/, "", e0)
                if (e0 !~ /^player_[0-9]+_/) continue
                if (isdef(e0)) { odef[keyname(e0)] = valueof(e0); continue }
                oval[keyname(e0)] = valueof(e0)
            }
            close(extra)
        }
        # 1) claves de la plantilla (el valor se toma de la linea sin "\default")
        while ((getline t < tpl) > 0) {
            sub(/\r$/, "", t)
            if (t ~ /^#/ || t ~ /^[ \t]*$/) continue
            if (t !~ /^player_[0-9]+_/) continue
            n = keyname(t)
            if (n == "") continue
            # El \default va en la CLAVE ("clave\default=valor"). Si aparece
            # antes que la linea de valor hay que ignorarlo SIN marcarlo como
            # visto, o se perderia la clave (pasa con player_N_profile_name).
            if (isdef(t)) continue
            if (!(n in visto)) {
                visto[n] = 1
                orden[++cnt] = n
                val[n] = valueof(t)
            }
        }
        for (i = 1; i <= cnt; i++) {
            n = orden[i]
            # connected y type se emiten en su sitio, con nuestros valores
            if (n == "connected") { emit(n, conn, def_de(n, conn)); continue }
            if (n == "type")      { emit(n, type, def_de(n, type)); continue }
            v = xform(val[n], n)
            emit(n, v, def_de(n, v))
        }
        # 2) claves del jugador original que la plantilla no cubre: se conservan
        #    (salvo connected/type, que se emiten siempre con nuestros valores)
        if (extra != "") {
            while ((getline e < extra) > 0) {
                sub(/\r$/, "", e)
                if (e ~ /^[ \t]*$/) continue
                if (e !~ /^player_[0-9]+_/) continue
                if (isdef(e)) continue
                n = keyname(e)
                if (n == "" || (n in visto)) continue
                if (n == "connected" || n == "type") continue
                visto[n] = 1
                v = xform(valueof(e), n)
                emit(n, v, def_de(n, v))
            }
        }
        # 3) solo si la plantilla no los traia
        if (!("connected" in visto)) emit("connected", conn, def_de("connected", conn))
        if (!("type" in visto))      emit("type", type, def_de("type", type))
    }
    ' /dev/null
}

# =============================================================================
#  MONTAJE DEL FICHERO NUEVO
# =============================================================================
# Del plan (tokens "tipo:jugador:puerto") saca los datos de un jugador.
# Salida: "conn|port|guid|fuente"
# Los tokens del plan son "tipo:jugador:puerto" o bien "tipo:jugador:puerto:guid"
# (el 4º campo, opcional, es el guid exacto que ha dado SDL; si falta se usa
#  GUID_DUALSENSE / GUID_INTEGRADO, que son la via de respaldo).
datos_de_jugador() { # $1 = indice de jugador
    local k="$1" t ti tp tj tg rest val_port="$1" val_fuente="" val_guid=""
    for t in $PLAN_JUGADORES; do
        ti="${t%%:*}"
        rest="${t#*:}"; tj="${rest%%:*}"
        rest="${rest#*:}"; tp="${rest%%:*}"
        tg=""
        case "$t" in *:*:*:*) tg="${t#*:*:*:}" ;; esac
        [ "${tj:-}" = "$k" ] || continue
        val_port="${tp:-0}"
        val_guid="${tg:-}"
        case "$ti" in
            dual)
                val_fuente="$FUENTE_DS"
                [ -z "$val_guid" ] && val_guid="$GUID_DUALSENSE" ;;
            integrado)
                val_fuente="$FUENTE_INT"
                [ -z "$val_guid" ] && val_guid="$GUID_INTEGRADO" ;;
        esac
        printf '%s|%s|%s|%s' "true" "$val_port" "$val_guid" "$val_fuente"
        return 0
    done
    printf '%s|%s|%s|%s' "false" "$val_port" "" ""
    return 0
}

# Deja el bloque de un jugador tal cual, forzando solo connected=false.
# Se usa para los jugadores sobrantes: diff minimo y cero riesgo.
forzar_desconectado() { # $1 = fichero con las lineas del jugador, $2 = k
    awk -v k="$2" '
        { sub(/\r$/, "") }
        /^player_[0-9]+_connected=/ {
            v = $0; sub(/.*=/, "", v)
            # si ya estaba en false, no se toca nada (ni el \default)
            igual = (v == "false")
            print "player_" k "_connected=false"
            next
        }
        /^player_[0-9]+_connected\\default=/ {
            if (igual) print; else print "player_" k "_connected\\default=false"
            next
        }
        { print }
    ' "$1"
}

montar_fichero() { # $1 = fichero nuevo  ($PLAN_*, $INDICES, $QC_LF, $TMPDIR_RUN)
    local nuevo="$1"
    local bloque="$TMPDIR_RUN/players.block"
    : >"$bloque" || return 1

    local k datos conn port guid fuente extra vacia="$TMPDIR_RUN/fuente.vacia"
    : >"$vacia"

    for k in $INDICES; do
        datos="$(datos_de_jugador "$k")"
        conn="${datos%%|*}"; datos="${datos#*|}"
        port="${datos%%|*}"; datos="${datos#*|}"
        guid="${datos%%|*}"; fuente="${datos#*|}"
        extra="$TMPDIR_RUN/extra.$k"
        extra_de_jugador "${QC_LF:-$QC}" "$k" "$extra"

        if [ "$conn" = "true" ] && [ -n "${fuente:-}" ] && [ -r "$fuente" ]; then
            FUENTE="$fuente"
            render_player "$k" true "$guid" "$port" "$TIPO_CONTROLADOR" "$extra" >>"$bloque"
        elif [ "$conn" = "false" ] && [ -s "$extra" ]; then
            # ya existia: se conserva entero y solo se marca como desconectado
            forzar_desconectado "$extra" "$k" >>"$bloque"
        else
            # no existia (o no hay plantilla): bloque minimo
            FUENTE="$vacia"
            render_player "$k" "$conn" "$guid" "$port" "$TIPO_CONTROLADOR" "$extra" >>"$bloque"
        fi
    done

    # Ensamblado: se conserva todo y las lineas player_ de [Controls] se
    # sustituyen por el bloque nuevo EN LA POSICION de la primera de ellas,
    # de modo que el resto del fichero no se mueve.
    awk -v bloque="$bloque" '
        function volcar() {
            while ((getline l < bloque) > 0) print l
            close(bloque)
        }
        /^\[/ {
            if (inctl && !volcado) { volcar(); volcado = 1 }
            inctl = ($0 == "[Controls]")
            print
            next
        }
        {
            if (inctl && $0 ~ /^player_[0-9]+_/) {
                if (!volcado) { volcar(); volcado = 1 }
                next
            }
            print
        }
        END { if (inctl && !volcado) { volcar(); volcado = 1 } }
    ' "${QC_LF:-$QC}" >"$nuevo"
}

# =============================================================================
#  VALIDACION DEL FICHERO NUEVO
# =============================================================================
validar_salida() { # $1 = nuevo  $2 = original
    local nuevo="$1" orig="$2"

    # 1) mismas secciones, mismo orden
    if ! diff -q <(grep '^\[' "$orig") <(grep '^\[' "$nuevo") >/dev/null 2>&1; then
        err "las secciones del fichero generado no coinciden con el original"; return 1
    fi
    # 2) una sola [Controls]
    local nctl
    nctl="$(grep -c '^\[Controls\]$' "$nuevo" 2>/dev/null || echo 0)"
    [ "$nctl" = "1" ] || { err "[Controls] aparece $nctl veces en el generado"; return 1; }

    # 3) lineas no-player de [Controls] intactas
    if ! diff -q \
        <(awk '/^\[/{i=($0=="[Controls]")} i && !/^player_/' "$orig") \
        <(awk '/^\[/{i=($0=="[Controls]")} i && !/^player_/' "$nuevo") >/dev/null 2>&1; then
        err "se han modificado lineas de [Controls] que no son de jugador"; return 1
    fi

    # 4) cada jugador esperado aparece exactamente una vez con 'connected='
    local k cuenta malo=0
    for k in $INDICES; do
        cuenta="$(awk -v k="$k" '
            /^\[/{i=($0=="[Controls]")}
            i && index($0, "player_" k "_connected=") == 1 { n++ }
            END{print n+0}' "$nuevo")"
        [ "$cuenta" = "1" ] || { err "player_$k tiene $cuenta lineas connected= (esperado 1)"; malo=1; }
    done
    [ "$malo" -eq 0 ] || return 1

    # 4b) no debe haber jugadores fuera de la lista esperada
    local fuera
    fuera="$(awk '/^\[/{i=($0=="[Controls]")}
                    i && /^player_[0-9]+_/ { n=$0; sub(/^player_/,"",n); sub(/_.*/,"",n); print n }' "$nuevo" \
             | sort -n -u | tr '\n' ' ')"
    fuera="${fuera% }"
    [ "$fuera" = "$INDICES" ] || { err "jugadores en el generado ('$fuera') != esperados ('$INDICES')"; return 1; }

    # 5) todos los jugadores tienen el mismo numero de claves
    local conteo
    conteo="$(awk '/^\[/{i=($0=="[Controls]")} i && /^player_[0-9]+_/ {
                       n=$0; sub(/^player_/,"",n); sub(/_.*/,"",n)
                       k[n]++ }
                   END { for (x in k) print x, k[x] }' "$nuevo" \
              | awk '{print $2}' | sort -u | wc -l)"
    [ "$conteo" = "1" ] || warn "los jugadores del generado no tienen el mismo numero de claves (revisa con --dry-run)"

    # 6) jugadores conectados esperados
    local esperados
    esperados="$(awk -v p="$PLAN_JUGADORES" 'BEGIN{n=split(p,a," "); c=0; for(i=1;i<=n;i++) if (a[i] != "") c++; print c}')"
    local reales
    reales="$(awk '/^\[/{i=($0=="[Controls]")} i && /^player_[0-9]+_connected=true/ {n++} END{print n+0}' "$nuevo")"
    [ "$reales" = "$esperados" ] || {
        err "conectados en el generado ($reales) != planificados ($esperados)"; return 1; }

    return 0
}

# =============================================================================
#  PLAN DE ASIGNACION (via SDL)
# =============================================================================
# Aqui SI sabemos cual es cada mando y en que puerto lo tiene Eden AHORA MISMO,
# porque se lo hemos preguntado a SDL. Los tokens son "tipo:jugador:puerto:guid"
# con los valores reales de cada dispositivo.
planificar_sdl() {
    PLAN_JUGADORES=""
    local resumen="" i=0 primero_int=0 par pg t k

    case "$ORDEN_INTEGRADO" in
        ignorar) INCLUIR_INT=0 ;;
        primero) INCLUIR_INT=1; primero_int=1 ;;
        *)       INCLUIR_INT=1 ;;
    esac
    # si no hay ningun DualSense, el integrado entra como P1
    if [ "${DS_SDL_N:-0}" -eq 0 ] \
       && { [ "${INTEGRADO_N:-0}" -gt 0 ] || [ "${ASUMIR_INTEGRADO:-0}" -eq 1 ]; }; then
        INCLUIR_INT=1
        primero_int=1
    fi
    # no se puede asignar el integrado si SDL no nos ha dado su puerto y guid.
    # El panel puede pedir un --who "esperado" en consolas con mando integrado
    # (Steam Input solo lo expone al lanzar): se usa un puerto/guid de relleno
    # solo para el resumen, nunca para aplicar.
    if [ "$INCLUIR_INT" -eq 1 ] && [ -z "${SDL_INT_PAR:-}" ]; then
        if [ "${ASUMIR_INTEGRADO:-0}" -eq 1 ]; then
            SDL_INT_PAR="0:00000000000000000000000000000000"
            INTEGRADO_NOMBRES="${INTEGRADO_NOMBRES:-Steam Input}"
        else
            INCLUIR_INT=0
            primero_int=0
        fi
    fi

    if [ "${DS_SDL_N:-0}" -eq 0 ] && [ "$INCLUIR_INT" -eq 0 ]; then
        return 2
    fi

    if [ "$INCLUIR_INT" -eq 1 ] && [ "$primero_int" -eq 1 ]; then
        par="${SDL_INT_PAR%%:*}"; pg="${SDL_INT_PAR#*:}"
        PLAN_JUGADORES="$PLAN_JUGADORES integrado:0:$par:$pg"
        resumen="$resumen
      Player 1 = INTEGRADO [$INTEGRADO_NOMBRES]  (port $par)"
        i=1
    fi

    # Si el integrado entra al final, reservarle el ultimo hueco: con 4
    # DualSense y tope 4 se cae el ultimo DS (el candidato a P4).
    local tope="${JUGADORES_MAX:-4}" limite_ds
    [ "$tope" -gt "$N_TOTALES" ] 2>/dev/null && tope="$N_TOTALES"
    limite_ds="$tope"
    if [ "$primero_int" -eq 0 ] && [ "$INCLUIR_INT" -eq 1 ] \
       && [ -n "${SDL_INT_PAR:-}" ]; then
        limite_ds=$((tope - 1))
        [ "$limite_ds" -lt 0 ] && limite_ds=0
    fi

    # P1..PN = los DualSense, con SUS puertos reales (ordenados por puerto)
    k=0
    for t in ${SDL_DS_LISTA:-}; do
        [ "$k" -lt "${DS_N:-0}" ] || break
        [ "$i" -lt "$N_TOTALES" ] || break
        [ "$i" -lt "$limite_ds" ] || break
        par="${t%%:*}"; pg="${t#*:}"
        PLAN_JUGADORES="$PLAN_JUGADORES dual:$i:$par:$pg"
        resumen="$resumen
      Player $((i + 1)) = DualSense $((k + 1))  (port $par)"
        i=$((i + 1)); k=$((k + 1))
    done

    if [ "$primero_int" -eq 0 ] && [ "$INCLUIR_INT" -eq 1 ] \
       && [ "$i" -lt "$tope" ]; then
        par="${SDL_INT_PAR%%:*}"; pg="${SDL_INT_PAR#*:}"
        PLAN_JUGADORES="$PLAN_JUGADORES integrado:$i:$par:$pg"
        resumen="$resumen
      Player $((i + 1)) = INTEGRADO [$INTEGRADO_NOMBRES]  (port $par)"
        i=$((i + 1))
    fi

    PLAN_RESUMEN="$resumen"
    plan_desconectar_resto "$i"
    return 0
}

# =============================================================================
#  PLAN DE ASIGNACION (respaldo, leyendo /sys)
# =============================================================================
# Rellena: PLAN_JUGADORES ("dual:0 integrado:1 ..."), PLAN_RESUMEN
planificar() {
    PLAN_JUGADORES=""

    # Preferente: plan a partir de lo que dice SDL (puertos y guids exactos).
    if [ "${SDL_OK:-0}" -eq 1 ]; then
        planificar_sdl
        return $?
    fi

    local resumen="" i=0
    local p1_es_integrado=0

    # Si el escenario es Steam Input, los pads "de verdad" para Eden son los
    # virtuales; usamos el numero efectivo de DualSense para decidir.
    local n="$DS_N"

    # ¿el integrado entra en el plan?
    case "$ORDEN_INTEGRADO" in
        ignorar) INCLUIR_INT=0 ;;
        *)       INCLUIR_INT=1 ;;
    esac
    # si no hay ningun DualSense, el integrado es obligatorio como P1
    if [ "$n" -eq 0 ] && [ "$INTEGRADO_N" -gt 0 ]; then
        INCLUIR_INT=1
        p1_es_integrado=1
    fi
    # en escenario Steam Input no podemos identificar el integrado
    if [ "$ESCENARIO" = "steam_input" ]; then INCLUIR_INT=0; fi

    # ¿ponemos el integrado primero?
    local primero_int=0
    if [ "$INCLUIR_INT" -eq 1 ]; then
        case "$ORDEN_INTEGRADO" in
            primero) primero_int=1 ;;
            *)       primero_int=0 ;;
        esac
        [ "$p1_es_integrado" -eq 1 ] && primero_int=1
    fi

    # --- escenario Steam Input: asignamos los pads virtuales 1..N -----------
    if [ "$ESCENARIO" = "steam_input" ]; then
        local np="$VIRT_N"
        [ "$np" -gt "$JUGADORES_MAX" ] && np="$JUGADORES_MAX"
        if [ "$np" -eq 0 ]; then return 2; fi
        while [ "$i" -lt "$np" ]; do
            PLAN_JUGADORES="$PLAN_JUGADORES dual:$i:$i"
            resumen="$resumen
      Player $((i + 1)) = pad virtual Steam $i   (port $i)"
            i=$((i + 1))
        done
        PLAN_RESUMEN="$resumen"
        plan_desconectar_resto "$i"
        return 0
    fi

    # --- escenario nativo / solo integrado ----------------------------------
    if [ "$n" -eq 0 ] && [ "$INCLUIR_INT" -eq 0 ]; then
        return 2
    fi

    if [ "$primero_int" -eq 1 ]; then
        PLAN_JUGADORES="$PLAN_JUGADORES integrado:0:0"
        resumen="$resumen
      Player 1 = INTEGRADO [$INTEGRADO_NOMBRES]   (port 0)"
        i=1
        local j=0
        while [ "$j" -lt "$n" ] && [ "$i" -lt "$N_TOTALES" ] \
              && [ "$i" -lt "$JUGADORES_MAX" ]; do
            PLAN_JUGADORES="$PLAN_JUGADORES dual:$i:$j"
            resumen="$resumen
      Player $((i + 1)) = DualSense $((j + 1))   (port $j)"
            i=$((i + 1)); j=$((j + 1))
        done
    else
        local j=0
        while [ "$j" -lt "$n" ]; do
            PLAN_JUGADORES="$PLAN_JUGADORES dual:$i:$j"
            resumen="$resumen
      Player $((i + 1)) = DualSense $((j + 1))   (port $j)"
            i=$((i + 1)); j=$((j + 1))
            [ "$i" -ge "$N_TOTALES" ] && break
            [ "$i" -ge "$JUGADORES_MAX" ] && break
        done
        if [ "$INCLUIR_INT" -eq 1 ] && [ "$i" -lt "$N_TOTALES" ] \
           && [ "$i" -lt "$JUGADORES_MAX" ]; then
            PLAN_JUGADORES="$PLAN_JUGADORES integrado:$i:0"
            resumen="$resumen
      Player $((i + 1)) = INTEGRADO [$INTEGRADO_NOMBRES]   (port 0)"
            i=$((i + 1))
        fi
    fi

    if [ "$INCLUIR_INT" -eq 1 ] && [ "$i" -ge "$N_TOTALES" ]; then
        warn "no hay hueco para el mando integrado: el fichero solo define $N_TOTALES jugadores"
    fi
    PLAN_RESUMEN="$resumen"
    plan_desconectar_resto "$i"
    return 0
}

plan_desconectar_resto() { # $1 = primer indice desconectado
    local i="$1"
    if [ "$i" -ge "$N_TOTALES" ]; then
        PLAN_RESUMEN="$PLAN_RESUMEN
      (no hay jugadores sobrantes en el fichero: $N_TOTALES en total)"
    else
        PLAN_RESUMEN="$PLAN_RESUMEN
      Players $((i + 1))..$N_TOTALES = desconectados"
    fi
}

# =============================================================================
#  COMPROBACIONES PREVIAS
# =============================================================================

# Avisa si alguna config por juego (<config>/custom/<title id>.ini) define
# jugadores: en ese caso Eden ignoraria el [Controls] global PARA ESE JUEGO.
avisar_custom_overrides() {
    local d f n ids=""
    [ -n "${QC:-}" ] || return 0
    d="$(config_dir_de "$QC")/custom"
    [ -d "$d" ] || return 0
    for f in "$d"/*.ini; do
        [ -f "$f" ] || continue
        n="$(awk '/^\[/{i=($0=="[Controls]")} i && /^player_[0-9]+_/ {c++} END{print c+0}' "$f" 2>/dev/null)"
        [ "${n:-0}" -gt 0 ] && ids="$ids $(basename -- "$f" .ini)($n)"
    done
    if [ -n "$ids" ]; then
        warn "hay configs POR JUEGO que definen jugadores y pueden ignorar el [Controls] global:"
        printf '  %s\n' "$ids" >&2
        log WARN "custom overrides:$ids"
    fi
    return 0
}

eden_en_ejecucion() {
    local lineas
    lineas="$(pgrep -af . 2>/dev/null \
        | awk -v me="$$" -v pp="${PPID:-0}" '$1 != me && $1 != pp' \
        | grep -Ev 'eden-autoconfig|eden-diagnostico|pgrep|grep -E' || true)"
    [ -z "$lineas" ] && return 1
    printf '%s\n' "$lineas" | grep -E "$EDEN_PROCESOS_PATRON" >/dev/null 2>&1
}

# Muestra (para --status) que procesos ha encontrado como "Eden"
procesos_eden() {
    pgrep -af . 2>/dev/null \
        | awk -v me="$$" -v pp="${PPID:-0}" '$1 != me && $1 != pp' \
        | grep -Ev 'eden-autoconfig|eden-diagnostico|pgrep|grep -E' \
        | grep -E "$EDEN_PROCESOS_PATRON" 2>/dev/null || true
}

mostrar_estado() {
    say "Eden (AppImage)     : $(appimage_de_eden || echo 'no encontrado')"
    say "qt-config.ini       : $QC"
    say "perfil usado        : $PERFIL -> $(perfil_path "$PERFIL" || echo 'NO ENCONTRADO')"
    local p_ed
    p_ed="$(procesos_eden)"
    if [ -n "$p_ed" ]; then
        say "Eden en ejecucion   : SI  (no se aplicara nada)"
        printf '   %s\n' "$p_ed"
    else
        say "Eden en ejecucion   : no"
    fi
    say ""
    say "--- mandos ---"
    if [ "${SDL_OK:-0}" -eq 1 ]; then
        say "Fuente de deteccion : SDL (lo mismo que ve Eden)"
        [ -n "${SDL_INFO:-}" ] && say "  libSDL3           : $SDL_INFO"
        [ -n "${SDL_ORIGEN:-}" ] && say "  origen            : $SDL_ORIGEN"
        say "Modo de los mandos  : ${MODO_RED:-?}"
    else
        say "Fuente de deteccion : /sys + bluetoothctl (SDL no disponible)"
    fi
    say "DualSense           : $DS_SDL_N   [$DS_SDL_MACS ]"
    say "  puertos DualSense : ${SDL_DS_LISTA:-<los calcula el metodo de respaldo>}"
    say "DualSense (Bluetooth): $DS_BT_N   [$DS_BT_MACS ]"
    say "Pads virtuales Steam : $VIRT_N"
    say "Candidatos integrado : $INTEGRADO_N$INTEGRADO_DETALLE"
    [ -n "${SDL_INT_PAR:-}" ] && say "  puerto integrado  : $SDL_INT_PAR"
    say "Auxiliares ignorados : $AUX_N"
    [ -n "$OTROS_LISTA" ] && say "Otros (no usados)    :$OTROS_LISTA"
    if [ "${DS_BT_N:-0}" -gt 0 ] && [ "${DS_SDL_N:-0}" -lt "${DS_BT_N:-0}" ]; then
        warn "hay $DS_BT_N DualSense por Bluetooth pero solo veo $DS_SDL_N utilizables:"
        warn "  Eden no esta viendo alguno (revisa Steam Input / el ajuste del acceso)."
    fi
    say ""
    case "$ESCENARIO" in
        nativo)        say "ESCENARIO: NATIVO  (Eden ve los mandos reales)" ;;
        steam_input)   say "ESCENARIO: STEAM INPUT ACTIVO  (Eden ve pads virtuales de Valve)" ;;
        steam_input_integrado) say "ESCENARIO: STEAM INPUT ACTIVO  (solo el mando integrado, como pad virtual)" ;;
        solo_integrado) say "ESCENARIO: sin DualSense -> mando integrado de la Ally" ;;
        *)             say "ESCENARIO: no se ha reconocido ningun mando utilizable" ;;
    esac
    say "Fuente de la cuenta de DualSense: $DS_FUENTE"
    case "$ESCENARIO" in
        steam_input|steam_input_integrado)
            say ""
            say "AVISO: Steam Input esta activo, asi que Eden ve pads VIRTUALES de Valve."
            if [ "${SDL_OK:-0}" -eq 1 ]; then
                say "       Aun asi, sus NOMBRES delatan que mando fisico son, y el script usa"
                say "       el puerto y guid REALES de cada uno en este mismo momento, asi que"
                say "       la asignacion es exacta (no hay que adivinar puertos)."
                say "       OJO: el orden/puertos los decide Steam y puede cambiar entre"
                say "       sesiones; por eso se recalculan en cada lanzamiento."
            else
                say "       Sin SDL no puedo saber los puertos exactos (cambian entre sesiones)."
            fi
            ;;
    esac
    avisar_custom_overrides
    say ""
    say "--- que haria ---"
    if [ -n "${PLAN_RESUMEN:-}" ]; then say "$PLAN_RESUMEN"; else say "      (nada que asignar)"; fi
    if [ -n "$EXIGIR_P1_MAC" ]; then
        say ""
        say "EXIGIR_P1_MAC=$EXIGIR_P1_MAC"
        if [ "$DS_BT_N" -gt 0 ]; then
            local primera
            primera="$(printf '%s' "$DS_BT_MACS" | awk '{print $1}')"
            if [ "$primera" = "$EXIGIR_P1_MAC" ]; then
                say "      coincide con el primer DualSense detectado: OK"
            else
                say "      NO coincide. Primer DualSense detectado: $primera"
                say "      Eden NO permite fijar por MAC; reconecta los mandos en el"
                say "      orden deseado (P1 el primero) antes de lanzar el juego."
            fi
        else
            say "      (no se han detectado DualSense por Bluetooth)"
        fi
    fi
}

# =============================================================================
#  COPIA DE SEGURIDAD / RESTAURACION
# =============================================================================
hacer_backup() { # $1 = fichero
    preparar_dirs
    local marca bak
    marca="$(date '+%Y%m%d-%H%M%S')"
    bak="$BK_DIR/qt-config.ini.$marca"
    if [ -e "$bak" ]; then
        bak="$bak.$$"
    fi
    cp -p -- "$1" "$bak" || { err "no se pudo copiar $1 a $bak"; return 1; }
    say "Copia de seguridad: $bak"
    log INFO "backup -> $bak"
    aplicar_retencion
    return 0
}

aplicar_retencion() {
    [ "${RETENCION_BACKUPS:-0}" -gt 0 ] 2>/dev/null || return 0
    local n
    n="$(ls -1 "$BK_DIR"/qt-config.ini.* 2>/dev/null | wc -l)"
    [ "$n" -le "$RETENCION_BACKUPS" ] && return 0
    ls -1t "$BK_DIR"/qt-config.ini.* 2>/dev/null | tail -n +$((RETENCION_BACKUPS + 1)) | while read -r f; do
        case "$f" in
            "$BK_DIR"/qt-config.ini.*) rm -f -- "$f" ;;
        esac
    done
    return 0
}

# El applet de mandos de Eden abre una ventana al iniciar el juego. Como N.E.C.A
# ya deja los mandos puestos, se desactiva: el juego continua sin preguntar.
applet_apagado() { # $1 = fichero
    # Eden solo usa el valor si ademas esta "\default=false"
    awk -v sec="[LibraryApplet]" '
        /^\[/ { d = ($0 == sec) }
        d && /^controller_applet_mode\\default[[:space:]]*=/ {
            v = $0; sub(/^[^=]*=/, "", v); gsub(/[[:space:]]/, "", v)
            if (v == "false") def = 1
        }
        d && /^controller_applet_mode[[:space:]]*=/ {
            v = $0; sub(/^[^=]*=/, "", v); gsub(/[[:space:]]/, "", v)
            if (v == "2") ok = 1
        }
        END { exit !(ok && def) }' "$1" 2>/dev/null
}

forzar_applet_apagado() { # $1 = fichero
    local f="$1" tmp
    [ -f "$f" ] || return 0
    applet_apagado "$f" && return 0
    tmp="$f.applet.$$"
    awk -v sec="[LibraryApplet]" '
        BEGIN { dentro = 0; puesto = 0; defp = 0; haysec = 0 }
        /^\[/ {
            if (dentro) {
                if (!puesto) { print "controller_applet_mode=2"; puesto = 1 }
                if (!defp) { print "controller_applet_mode\\default=false"; defp = 1 }
            }
            dentro = ($0 == sec)
            if (dentro) haysec = 1
            print
            next
        }
        dentro && /^controller_applet_mode\\default[[:space:]]*=/ {
            if (!defp) { print "controller_applet_mode\\default=false"; defp = 1 }
            next
        }
        dentro && /^controller_applet_mode[[:space:]]*=/ {
            if (!puesto) { print "controller_applet_mode=2"; puesto = 1 }
            next
        }
        { print }
        END {
            if (dentro) {
                if (!puesto) { print "controller_applet_mode=2"; puesto = 1 }
                if (!defp) { print "controller_applet_mode\\default=false"; defp = 1 }
            } else if (!haysec) {
                print ""
                print "[LibraryApplet]"
                print "controller_applet_mode=2"
                print "controller_applet_mode\\default=false"
            }
        }
    ' "$f" >"$tmp" || { rm -f "$tmp"; return 1; }
    mv -f -- "$tmp" "$f"
}

escribir_atomico() { # $1 = nuevo  $2 = destino
    local nuevo="$1" dst="$2" tmp
    tmp="$(dirname -- "$dst")/.eden-autoconfig.tmp.$$"
    cp -p -- "$dst" "$tmp" 2>/dev/null || { cp -- "$dst" "$tmp" 2>/dev/null || true; }
    cat -- "$nuevo" >"$tmp" || { err "no se pudo escribir $tmp"; rm -f -- "$tmp"; return 1; }
    mv -f -- "$tmp" "$dst" || { err "no se pudo mover $tmp a $dst"; return 1; }
    return 0
}

# =============================================================================
#  COMANDOS
# =============================================================================

cmd_save_template() {
    local tipo="$1" desde_perfil="${2:-}" origen="" origen_mostrar="" dst guid_real
    case "$tipo" in
        ally|dualsense) ;;
        *) err "uso: --save-template ally|dualsense [--from-profile NOMBRE]"; return 1 ;;
    esac
    preparar_dirs
    # Eden escribe qt-config.ini al cerrarse: si esta abierto, lo que hay en
    # disco puede estar desactualizado y guardariamos una plantilla vieja.
    if eden_en_ejecucion; then
        warn "Eden parece estar en ejecucion."
        warn "  Cierra Eden (que guarde la configuracion) y vuelve a intentarlo,"
        warn "  o la plantilla podria salir desactualizada."
    fi

    # origen
    if [ -n "$desde_perfil" ]; then
        origen="$(perfil_path "$desde_perfil" || true)"
        [ -n "${origen:-}" ] || { err "no encuentro el perfil '$desde_perfil' en $(config_dir_de "${QC:-/dev/null}")/input"; return 5; }
        origen_mostrar="$origen"
        say "Origen: perfil '$desde_perfil' -> $origen"
    else
        origen="${QC_LF:-$QC}"
        [ -r "$origen" ] || { err "no encuentro qt-config.ini"; return 4; }
        say "Origen: qt-config.ini -> $QC"
        origen_mostrar="$QC"
        # extraer solo el bloque player_0
        awk '
            /^\[/ { i = ($0 == "[Controls]"); next }
            i && index($0, "player_0_") == 1 { print }
        ' "$origen" >"$TMPDIR_RUN/tpl.tmp" 2>/dev/null
        origen="$TMPDIR_RUN/tpl.tmp"
        if ! grep -qE '^player_0_' "$origen" 2>/dev/null; then
            err "no hay bloque player_0_ en [Controls] de $QC"
            return 5
        fi
    fi

    dst="$TMPDIR_RUN/normalizada.txt"
    if ! normalizar_origen "$origen" "$dst"; then
        err "el origen no parece una plantilla valida ($origen)"; return 5
    fi

    guid_real="$(guid_de_plantilla "$dst")"
    # avisos de coherencia
    case "$tipo" in
        dualsense)
            if [ -n "${guid_real:-}" ]; then
                case "$guid_real" in
                    *4c05*) : ;;
                    *) warn "el guid guardado ($guid_real) NO parece de Sony (054c). ¿Seguro que es un DualSense?"
                       [ "$FORCE" -eq 1 ] || { err "usa --force si estas seguro"; return 5; } ;;
                esac
            fi
            ;;
        ally)
            if [ -n "${guid_real:-}" ]; then
                case "$guid_real" in
                    *4c05*) warn "el guid guardado ($guid_real) SÍ parece de DualSense: puede que no sea el integrado" ;;
                esac
            fi
            ;;
    esac

    dst_final="$(plantilla_path "$tipo")"
    {
        printf '# eden-autoconfig - plantilla: %s\n' "$tipo"
        printf '# origen : %s\n' "$origen_mostrar"
        printf '# fecha  : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf '# guid   : %s\n' "${guid_real:-<ninguno>}"
        printf '# Las lineas player_0_* de aqui se clonan en cada jugador cambiando\n'
        printf '# el prefijo y el port:N. NO edites esto a mano si no es necesario.\n'
    } >"$dst_final"
    cat -- "$dst" >>"$dst_final"
    chmod 600 "$dst_final" 2>/dev/null || true
    say "Plantilla guardada: $dst_final  (guid ${guid_real:-?})"
    log INFO "plantilla guardada $tipo -> $dst_final guid=${guid_real:-?}"
    return 0
}

cmd_restore() {
    local cual="${1:-latest}" origen
    preparar_dirs
    if [ "$cual" = "latest" ]; then
        origen="$(ls -1t "$BK_DIR"/qt-config.ini.* 2>/dev/null | head -n 1)"
    else
        if [ -e "$BK_DIR/qt-config.ini.$cual" ]; then
            origen="$BK_DIR/qt-config.ini.$cual"
        else
            origen="$(ls -1t "$BK_DIR"/qt-config.ini.* 2>/dev/null | sed -n "${cual}p")"
        fi
    fi
    [ -n "${origen:-}" ] && [ -r "$origen" ] || { err "no encuentro copia de seguridad (¿--list-backups?)"; return 1; }
    grep -q '^\[Controls\]' "$origen" || { err "$origen no parece un qt-config.ini valido"; return 1; }
    [ -n "${QC:-}" ] && [ -r "$QC" ] || { err "no encuentro el qt-config.ini destino"; return 4; }
    warn "voy a SOBRESCRIBIR $QC con $origen"
    hacer_backup "$QC" || return 1
    escribir_atomico "$origen" "$QC" || return 1
    say "Restaurado: $origen -> $QC"
    log INFO "restore $origen -> $QC"
    return 0
}

cmd_list_backups() {
    preparar_dirs
    if ls -1 "$BK_DIR"/qt-config.ini.* >/dev/null 2>&1; then
        ls -la "$BK_DIR"/qt-config.ini.* 2>/dev/null
    else
        say "(no hay copias de seguridad todavia)"
    fi
    return 0
}

cmd_aplicar() { # $1 = 0 aplicar, 1 dry-run
    local solo_preview="$1"
    local nuevo="$TMPDIR_RUN/qt-config.ini.new"

    if eden_en_ejecucion; then
        err "Eden esta en ejecucion. Cierralo y vuelve a intentarlo."
        err "(Eden podria sobrescribir los cambios al salir.)"
        log WARN "abortado: Eden en ejecucion"
        return 3
    fi

    if [ "${PLAN_CALCULADO:-0}" -eq 0 ]; then
        PLAN_CALCULADO=1
        if ! planificar; then
            say "Nada que hacer: no hay mandos utilizables (ni DualSense ni integrado)."
            log INFO "nada que hacer: sin mandos"
            return 2
        fi
    fi
    [ -n "${PLAN_JUGADORES:-}" ] || return 2

    # comprobacion de plantillas necesarias
    FUENTE_DS=""; FUENTE_INT=""
    case " $PLAN_JUGADORES " in
        *" dual:"*)
            FUENTE_DS="$(resolver_fuente dualsense || true)"
            [ -n "${FUENTE_DS:-}" ] || {
                err "no encuentro plantilla 'dualsense' ni el perfil '$PERFIL'."
                err "Ejecuta:  $PROG --save-template dualsense"
                return 5
            }
            ;;
    esac
    case " $PLAN_JUGADORES " in
        *" integrado:"*)
            FUENTE_INT="$(resolver_fuente ally || true)"
            [ -n "${FUENTE_INT:-}" ] || {
                err "no encuentro plantilla 'ally'."
                err "Ejecuta:  $PROG --save-template ally   (con el mando integrado configurado en Eden)"
                return 5
            }
            ;;
    esac

    # Avisa si el guid de una plantilla NO aparece en la configuracion actual.
# Sintoma clasico: la plantilla se guardo con el pad virtual de Steam (o por
# USB) y ahora el mando real usa otro guid -> "no responde nada en el juego".
avisar_guid_no_visto() { # $1 = tipo, $2 = fichero plantilla
    local tipo="$1" f="$2" g
    g="$(guid_de_plantilla "$f")"
    [ -n "${g:-}" ] || return 0
    # si la configuracion actual no tiene ningun binding, no hay nada que comparar
    grep -q 'guid:' "${QC_LF:-$QC}" 2>/dev/null || return 0
    if grep -q "guid:$g" "${QC_LF:-$QC}" 2>/dev/null; then
        return 0
    fi
    warn "el guid de la plantilla '$tipo' ($g) no aparece en tu qt-config.ini."
    warn "  -> suele significar que la plantilla es de otro modo de conexion"
    warn "     (USB vs Bluetooth) o de otro estado de Steam Input."
    warn "     Si los mandos no responden en el juego: configura ese mando en"
    warn "     Eden (Ajustes > Controles) y ejecuta  $PROG --save-template $tipo"
    log WARN "guid de plantilla $tipo ($g) ausente en el qt-config.ini"
    return 0
}

# Si la plantilla no es la guardada sino el perfil, avisamos del guid:
    # el perfil lleva *el* guid con el que se guardo y podria no ser el del
    # mando de destino.
    local tpl_guardada g tipo_aviso f
    for tipo_aviso in dualsense ally; do
        f=""
        case "$tipo_aviso" in
            dualsense) f="$FUENTE_DS" ;;
            ally)      f="$FUENTE_INT" ;;
        esac
        [ -n "${f:-}" ] || continue
        tpl_guardada="$(plantilla_path "$tipo_aviso")"
        if [ "$f" != "$tpl_guardada" ]; then
            g="$(guid_de_plantilla "$f")"
            warn "plantilla '$tipo_aviso' tomada del perfil '$PERFIL' (guid ${g:-?})"
            warn "  -> si el mando real no usa ese guid, ejecuta:  $PROG --save-template $tipo_aviso"
            log WARN "plantilla $tipo_aviso desde perfil, guid=${g:-?}"
        fi
        avisar_guid_no_visto "$tipo_aviso" "$f"
    done

    if [ -n "$EXIGIR_P1_MAC" ] && [ "$DS_BT_N" -gt 0 ]; then
        local primera
        primera="$(printf '%s' "$DS_BT_MACS" | awk '{print $1}')"
        if [ "$primera" != "$EXIGIR_P1_MAC" ]; then
            warn "EXIGIR_P1_MAC=$EXIGIR_P1_MAC pero el primer DualSense es $primera"
            warn "Eden no permite fijar por MAC: P1 sera $primera"
            if [ "$AVISAR_SIN_NEGOCIAR" = "1" ]; then
                err "AVISAR_SIN_NEGOCIAR=1 -> no aplico cambios"
                return 1
            fi
        fi
    fi

    montar_fichero "$nuevo" || { err "fallo al generar el fichero"; return 1; }
    validar_salida "$nuevo" "${QC_LF:-$QC}" || { err "la validacion ha fallado; NO se toca el original"; return 1; }

    local applet_cambia=0
    if ! applet_apagado "${QC_LF:-$QC}"; then applet_cambia=1; fi
    forzar_applet_apagado "$nuevo" || warn "no he podido desactivar el applet de mandos"

    if [ "${RESUMEN_MOSTRADO:-0}" -eq 0 ]; then
        say "--- resumen ---"
        say "$PLAN_RESUMEN"
        say ""
    fi

    # Cambios de CONTENIDO (ignorando el orden de las lineas: Eden/QSettings
    # reordena las claves al guardar, asi que el orden es irrelevante).
    awk '/^\[/{i=($0=="[Controls]")} i && /^player_/' "${QC_LF:-$QC}" | sort >"$TMPDIR_RUN/lp.orig"
    awk '/^\[/{i=($0=="[Controls]")} i && /^player_/' "$nuevo" | sort >"$TMPDIR_RUN/lp.new"
    comm -23 "$TMPDIR_RUN/lp.orig" "$TMPDIR_RUN/lp.new" >"$TMPDIR_RUN/lp.del"
    comm -13 "$TMPDIR_RUN/lp.orig" "$TMPDIR_RUN/lp.new" >"$TMPDIR_RUN/lp.add"

    say "--- cambios ---"
    if [ "$applet_cambia" -eq 1 ]; then
        say "applet de mandos de Eden: se desactiva (no volvera a preguntar)"
    fi
    if [ ! -s "$TMPDIR_RUN/lp.del" ] && [ ! -s "$TMPDIR_RUN/lp.add" ] \
       && [ "$applet_cambia" -eq 0 ]; then
        say "(sin cambios de contenido: el fichero ya estaba correcto)"
        if [ "$solo_preview" -eq 0 ]; then
            say "No hace falta escribir nada."
            log INFO "sin cambios"
            return 0
        fi
    else
        say "lineas de jugador que desaparecen/cambian: $(grep -c '' "$TMPDIR_RUN/lp.del" 2>/dev/null || echo 0)"
        say "lineas de jugador nuevas:                  $(grep -c '' "$TMPDIR_RUN/lp.add" 2>/dev/null || echo 0)"
        if [ "$VERBOSE" -eq 1 ]; then
            sed 's/^/  - /' "$TMPDIR_RUN/lp.del"
            sed 's/^/  + /' "$TMPDIR_RUN/lp.add"
        else
            say "(usa --dry-run --verbose para verlas)"
        fi
    fi

    if [ "$VERBOSE" -eq 1 ] && diff -u --label "antes: $QC" --label "despues" \
            "${QC_LF:-$QC}" "$nuevo" >"$TMPDIR_RUN/diff.txt" 2>&1; then
        say "(el fichero generado es identico al actual)"
    elif [ "$VERBOSE" -eq 1 ]; then
        say ""
        say "--- diff completo (incluye movimientos de linea) ---"
        cat -- "$TMPDIR_RUN/diff.txt"
    fi

    if [ "$solo_preview" -eq 1 ]; then
        local preview="$BASE_DIR/preview/qt-config.ini.new"
        mkdir -p "$BASE_DIR/preview" 2>/dev/null
        cp -- "$nuevo" "$preview" 2>/dev/null && say ""
        say "PREVIEW (dry-run): fichero generado en $preview"
        say "No se ha modificado $QC"
        log INFO "dry-run ok, preview en $preview"
        return 0
    fi

    hacer_backup "$QC" || return 1
    escribir_atomico "$nuevo" "$QC" || return 1
    if applet_apagado "$QC"; then
        log INFO "applet de mandos: desactivado (controller_applet_mode=2)"
    else
        log WARN "applet de mandos: NO se pudo desactivar"
    fi
    say ""
    say "OK: $QC actualizado."
    log INFO "aplicado. plan: $PLAN_JUGADORES ; version=$VERSION hash=$HASH escenario=$ESCENARIO ds_sdl=$DS_SDL_N ds_bt=$DS_BT_N virt=$VIRT_N"
    # linea unica, util tambien con --quiet (aparece en el log de ES-DE)
    printf '%s: %s | escenario=%s | DualSense(SDL)=%s DualSense(BT)=%s virtuales=%s\n' \
        "$PROG" "$(printf '%s' "$PLAN_JUGADORES" | sed 's/^ //')" "$ESCENARIO" \
        "$DS_SDL_N" "$DS_BT_N" "$VIRT_N" >&2
    return 0
}

# Muestra la lista de mandos TAL COMO los ve Eden (via SDL), con su clasificacion.
cmd_mandos() {
    say "$PROG v$VERSION -- mandos segun SDL"
    say ""
    if [ "${SDL_OK:-0}" -ne 1 ]; then
        err "no he podido obtener la lista de mandos desde SDL."
        err "Prueba a mano para ver el error completo:"
        err "  bash ${HERE}/eden-mandos-sdl.sh --verbose"
        return 1
    fi
    say "Modo de los mandos : ${MODO_RED:-?}"
    say "Escenario          : ${ESCENARIO:-?}"
    [ -n "${SDL_INFO:-}" ] && say "libSDL3 usada      : $SDL_INFO"
    [ -n "${SDL_ORIGEN:-}" ] && say "origen             : $SDL_ORIGEN"
    say ""
    printf '%-28s %-34s %-6s %-4s %-9s %s\n' NOMBRE GUID PUERTO TIPO SERIE CLASE
    printf '%-28s %-34s %-6s %-4s %-9s %s\n' ------ ---- ------ ---- ----- -----
    local nombre guid port tipo esgp sdlname serial cat
    while IFS='|' read -r nombre guid port tipo esgp sdlname serial _indice; do
        [ -n "${nombre:-}" ] || continue
        case "$nombre" in '#'*) continue ;; esac
        cat="$(clasificar_sdl "$nombre" "$guid")"
        printf '%-28s %-34s %-6s %-4s %-9s %s\n' "$nombre" "${guid:0:34}" "${port:-?}" "${tipo:-?}" "${serial:-?}" "$cat"
    done <"${SDL_LISTA:-/dev/null}"
    say ""
    say "Clases: dualsense = se asigna a P1..PN | integrado = solo si no hay DualSense"
    say "        steam_virtual = pad virtual sin identificar | otro = no se usa"
    say ""
    say "Se asignaria:"
    if [ -n "${PLAN_RESUMEN:-}" ]; then say "$PLAN_RESUMEN"; else say "      (nada que asignar)"; fi
    return 0
}

cmd_who() {
    say "Prediccion de asignacion (Eden identifica por guid+puerto, no por MAC):"
    if [ -n "${PLAN_RESUMEN:-}" ]; then say "$PLAN_RESUMEN"; else say "  (nada)"; fi
    say ""
    if [ "$DS_BT_N" -gt 0 ]; then
        say "DualSense por Bluetooth, en el orden aproximado de puerto 0,1,2,3:"
        local i=0 m
        for m in $DS_BT_MACS; do
            say "  port $i -> $m"
            i=$((i + 1))
        done
        say ""
        say "NOTA: es una APROXIMACION (el orden de BlueZ no tiene por que ser el"
        say "      que use SDL/Eden). La comprobacion definitiva esta en Eden:"
        say "      Ajustes > Controles, donde cada mando aparece como"
        say "      'Wireless Controller 0', 'Wireless Controller 1', etc."
        say "      Para fijar quien es P1 de forma estable:"
        say "        a) Steam Input ACTIVADO + reordenar los mandos en Steam (se recuerda), o"
        say "        b) conectar primero (y mantener) el DualSense que quieres como P1."
    fi
    return 0
}

usage() {
    cat <<EOF
$PROG v$VERSION - configura automaticamente los mandos de Eden

USO
  $PROG [opciones]                 aplica la configuracion
  $PROG --status                   muestra deteccion y plan (no cambia nada)
  $PROG --dry-run                  genera y compara, sin escribir
  $PROG --mandos                   lista los mandos TAL COMO los ve Eden (SDL)
  $PROG --who                      quien sera P1/P2/... (con MACs)
  $PROG --save-template TIPO       guarda plantilla (TIPO = dualsense | ally)
       [--from-profile NOMBRE]     usa directamente ese perfil de Eden
  $PROG --restore [latest|N]       restaura la ultima (o la N-esima) copia
  $PROG --list-backups             lista copias de seguridad
  $PROG --help

OPCIONES
  --quiet          silencio (solo errores)
  --verbose        detalle (incluye diff completo en --dry-run)
  --force          continua aunque haya avisos de coherencia de plantilla
  --integrado MODO ignorar | primero | ultimo   (por defecto: ignorar)
  --max N          numero maximo de DualSense a asignar (1..4)
  --perfil NOMBRE  perfil de Eden a clonar (por defecto: emudeck)
  --config RUTA    ruta explicita a qt-config.ini

FICHEROS
  config : $CONF_FILE (opcional; variables del script)
  log    : $LOG_FILE
  plant. : $TPL_DIR/dualsense.player0.txt , $TPL_DIR/ally.player0.txt
  copias : $BK_DIR/

PRIMER USO
  1) En Eden -> Ajustes -> Controles: con un DualSense conectado, carga el
     perfil 'emudeck' para el Player 1 y pulsa OK.
  2) $PROG --save-template dualsense
  3) Repite con el mando integrado de la Ally (sin DualSense conectados):
     carga el perfil 'emudeck' para el Player 1, OK y
     $PROG --save-template ally
  4) $PROG --status   y despues prueba con:  $PROG --dry-run --verbose
EOF
}

# =============================================================================
#  ARGUMENTOS
# =============================================================================
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --status) MODO="status" ;;
            --dry-run|--dryrun) MODO="dryrun" ;;
            --who) MODO="who" ;;
            --asumir-integrado) ASUMIR_INTEGRADO=1 ;;
            --mandos) MODO="mandos" ;;
            --save-template)
                MODO="save-template"
                shift || { err "--save-template necesita un valor"; exit 1; }
                TEMPLATE_TIPO="${1:-}" ;;
            --from-profile)
                shift || { err "--from-profile necesita un valor"; exit 1; }
                TEMPLATE_DESDE_PERFIL="${1:-}" ;;
            --restore)
                MODO="restore"
                if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then shift; RESTORE_ARG="$1"; else RESTORE_ARG="latest"; fi ;;
            --list-backups) MODO="list-backups" ;;
            --quiet|-q) QUIET=1 ;;
            --verbose|-v) VERBOSE=1 ;;
            --force) FORCE=1 ;;
            --integrado)
                shift || { err "--integrado necesita un valor"; exit 1; }
                ORDEN_INTEGRADO="${1:-}" ;;
            --max)
                shift || { err "--max necesita un valor"; exit 1; }
                JUGADORES_MAX="${1:-4}" ;;
            --perfil)
                shift || { err "--perfil necesita un valor"; exit 1; }
                PERFIL="${1:-}" ;;
            --config)
                shift || { err "--config necesita un valor"; exit 1; }
                EDEN_CONFIG="${1:-}" ;;
            --help|-h) MODO="help" ;;
            *) err "opcion no reconocida: $1 (usa --help)"; exit 1 ;;
        esac
        shift
    done
    TEMPLATE_TIPO="${TEMPLATE_TIPO:-}"
    TEMPLATE_DESDE_PERFIL="${TEMPLATE_DESDE_PERFIL:-}"
    RESTORE_ARG="${RESTORE_ARG:-latest}"
    case "$ORDEN_INTEGRADO" in
        ignorar|primero|ultimo) ;;
        *) err "valor invalido para --integrado: $ORDEN_INTEGRADO (ignorar|primero|ultimo)"; exit 1 ;;
    esac
    case "$JUGADORES_MAX" in
        ''|*[!0-9]*) err "valor invalido para --max: $JUGADORES_MAX"; exit 1 ;;
    esac
    [ "$JUGADORES_MAX" -ge 1 ] && [ "$JUGADORES_MAX" -le 4 ] || { err "--max debe estar entre 1 y 4"; exit 1; }
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
    preparar_dirs
    rotar_log

    # config del usuario (si existe)
    if [ -r "$CONF_FILE" ]; then
        # shellcheck disable=SC1090
        . "$CONF_FILE" 2>/dev/null || warn "no he podido leer $CONF_FILE"
    fi
    parse_args "$@"

    if [ "$MODO" = "help" ]; then usage; exit 0; fi

    TMPDIR_RUN="$(mktemp -d "$BASE_DIR/.tmp.XXXXXX" 2>/dev/null || true)"
    [ -n "$TMPDIR_RUN" ] || { err "no puedo crear directorio temporal en $BASE_DIR"; exit 1; }

    tomar_lock

    log INFO "=== $PROG v$VERSION modo=$MODO args='$*' ==="

    # localizar config de Eden
    if [ -n "$EDEN_CONFIG" ] && [ ! -r "$EDEN_CONFIG" ]; then
        err "la ruta indicada en --config/EDEN_CONFIG no existe o no es legible:"
        err "  $EDEN_CONFIG"
        exit 4
    fi
    QC="$(localizar_qconfig || true)"
    if [ -z "${QC:-}" ] && [ "$MODO" != "restore" ] && [ "$MODO" != "list-backups" ]; then
        err "no encuentro el qt-config.ini de Eden."
        err "Busca tu mismo con:"
        err "  find \"\$HOME\" -maxdepth 5 -name qt-config.ini -ipath '*eden*'"
        err "y pasalo con:  $PROG --config RUTA"
        # pistas utiles
        for c in "$HOME/.config/eden/qt-config.ini" "$HOME/.local/share/eden/config/qt-config.ini"; do
            [ -e "$c" ] && say "  (existe pero sin [Controls]: $c)"
        done
        exit 4
    fi
    [ -n "${QC:-}" ] && log INFO "qt-config.ini = $QC"

    # Se lee SIEMPRE desde una copia normalizada a LF ($QC_LF), para que las
    # comparaciones de seccion funcionen aunque el fichero tuviera CRLF.
    # Se escribe siempre en $QC. Eden (QSettings en Linux) usa LF, asi que en
    # la practica esto no cambia nada.
    QC_LF="$QC"
    if [ -n "${QC:-}" ] && grep -q "$(printf '\r')" "$QC" 2>/dev/null; then
        QC_LF="$TMPDIR_RUN/qt-config.ini.lf"
        tr -d '\r' <"$QC" >"$QC_LF" 2>/dev/null || QC_LF="$QC"
        log INFO "el qt-config.ini contenia CRLF; se trabaja sobre una copia en LF"
        [ "$MODO" = "aplicar" ] || [ "$MODO" = "dryrun" ] && \
            say "Nota: el qt-config.ini tiene finales de linea CRLF; se normalizan a LF."
    fi

    case "$MODO" in
        save-template) cmd_save_template "$TEMPLATE_TIPO" "$TEMPLATE_DESDE_PERFIL"; exit $? ;;
        restore)       cmd_restore "$RESTORE_ARG"; exit $? ;;
        list-backups)  cmd_list_backups; exit 0 ;;
    esac

    # el resto necesita deteccion
    if [ -n "${QC:-}" ]; then
        INDICES="$(indices_jugador "${QC_LF:-$QC}" | tr '\n' ' ')"
        INDICES="${INDICES% }"
        local maxidx=-1 idx
        for idx in $INDICES; do [ "$idx" -gt "$maxidx" ] && maxidx="$idx"; done
        if [ "$maxidx" -lt 0 ]; then
            warn "el qt-config.ini no define ningun player_N_; asumo 10 jugadores (0..9)"
            N_TOTALES=10
            INDICES="0 1 2 3 4 5 6 7 8 9"
        else
            N_TOTALES=$((maxidx + 1))
        fi
        log INFO "jugadores definidos en el fichero: N_TOTALES=$N_TOTALES INDICES='$INDICES'"
    fi

    detectar_mandos
    log INFO "deteccion: escenario=$ESCENARIO ds_sdl=$DS_SDL_N ds_bt=$DS_BT_N virt=$VIRT_N integrado=$INTEGRADO_N"

    case "$MODO" in
        status)
            say "$PROG v$VERSION"
            PLAN_CALCULADO=1
            planificar || true
            RESUMEN_MOSTRADO=1
            mostrar_estado
            exit 0
            ;;
        who)
            # El panel pide --who cada 5 s: no inundar log.txt.
            LOG_QUIET=1
            planificar || true
            cmd_who
            exit 0
            ;;
        mandos)
            planificar || true
            cmd_mandos
            exit $?
            ;;
        dryrun)
            say "$PROG v$VERSION (dry-run)"
            PLAN_CALCULADO=1
            planificar || true
            RESUMEN_MOSTRADO=1
            mostrar_estado
            say ""
            cmd_aplicar 1
            exit $?
            ;;
        aplicar)
            cmd_aplicar 0
            exit $?
            ;;
    esac
}

# main() lo llama el despachador (eden-autoconfig.sh)
