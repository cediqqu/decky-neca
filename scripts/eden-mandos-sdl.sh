#!/usr/bin/env bash
# =============================================================================
#  eden-mandos-sdl.sh  --  lista los mandos TAL COMO los ve SDL (y Eden)
# =============================================================================
#  Eden usa SDL3 para los mandos. Este ayudante carga una libSDL3 y pregunta
#  por los dispositivos, obteniendo para cada uno: el NOMBRE que muestra Eden,
#  el GUID y el PUERTO (que es lo que Eden guarda en qt-config.ini), y el tipo.
#
#  Por que hace falta: cuando Steam Input esta activo (habitual al lanzar desde
#  ES-DE), Eden NO ve los mandos nativos: ve los pads VIRTUALES de Steam (guid
#  de Valve) "disfrazados" con el nombre del mando fisico. Leer /sys no sirve
#  para saber eso: hay que preguntarle a SDL. Ademas los PUERTOS cambian entre
#  sesiones, asi que hay que leerlos en el momento de lanzar el juego.
#
#  IMPORTANTE: los GUIDs tienen que ser los MISMOS que calcula Eden. Distintas
#  versiones de SDL meten un CRC distinto en los bytes 2-3 del GUID, y entonces
#  Eden no encuentra el dispositivo. Aqui se usa la SDL del sistema y se pone
#  ese CRC a cero, que es como lo calcula la SDL de Eden (verificado con los
#  GUIDs reales que Eden escribe: 050000004c05... y 03000000de28...).
#
#  De donde saca la libSDL3 (en este orden):
#     1) $EDEN_SDL_LIB (+ $EDEN_SDL_LIB_DIR), si lo defines
#     2) una copia del AppImage de Eden, si existe (en ~/eden-autoconfig/sdl/)
#     3) la del sistema ("libSDL3.so.0" / "libSDL3.so")  <-- lo normal
#
#  OJO: la SDL que lleva Eden dentro calcula el CRC del GUID a 0; la del sistema
#  mete el de verdad. Por eso con la del sistema se normaliza el CRC
#  (SDL_CRC_CERO=si), que deja los GUIDs exactamente como los espera Eden.
#
#  CEMU: guarda el GUID con el CRC real. Para el se usa:
#     SDL_FUENTE=sistema SDL_GUID_MODO=cemu
#  (la SDL del sistema sin normalizar; ademas el PUERTO se cuenta solo entre
#   gamepads, que es como lo cuenta Cemu).
#
#  Uso:
#     bash eden-mandos-sdl.sh              # lista los mandos
#     bash eden-mandos-sdl.sh --verbose    # con detalles de la lib usada
#     bash eden-mandos-sdl.sh --copiar     # copia libSDL3 del AppImage de Eden
#                                          # (lo lanza un momento y lo cierra)
#     bash eden-mandos-sdl.sh --refrescar  # vuelve a extraer/copiar la lib
#     bash eden-mandos-sdl.sh --limpiar    # borra la cache de ~/eden-autoconfig/sdl
#
#  Salida (una linea por mando, separada por "|"):
#     NOMBRE_EDEN|GUID|PUERTO|TIPO|ES_GAMEPAD|NOMBRE_SDL|SERIE
#     (PUERTO = "n-esimo mando con ese GUID", lo que guarda Eden)
#  La primera linea empieza por "#" e indica la lib y su version.
#  NO modifica nada del sistema.
# =============================================================================

set -u

BASE_DIR="${EDEN_AUTOCONFIG_DIR:-$HOME/eden-autoconfig}"
SDL_DIR="$BASE_DIR/sdl"
HERE="$(cd -- "$(dirname -- "$0")" && pwd -P 2>/dev/null || echo "$PWD")"
EDEN_APPIMAGE="${EDEN_APPIMAGE:-}"
EDEN_SDL_LIB="${EDEN_SDL_LIB:-}"
EDEN_SDL_LIB_DIR="${EDEN_SDL_LIB_DIR:-}"

VERBOSE=0
MODO_COPIAR=0
case "${1:-}" in
    --verbose|-v) VERBOSE=1 ;;
    --copiar)     MODO_COPIAR=1 ;;
    --refrescar)  rm -f "$SDL_DIR/.ok" "$SDL_DIR/lib.sel" 2>/dev/null ;;
    --limpiar)
        case "$SDL_DIR" in
            "$HOME"/*) [ -n "$SDL_DIR" ] && rm -rf -- "$SDL_DIR" && echo "borrado: $SDL_DIR" ;;
            *) echo "no borro $SDL_DIR (no esta bajo \$HOME)" >&2; exit 1 ;;
        esac
        exit 0 ;;
    --help|-h) sed -n '2,32p' "$0"; exit 0 ;;
esac

log() { [ "$VERBOSE" -eq 1 ] && printf '[sdl] %s\n' "$*" >&2; return 0; }

mkdir -p "$SDL_DIR" 2>/dev/null || { echo "no puedo crear $SDL_DIR" >&2; exit 1; }

# -------------------------------------------------------------------- python
PY=""
for c in python3 python; do
    command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }
done
[ -n "$PY" ] || { echo "no encuentro python (ni python3)" >&2; exit 1; }

DUMP_PY="$SDL_DIR/dump.py"
cat >"$DUMP_PY" <<'PYEOF'
# -*- coding: utf-8 -*-
# Lista los mandos via libSDL3 (la misma que usa Eden), sin abrir dispositivos.
import ctypes, os, sys

class SDL_GUID(ctypes.Structure):
    _fields_ = [("data", ctypes.c_uint8 * 16)]

SDL_INIT_JOYSTICK = 0x00000200
SDL_INIT_GAMEPAD  = 0x00002000

# Los mismos hints que pone Eden (los que afectan a como se ve cada mando)
HINTS = [
    ("SDL_JOYSTICK_HIDAPI_XBOX", "0"),
    ("SDL_JOYSTICK_HIDAPI_STEAM", "1"),
    ("SDL_JOYSTICK_HIDAPI_JOY_CONS", "1"),
    ("SDL_JOYSTICK_HIDAPI_SWITCH", "1"),
    ("SDL_JOYSTICK_ENHANCED_REPORTS", "1"),
    ("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1"),
]
# Nombres que da Eden segun el tipo de SDL (su funcion GetControllerName)
TIPOS = {2: "Xbox 360 Controller", 3: "Xbox One Controller", 4: "DualShock 3 Controller",
         5: "DualShock 4 Controller", 6: "DualSense Controller"}

lib = os.environ.get("SDL_LIB") or "libSDL3.so.0"
try:
    sdl = ctypes.CDLL(lib)
except OSError as e:
    sys.stderr.write("no puedo cargar %s: %s\n" % (lib, e))
    sys.exit(2)

def set_sig(name, restype=None, argtypes=None):
    f = getattr(sdl, name)
    if restype is not None: f.restype = restype
    if argtypes is not None: f.argtypes = argtypes
    return f

try:
    set_sig("SDL_SetHint", ctypes.c_bool, [ctypes.c_char_p, ctypes.c_char_p])
    set_sig("SDL_InitSubSystem", ctypes.c_bool, [ctypes.c_uint32])
    set_sig("SDL_GetError", ctypes.c_char_p, [])
    set_sig("SDL_PumpEvents", None, [])
    set_sig("SDL_GetJoysticks", ctypes.POINTER(ctypes.c_uint32), [ctypes.POINTER(ctypes.c_int)])
    set_sig("SDL_GetJoystickGUIDForID", SDL_GUID, [ctypes.c_uint32])
    set_sig("SDL_GetJoystickNameForID", ctypes.c_char_p, [ctypes.c_uint32])
    set_sig("SDL_IsGamepad", ctypes.c_bool, [ctypes.c_uint32])
    set_sig("SDL_GetGamepadTypeForID", ctypes.c_int, [ctypes.c_uint32])
    set_sig("SDL_GetGamepadNameForID", ctypes.c_char_p, [ctypes.c_uint32])
except AttributeError as e:
    sys.stderr.write("esta libSDL3 no expone la API esperada: %s\n" % e)
    sys.exit(3)

# El numero de serie es OPCIONAL: si la lib no lo soporta, se sigue igual.
# Ojo: SDL3 no tiene SDL_GetJoystickSerialForID; hay que abrir el mando.
_get_serial_forid = None
_open_js = None
_get_serial = None
_close_js = None
for _n, _t, _a in (("SDL_GetJoystickSerialForID", ctypes.c_char_p, [ctypes.c_uint32]),
                   ("SDL_OpenJoystick", ctypes.c_void_p, [ctypes.c_uint32]),
                   ("SDL_GetJoystickSerial", ctypes.c_char_p, [ctypes.c_void_p]),
                   ("SDL_CloseJoystick", None, [ctypes.c_void_p])):
    try:
        _f = getattr(sdl, _n)
        if _t is not None:
            _f.restype = _t
        _f.argtypes = _a
        if _n == "SDL_GetJoystickSerialForID":
            _get_serial_forid = _f
        elif _n == "SDL_OpenJoystick":
            _open_js = _f
        elif _n == "SDL_GetJoystickSerial":
            _get_serial = _f
        else:
            _close_js = _f
    except Exception:
        pass

# version de la lib (para poder comparar con la que trae Eden).
# En SDL3: int SDL_GetVersion(void) y el valor es major*1000000+minor*1000+patch
version = "?"
try:
    set_sig("SDL_GetVersion", ctypes.c_int, [])
    v = int(sdl.SDL_GetVersion())
    if v > 0:
        version = "%d.%d.%d" % (v // 1000000, (v // 1000) % 1000, v % 1000)
except Exception:
    pass
sys.stdout.write("#lib %s version %s\n" % (lib, version))

for k, v in HINTS:
    try:
        sdl.SDL_SetHint(k.encode(), v.encode())
    except Exception:
        pass

if not sdl.SDL_InitSubSystem(SDL_INIT_JOYSTICK | SDL_INIT_GAMEPAD):
    err = (sdl.SDL_GetError() or b"")
    sys.stderr.write("SDL_InitSubSystem fallo: %s\n" % err.decode(errors="replace"))
    sys.exit(4)

def pump():
    try: sdl.SDL_PumpEvents()
    except Exception: pass
pump()
try:
    set_sig("SDL_UpdateJoysticks", None, [])
    sdl.SDL_UpdateJoysticks()
except Exception:
    pass
pump()

count = ctypes.c_int(0)
ids = sdl.SDL_GetJoysticks(ctypes.byref(count))
if not ids or count.value <= 0:
    sys.stderr.write("SDL no ve ningun mando\n")
    sys.stdout.flush()
    sys.exit(0)

def s(x):
    if not x: return ""
    if isinstance(x, bytes): return x.decode("utf-8", "replace")
    return str(x)

# La SDL que trae Eden calcula el CRC del GUID a 0; otras versiones meten un
# CRC distinto en los bytes 2-3. Con SDL_CRC_CERO=1 lo ponemos a cero para que
# el GUID sea EXACTAMENTE el que Eden espera (comprobado con sus guids reales:
# 050000004c05... y 03000000de28...). El resto de bytes ya coincide.
crc_cero = os.environ.get("SDL_CRC_CERO", "0").lower() in ("1", "si", "sí", "yes", "true")
# Cemu cuenta el "n-esimo con este guid" solo entre gamepads (SDL_GetGamepads).
solo_gp = os.environ.get("SDL_PUERTO_GAMEPADS", "0").lower() in ("1", "si", "sí", "yes", "true")

puertos = {}   # guid -> cuantos llevamos (asi calcula Eden el "port")
for i in range(count.value):
    jid = ids[i]
    try:
        g = sdl.SDL_GetJoystickGUIDForID(jid)
        datos = list(g.data)
        if crc_cero:
            datos[2] = 0
            datos[3] = 0
        guid = "".join("%02x" % b for b in datos)
        nombre_sdl = s(sdl.SDL_GetJoystickNameForID(jid))
        es_gp = bool(sdl.SDL_IsGamepad(jid))
        tipo = 0
        nombre_gp = ""
        if es_gp:
            tipo = int(sdl.SDL_GetGamepadTypeForID(jid))
            nombre_gp = s(sdl.SDL_GetGamepadNameForID(jid))
        # El nombre es EXACTAMENTE el que muestra Eden en el desplegable
        if tipo in TIPOS:
            nombre = TIPOS[tipo]
        elif es_gp and nombre_gp:
            nombre = nombre_gp
        else:
            nombre = nombre_sdl
        # numero de serie (en un DualSense por BT es su MAC). Opcional y a
        # prueba de fallos: si la lib no lo da, se queda vacio.
        serial = ""
        try:
            if _get_serial_forid is not None:
                serial = s(_get_serial_forid(jid))
            elif _open_js is not None and _get_serial is not None:
                _js = _open_js(jid)
                if _js:
                    serial = s(_get_serial(_js))
                    if _close_js is not None:
                        _close_js(_js)
        except Exception:
            serial = ""
        p = puertos.get(guid, 0)
        if es_gp or not solo_gp:
            puertos[guid] = p + 1
        out = [nombre, guid, str(p), str(tipo), "1" if es_gp else "0",
               nombre_sdl, serial]
        sys.stdout.write("|".join(x.replace("|", " ").replace("\n", " ") for x in out) + "\n")
    except Exception as e:
        sys.stderr.write("aviso: fallo leyendo el mando %d: %s\n" % (i, e))
sys.stdout.flush()
PYEOF

# ------------------------------------------------------------------ AppImage
localizar_appimage() {
    [ -n "$EDEN_APPIMAGE" ] && [ -x "$EDEN_APPIMAGE" ] && { printf '%s' "$EDEN_APPIMAGE"; return 0; }
    local f
    for f in "$HOME"/Applications/*[Ee]den*.AppImage "$HOME"/AppImages/*[Ee]den*.AppImage \
             "$HOME"/*[Ee]den*.AppImage; do
        [ -x "$f" ] && { printf '%s' "$f"; return 0; }
    done
    if command -v find >/dev/null 2>&1; then
        f="$(find "$HOME" -maxdepth 5 -type f -iname '*eden*.appimage' -perm -u+x \
             -not -path '*/.cache/*' 2>/dev/null | head -n 1)"
        [ -n "$f" ] && { printf '%s' "$f"; return 0; }
    fi
    return 1
}

extraer_sdl() {  # ultimo recurso: saca libSDL3 del AppImage
    local appim pat ya
    appim="$(localizar_appimage)" || { log "no encuentro el AppImage"; return 1; }
    log "AppImage: $appim"
    if [ -e "$SDL_DIR/squashfs-root" ]; then
        mv -f "$SDL_DIR/squashfs-root" "$SDL_DIR/squashfs-root.$(date +%s)" 2>/dev/null
    fi
    for pat in 'usr/lib/libSDL3*' 'usr/lib*/libSDL3*' '*libSDL3*'; do
        log "extrayendo patron: $pat"
        ( cd "$SDL_DIR" && "$appim" --appimage-extract "$pat" >/dev/null 2>&1 ) || true
        ya="$(find "$SDL_DIR/squashfs-root" -maxdepth 6 -type f -name 'libSDL3.so*' 2>/dev/null | head -n 1)"
        [ -n "$ya" ] && { log "extraida: $ya"; return 0; }
    done
    # si el patron no funciono, extraccion completa (tarda un poco, una sola vez)
    log "patrones sin exito; extraccion completa"
    ( cd "$SDL_DIR" && "$appim" --appimage-extract >/dev/null 2>&1 ) || true
    ya="$(find "$SDL_DIR/squashfs-root" -maxdepth 6 -type f -name 'libSDL3.so*' 2>/dev/null | head -n 1)"
    [ -n "$ya" ] && { log "extraida (completa): $ya"; return 0; }
    log "no hay libSDL3 dentro del AppImage (¿enlace estatico?)"
    return 1
}

# ------------------------------------------------------- probar candidatos
ejecutar_dump() { # $1 = SDL_LIB, $2 = dir (opcional), $3 = crc_cero (1/0)
    local crc="${3:-0}"
    # permite forzarlo desde el .conf (SDL_CRC_CERO=si|no)
    case "${SDL_CRC_CERO:-}" in
        si|sí|1|yes|true) crc=1 ;;
        no|0|false)       crc=0 ;;
    esac
    # Cemu cuenta el PUERTO solo entre gamepads (ver cabecera)
    local gp="${SDL_PUERTO_GAMEPADS:-0}"
    [ "${SDL_GUID_MODO:-eden}" = "cemu" ] && gp=1
    if [ -n "${2:-}" ]; then
        LD_LIBRARY_PATH="$2${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        SDL_LIB="$1" SDL_CRC_CERO="$crc" SDL_PUERTO_GAMEPADS="$gp" \
        "$PY" "$DUMP_PY"
    else
        SDL_LIB="$1" SDL_CRC_CERO="$crc" SDL_PUERTO_GAMEPADS="$gp" \
        "$PY" "$DUMP_PY"
    fi
}

# Devuelve TODOS los PID relacionados con Eden: el lanzador del AppImage, el
# proceso "dwarfs" que lo monta y el binario real. Excluye nuestros scripts y
# cualquier otra cosa que solo mencione "eden" (p.ej. un editor con un fichero
# de este proyecto abierto).
pids_de_eden() {
    pgrep -af . 2>/dev/null \
        | grep -iE 'eden' \
        | grep -Ev 'eden-mandos-sdl|eden-autoconfig|eden-diagnostico|eden_controller|kate|sftp|pgrep|grep ' \
        | awk '{print $1}'
}

# Compatibilidad: primer PID (puede ser el lanzador, no el binario real).
pid_de_eden() { pids_de_eden | head -n 1; }

# Posibles raices del AppImage para un proceso. Devuelve una por linea.
#
# El AppImage de Eden (fs "dwarfs") monta sus ficheros en /tmp/.mount_XXXX
# DENTRO DE SU PROPIO NAMESPACE: desde nuestro shell esa ruta no existe. Por eso
# se prueban las dos formas:
#   1) la ruta tal cual (por si el montaje fuese visible)
#   2) /proc/<pid>/root + la ruta   <- esto entra en el namespace del proceso
#   3) globs de montajes/extracciones dentro de su namespace
raices_de_pid() { # $1 = pid
    local p="$1" exe base
    exe="$(readlink "/proc/$p/exe" 2>/dev/null || echo '')"
    [ -n "$exe" ] || return 1
    case "$exe" in
        *.AppImage) return 1 ;;          # es el lanzador; no lleva la lib dentro
    esac
    base=""
    case "$exe" in
        */usr/bin/*) base="${exe%%/usr/bin/*}" ;;
        */bin/*)     base="${exe%%/bin/*}" ;;
        */sbin/*)    base="${exe%%/sbin/*}" ;;
    esac
    [ -n "$base" ] || return 1
    printf '%s\n' "$base"
    printf '/proc/%s/root%s\n' "$p" "$base"
    printf '/proc/%s/root/tmp/.mount_*\n' "$p"
    printf '/proc/%s/root/tmp/appimage_*\n' "$p"
    return 0
}

# Cierra SOLO los procesos del AppImage (nunca editores ni otros programas).
cerrar_eden_lanzado() { # $@ = pids
    local p exe
    for p in "$@"; do
        exe="$(readlink "/proc/$p/exe" 2>/dev/null || true)"
        case "$exe" in
            *.AppImage|/tmp/.mount_*|/tmp/appimage_*) kill "$p" 2>/dev/null ;;
        esac
    done
    return 0
}

# Copia la libSDL3 desde el AppImage de Eden EN EJECUCION. Es la unica forma de
# tener EXACTAMENTE la misma SDL que Eden (y por tanto los mismos GUIDs).
copiar_del_montaje() {
    local appim pid pids p r rr f n=0 lanzado=0
    appim="$(localizar_appimage)" || { echo "no encuentro el AppImage de Eden" >&2; return 1; }

    pid="$(pid_de_eden)"
    if [ -z "$pid" ]; then
        echo "Abriendo Eden un momento para copiar su libSDL3..." >&2
        "$appim" >/dev/null 2>&1 &
        lanzado=1
        local i
        for i in $(seq 1 60); do
            sleep 0.5
            pid="$(pid_de_eden)"
            [ -n "$pid" ] && break
        done
    fi
    if [ -z "$pid" ]; then
        echo "Eden no ha arrancado en 30 s. Abrelo a mano y repite este comando." >&2
        return 1
    fi
    sleep 4   # dejar que arranque el binario real

    pids="$(pids_de_eden)"
    : >"$SDL_DIR/.raices"
    for p in $pids; do
        raices_de_pid "$p" >>"$SDL_DIR/.raices" 2>/dev/null || true
    done
    log "pids: $(printf '%s' "$pids" | tr '\n' ' ')"

    while IFS= read -r r; do
        [ -n "$r" ] || continue
        # shellcheck disable=SC2086
        for rr in $r; do      # expande posibles globs
            [ -d "$rr" ] || continue
            log "probando raiz: $rr"
            find "$rr" -maxdepth 5 \( -type f -o -type l \) -name 'libSDL3.so*' 2>/dev/null >"$SDL_DIR/.libs"
            while IFS= read -r f; do
                [ -n "$f" ] || continue
                if cp -fL -- "$f" "$SDL_DIR/" 2>/dev/null; then
                    log "copiada: $f"
                    n=$((n + 1))
                fi
            done <"$SDL_DIR/.libs"
            [ "$n" -gt 0 ] && break 2
        done
    done <"$SDL_DIR/.raices"

    if [ "$lanzado" -eq 1 ]; then
        sleep 1
        # shellcheck disable=SC2086
        cerrar_eden_lanzado $pids
    fi

    if [ "$n" -eq 0 ]; then
        echo "no encuentro libSDL3 dentro del AppImage de Eden." >&2
        echo "Raices probadas (solo las que existen):" >&2
        while IFS= read -r r; do
            # shellcheck disable=SC2086
            for rr in $r; do
                [ -d "$rr" ] || continue
                echo "  $rr" >&2
                echo "    contenido: $(ls "$rr" 2>/dev/null | head -n 8 | tr '\n' ' ')" >&2
                [ -d "$rr/lib" ] && echo "    lib/: $(ls "$rr/lib" 2>/dev/null | head -n 8 | tr '\n' ' ')" >&2
            done
        done <"$SDL_DIR/.raices"
        echo "(si no aparece ninguna libSDL3, Eden lleva SDL estatica: dimelo)" >&2
        return 1
    fi
    chmod 644 "$SDL_DIR"/libSDL3.so* 2>/dev/null
    return 0
}


lista_candidatos() {
    local fuente="${SDL_FUENTE:-auto}"
    # 1) forzada por el usuario
    [ -n "$EDEN_SDL_LIB" ] && printf '%s|%s\n' "$EDEN_SDL_LIB" "$EDEN_SDL_LIB_DIR"
    # 2) copia del AppImage de Eden (mismos guids que Eden) salvo que se pida
    #    expresamente la del sistema
    local ya
    if [ "$fuente" != "sistema" ]; then
        for ya in "$SDL_DIR"/libSDL3.so*; do
            [ -f "$ya" ] && printf '%s|%s\n' "$(basename -- "$ya")" "$SDL_DIR"
        done
    fi
    # 3) la del sistema (guids sin normalizar; la que usa Cemu)
    [ "$fuente" != "appimage" ] && printf 'libSDL3.so.0|\nlibSDL3.so|\n'
    return 0
}

intentar_candidatos() {
    local cand lib dir out rc
    while IFS='|' read -r lib dir; do
        [ -n "${lib:-}" ] || continue
        log "probando libSDL3: ${lib}${dir:+ (dir $dir)}"
        # la del AppImage de Eden -> guids exactos; la del sistema -> CRC a cero
        if [ "$dir" = "$SDL_DIR" ]; then crc=0; else crc=1; fi
        # Cemu guarda el GUID con el CRC real: no se normaliza nunca
        [ "${SDL_GUID_MODO:-eden}" = "cemu" ] && crc=0
        out="$(ejecutar_dump "$lib" "$dir" "$crc" 2>"$SDL_DIR/.err")"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            printf '%s|%s\n' "$lib" "$dir" >"$SDL_DIR/lib.sel"
            local origen
            if [ "$dir" = "$SDL_DIR" ]; then origen="AppImage de Eden"
            elif [ -z "$dir" ] && [ "${SDL_GUID_MODO:-eden}" = "cemu" ]; then
                origen="sistema (guid real, formato Cemu)"
            elif [ -z "$dir" ]; then origen="sistema (CRC normalizado a 0 = guids de Eden)"
            else origen="otra ($dir)"; fi
            printf '%s\n' "$out"
            printf '#origen %s\n' "$origen"
            return 0
        fi
        log "  fallo (exit $rc): $(tr '\n' ' ' <"$SDL_DIR/.err" 2>/dev/null | cut -c1-160)"
    done < <(lista_candidatos)
    return 1
}

# --- modo --copiar: copiar la libSDL3 desde el AppImage de Eden -------------
if [ "$MODO_COPIAR" -eq 1 ]; then
    if copiar_del_montaje; then
        echo "libSDL3 copiada en $SDL_DIR:"
        ls -la "$SDL_DIR"/libSDL3.so* 2>/dev/null
        if intentar_candidatos >/dev/null; then
            echo "y funciona correctamente."
            exit 0
        fi
        echo "copiada, pero no he podido usarla. Prueba: bash $0 --verbose" >&2
        exit 1
    fi
    exit 1
fi

# Gancho de pruebas: mismo formato que la salida real (sin libSDL3).
if [ -n "${EDEN_FAKE_SDL:-}" ] && [ -r "$EDEN_FAKE_SDL" ]; then
    echo "#lib falsa (EDEN_FAKE_SDL)"
    cat "$EDEN_FAKE_SDL"
    exit 0
fi

log "python: $PY"
if intentar_candidatos; then
    exit 0
fi

# ultimo recurso: extraer del AppImage y volver a intentar
if extraer_sdl; then
    if intentar_candidatos; then
        exit 0
    fi
fi

echo "no he podido cargar ninguna libSDL3." >&2
echo "Probado: \$EDEN_SDL_LIB, copia del AppImage y sistema (libSDL3.so.0/.so)." >&2
if [ -s "$SDL_DIR/.err" ]; then
    echo "Ultimo error:" >&2
    sed 's/^/  /' "$SDL_DIR/.err" | head -n 5 >&2
fi
echo "Si sabes donde esta, indicamela asi:" >&2
echo "  EDEN_SDL_LIB=libSDL3.so.0 EDEN_SDL_LIB_DIR=/ruta/a/la/carpeta bash $0 --verbose" >&2
exit 1
