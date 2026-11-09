#!/usr/bin/env bash
# =============================================================================
#  eden-diagnostico.sh  --  SOLO LECTURA
# =============================================================================
#  Recoge toda la información necesaria para configurar Eden (fork de Yuzu)
#  y los mandos en una SteamOS / ROG Ally X.
#
#  NO ESCRIBE NADA. Solo lee ficheros y ejecuta consultas de solo lectura
#  (cat, ls, grep, find, bluetoothctl info, pgrep...).
#
#  Uso:
#     bash eden-diagnostico.sh
#     bash eden-diagnostico.sh > diagnostico.txt 2>&1     # guardar y pegar
#
#  Tarda unos segundos (consulta Bluetooth). Si algo no existe, lo dice.
# =============================================================================

set -u
set -o pipefail

# ------------------------------------------------------------------ utilidades
SEC_N=0
sec() {
    SEC_N=$((SEC_N + 1))
    printf '\n\n'
    printf '=====================================================================\n'
    printf '== %02d. %s\n' "$SEC_N" "$*"
    printf '=====================================================================\n'
}
sub() { printf '\n--- %s\n' "$*"; }
say() { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# cat que no se queja si no existe / no se puede leer
trycat() {
    local f
    for f in "$@"; do
        if [ -r "$f" ]; then
            say "### cat $f"
            cat -- "$f" 2>/dev/null
        else
            say "### (no existe o no legible): $f"
        fi
    done
}

# imprime info de un fichero: ruta, tamaño, permisos, fecha
finfo() {
    local f="$1"
    if [ -e "$f" ]; then
        local modo fecha tam
        modo="$(stat -c '%A %U:%G' "$f" 2>/dev/null || echo '?')"
        fecha="$(stat -c '%y' "$f" 2>/dev/null || echo '?')"
        tam="$(stat -c '%s' "$f" 2>/dev/null || echo '?')"
        printf '  [OK]   %-70s %s bytes  %s  %s\n' "$f" "$tam" "$modo" "$fecha"
    else
        printf '  [--]   %s\n' "$f"
    fi
}

# elimina el prefijo $HOME por legibilidad
short() { printf '%s' "${1#"$HOME"\//}"; }

# /sys/class/input/input* ordenado NUMERICAMENTE por el sufijo.
# (El glob normal se expande alfabeticamente: input10 antes que input2.)
# El orden numerico es el de registro del kernel, la mejor aproximacion al
# orden en que SDL enumera los mandos.
lista_inputs_sysfs() {
    ls -1d /sys/class/input/input[0-9]* 2>/dev/null \
        | awk -F'input' '{print $NF" "$0}' | sort -n | cut -d' ' -f2-
}

# =============================================================================
sec "ENTORNO"
# =============================================================================
say "fecha           : $(date '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null)"
say "hostname        : $(hostname 2>/dev/null)"
say "usuario         : $(id -un 2>/dev/null)  (uid $(id -u 2>/dev/null))"
say "HOME            : $HOME"
say "SHELL           : ${SHELL:-?}"
say "XDG_CONFIG_HOME : ${XDG_CONFIG_HOME:-<no definido>}"
say "XDG_DATA_HOME   : ${XDG_DATA_HOME:-<no definido>}"
say "uname           : $(uname -srm 2>/dev/null)"
say "bash            : ${BASH_VERSION:-?}"
sub "os-release"
trycat /etc/os-release
sub "herramientas disponibles"
for h in bash sed awk grep find bluetoothctl bluetoothd pgrep flock stat md5sum xdg-user-dir; do
    if have "$h"; then say "  [OK] $h -> $(command -v "$h")"; else say "  [--] $h"; fi
done
say "awk implementa: $(awk -W version 2>&1 | head -n 1)"

# =============================================================================
sec "EDEN: APPIMAGE"
# =============================================================================
say "Buscando AppImages de Eden en sitios habituales..."
for d in "$HOME/Applications" "$HOME/AppImages" "$HOME/Emulation" "$HOME/Emulation/tools" \
         "$HOME/Emulation/tools/launchers" "$HOME/.local/share" "$HOME/.local/bin" \
         "$HOME/Downloads" "$HOME/Descargas" "/opt" "$HOME/Desktop"; do
    [ -d "$d" ] || continue
    # shellcheck disable=SC2012
    for f in "$d"/*[Ee]den*.AppImage "$d"/*[Ee]den*.appimage; do
        [ -e "$f" ] || continue
        finfo "$f"
        say "        ejecutable: $([ -x "$f" ] && echo si || echo NO)"
    done
done
sub "busqueda global (maxdepth 5 en \$HOME)"
if have find; then
    find "$HOME" -maxdepth 5 -type f \( -iname 'eden*.appimage' -o -iname '*eden*.appimage' \) \
        -not -path '*/.cache/*' 2>/dev/null | while read -r f; do finfo "$f"; done
fi

# =============================================================================
sec "EDEN: LANZADOR DE EMUDECK"
# =============================================================================
LAUNCH_DIR="$HOME/Emulation/tools/launchers"
sub "listado de $LAUNCH_DIR"
if [ -d "$LAUNCH_DIR" ]; then
    ls -la "$LAUNCH_DIR" 2>/dev/null
else
    say "(no existe $LAUNCH_DIR)"
    say "Buscando otros directorios 'launchers':"
    find "$HOME" -maxdepth 4 -type d -name launchers 2>/dev/null | head -n 10
fi
sub "contenido de los .sh de eden"
if [ -d "$LAUNCH_DIR" ]; then
    for f in "$LAUNCH_DIR"/*eden* "$LAUNCH_DIR"/*Eden*; do
        [ -f "$f" ] || continue
        say "### $f"
        cat -- "$f" 2>/dev/null
        say ""
    done
fi

# =============================================================================
sec "EDEN: RUTA DE qt-config.ini"
# =============================================================================
say "Candidatos (en orden de preferencia):"
CANDIDATOS=(
    "$HOME/.config/eden/qt-config.ini"
    "$HOME/.config/Eden/qt-config.ini"
    "$HOME/.local/share/eden/config/qt-config.ini"
    "$HOME/.local/share/eden/qt-config.ini"
    "$HOME/.var/app/dev.eden.Eden/config/eden/qt-config.ini"
    "$HOME/.config/yuzu/qt-config.ini"
    "$HOME/.config/citron/qt-config.ini"
    "$HOME/.config/suyu/qt-config.ini"
)
for c in "${CANDIDATOS[@]}"; do finfo "$c"; done

sub "modo portable (carpeta 'user' junto al AppImage)"
if have find; then
    find "$HOME" -maxdepth 5 -type d -name user -path '*[Ee]den*' 2>/dev/null | head -n 10 | while read -r d; do
        say "  carpeta portable: $d"
        finfo "$d/config/qt-config.ini"
        finfo "$d/config/input"
    done
fi

sub "cualquier qt-config.ini bajo rutas con 'eden' (maxdepth 5)"
if have find; then
    find "$HOME" -maxdepth 5 -type f -name 'qt-config.ini' -ipath '*eden*' \
        -not -path '*/.cache/*' 2>/dev/null | head -n 20 | while read -r f; do finfo "$f"; done
fi

sub "directorio de datos de Eden"
for d in "$HOME/.local/share/eden" "$HOME/.config/eden" "$HOME/.config/Eden"; do
    if [ -d "$d" ]; then
        say "### ls -la $d"
        ls -la "$d" 2>/dev/null
    fi
done

# =============================================================================
sec "EDEN: PERFILES DE MANDO (input/*.ini)  <-- aqui vive el perfil 'emudeck'"
# =============================================================================
say "Los perfiles de Eden/Yuzu se guardan en <config>/input/<nombre>.ini"
say "El perfil 'emudeck' que instala EmuDeck deberia estar aqui."
for d in "$HOME/.config/eden/input" "$HOME/.config/Eden/input" \
         "$HOME/.local/share/eden/config/input" "$HOME/.config/yuzu/input"; do
    sub "$d"
    if [ -d "$d" ]; then
        ls -la "$d" 2>/dev/null
        for f in "$d"/*.ini; do
            [ -f "$f" ] || continue
            say ""
            say "### contenido de $f"
            cat -- "$f" 2>/dev/null
        done
    else
        say "(no existe)"
    fi
done

sub "configs por juego: ¿sobrescriben [Controls]?"
say "Si alguno de estos .ini tiene seccion [Controls] con claves player_N_*,"
say "EDEN IGNORARA el [Controls] global PARA ESE JUEGO y habra que tocarlo tambien."
for d in "$HOME/.config/eden/custom" "$HOME/.local/share/eden/config/custom" \
         "$HOME/.config/eden/config/custom"; do
    [ -d "$d" ] || continue
    say ""
    say "### ls -la $d"
    ls -la "$d" 2>/dev/null
    for f in "$d"/*.ini; do
        [ -f "$f" ] || continue
        say ""
        say "--- $f"
        guid_juego="$(basename "$f" .ini)"
        say "    (title id: $guid_juego)"
        if grep -q '^\[Controls\]' "$f" 2>/dev/null; then
            say "    !!! TIENE SECCION [Controls]:"
            grep -n '^\[Controls\]' "$f"
            say "    !!! claves de jugador dentro de esa seccion:"
            awk '/^\[/{i=($0=="[Controls]")} i && /^player_[0-9]+_/ {print "        "$0}' "$f" | head -n 40
            n_jug="$(awk '/^\[/{i=($0=="[Controls]")} i && /^player_[0-9]+_connected=/ {n++} END{print n+0}' "$f")"
            say "    !!! jugadores definidos ahi: $n_jug"
        else
            say "    (sin seccion [Controls]: no afecta a los mandos)"
        fi
        say "    resto de secciones:"
        grep -n '^\[' "$f" | head -n 20 | sed 's/^/      /'
        # claves player_* fuera de [Controls] (p.ej. player_select_applet_mode)
        otras="$(grep -nE '^player_' "$f" 2>/dev/null | grep -vE '^[0-9]+:player_[0-9]+_' | head -n 5)"
        if [ -n "$otras" ]; then
            say "    (otras claves 'player_' que NO son de mandos, ignorar):"
            printf '%s\n' "$otras" | sed 's/^/      /'
        fi
    done
    # configs de mando por juego: Eden tambien admite input profiles por juego
    for sub2 in "$d"/*/; do
        [ -d "$sub2" ] && say "  (subcarpeta: $sub2)"
    done
done

# =============================================================================
sec "EDEN: SECCION [Controls] COMPLETA"
# =============================================================================
QC=""
for c in "${CANDIDATOS[@]}"; do
    if [ -r "$c" ] && grep -q '^\[Controls\]' "$c" 2>/dev/null; then QC="$c"; break; fi
done
if [ -z "$QC" ] && have find; then
    QC="$(find "$HOME" -maxdepth 5 -type f -name 'qt-config.ini' -ipath '*eden*' \
          -not -path '*/.cache/*' 2>/dev/null | while read -r f; do
              grep -q '^\[Controls\]' "$f" 2>/dev/null && { printf '%s' "$f"; break; }
          done)"
fi

if [ -z "$QC" ]; then
    say "!! No se ha encontrado ningun qt-config.ini de Eden con seccion [Controls]."
else
    say "Usando: $QC"
    say ""
    awk '
        /^\[/ { insec = ($0 == "[Controls]") }
        insec { print }
    ' "$QC"
fi

# =============================================================================
sec "RESUMEN de [Controls]: jugadores"
# =============================================================================
if [ -n "$QC" ]; then
    printf '%-8s %-12s %-6s %-12s %s\n' JUGADOR CONNECTED TYPE PUERTO GUI
    awk '
        /^\[/ { insec = ($0 == "[Controls]") }
        !insec { next }
        /^player_[0-9]+_connected=/ {
            n=$0; sub(/^player_/,"",n); sub(/_connected=.*/,"",n);
            c=$0; sub(/.*=/,"",c); conn[n]=c;
        }
        /^player_[0-9]+_type=/ {
            n=$0; sub(/^player_/,"",n); sub(/_type=.*/,"",n);
            t=$0; sub(/.*=/,"",t); type[n]=t;
        }
        /^player_[0-9]+_.*guid:/ {
            # extrae el guid y el port de la primera clave con binding
            n=$0; sub(/^player_/,"",n); sub(/_.*/,"",n);
            if (!seen[n]++) {
                g=$0; if (match(g, /guid:[0-9a-fA-F]+/)) guid[n]=substr(g, RSTART+5, RLENGTH-5);
                if (match($0, /port:[0-9]+/)) port[n]=substr($0, RSTART+5, RLENGTH-5);
            }
        }
        END {
            for (i=0; i<20; i++) {
                if (!(i in conn) && !(i in type)) continue;
                printf "%-8s %-12s %-6s %-12s %s\n", "player_" i, \
                    (i in conn ? conn[i] : "?"), (i in type ? type[i] : "?"), \
                    (i in port ? port[i] : "-"), (i in guid ? guid[i] : "-");
            }
        }
    ' "$QC"

    sub "GUIDs distintos que aparecen en [Controls]"
    grep -o 'guid:[0-9a-fA-F]*' "$QC" 2>/dev/null | sort | uniq -c | sort -rn | head -n 20

    sub "pistas de interpretacion de GUID (vendor en little-endian)"
    say "  ...4c05...  -> vendor 054c = SONY   (DualSense real)"
    say "  ...de28...  -> vendor 28de = VALVE  (Steam Virtual Gamepad / mando interno Steam)"
    say "  ...050b...  -> vendor 0b05 = ASUS   (mando integrado de la Ally, probable)"
    say "  ...5e04...  -> vendor 045e = Microsoft (pad XInput / xpad)"
fi

# =============================================================================
sec "MANDOS: BLUETOOTH"
# =============================================================================
if have bluetoothctl; then
    sub "bluetoothctl --version"
    bluetoothctl --version 2>&1 | head -n 3
    sub "bluetoothctl devices Connected"
    ( bluetoothctl devices Connected 2>&1 | head -n 40 )
    sub "bluetoothctl devices (todos)"
    ( bluetoothctl devices 2>&1 | head -n 60 )
    sub "info de cada dispositivo emparejado (Name / Connected / Icon)"
    for mac in $(bluetoothctl devices 2>/dev/null | awk '{print $2}' | head -n 20); do
        say "--- $mac"
        bluetoothctl info "$mac" 2>/dev/null \
            | grep -E '^\s*(Name|Alias|Connected|Trusted|Paired|Icon|Class|UUID)' \
            | head -n 20
    done
else
    say "(bluetoothctl no disponible)"
fi

# =============================================================================
sec "MANDOS: DISPOSITIVOS DE ENTRADA (sysfs)"
# =============================================================================
say "Recorrido de /sys/class/input/input* ordenado NUMERICAMENTE (orden de registro del kernel)"
printf '%-10s %-38s %-22s %-20s %-6s %-6s\n' SYSFS HANDLERS NOMBRE UNIQ VEND PROD
printf '%-10s %-38s %-22s %-20s %-6s %-6s\n' -------- -------- ------ ---- ---- ----
for din in $(lista_inputs_sysfs); do
    [ -d "$din" ] || continue
    nombre="$(cat "$din/name" 2>/dev/null || echo '?')"
    uniqv="$(cat "$din/uniq" 2>/dev/null || echo '')"
    vend="$(cat "$din/id/vendor" 2>/dev/null || echo '?')"
    prod="$(cat "$din/id/product" 2>/dev/null || echo '?')"
    handlers=""
    for h in "$din"/event* "$din"/js*; do
        [ -e "$h" ] || continue
        handlers="$handlers $(basename "$h")"
    done
    printf '%-10s %-38s %-20s %-8s %-8s %s\n' "$(basename "$din")" "$handlers" "$nombre" "$uniqv" "$vend" "$prod"
done

sub "/proc/bus/input/devices (solo Name/Vendor/Product/Uniq/Handlers)"
if [ -r /proc/bus/input/devices ]; then
    grep -E '^(N|I|P|U|H):' /proc/bus/input/devices 2>/dev/null | head -n 120
fi

sub "nodos joystick"
ls -la /dev/input/js* 2>/dev/null || say "(no hay /dev/input/js*)"
sub "nodos event"
ls -la /dev/input/event* 2>/dev/null | head -n 40

# =============================================================================
sec "DETECCION PROVISIONAL (lo que decidiria eden-autoconfig.sh)"
# =============================================================================
# Misma logica que el script principal, en version reducida.
DS_SDL=0
DS_MACS_SDL=""
VIRT=0
INTEGRADO=0
INTEGRADO_NOM=""
AUX=0
OTROS=""

# Igual que eden-autoconfig.sh: el ORDEN de estas comprobaciones importa.
for din in $(lista_inputs_sysfs); do
    [ -d "$din" ] || continue
    nombre="$(cat "$din/name" 2>/dev/null || echo '')"
    uniqv="$(cat "$din/uniq" 2>/dev/null || echo '')"
    vend="$(cat "$din/id/vendor" 2>/dev/null || echo '')"
    prod="$(cat "$din/id/product" 2>/dev/null || echo '')"
    handlers=""
    for h in "$din"/event* "$din"/js*; do
        [ -e "$h" ] || continue
        handlers="$handlers $(basename "$h")"
    done
    handlers="${handlers# }"
    tiene_js=0; tiene_km=0
    for h in $handlers; do
        case "$h" in js[0-9]*) tiene_js=1 ;; kbd|mouse[0-9]*) tiene_km=1 ;; esac
    done
    nl="$(printf '%s' "$nombre" | tr '[:upper:]' '[:lower:]')"

    case "$nl" in
        *touchpad*|*"motion sensors"*|*"consumer control"*|*keyboard*|*mouse*|*"video bus"*|\
        *"power button"*|*"sleep button"*|*"pc speaker"*|*"hd-audio"*|*"lid switch"*|*sensors*)
            AUX=$((AUX + 1)); continue ;;
    esac
    case "$nl" in
        *"wireless controller"*|*dualsense*)
            DS_SDL=$((DS_SDL + 1)); DS_MACS_SDL="$DS_MACS_SDL $uniqv"; continue ;;
    esac
    # teclados/ratones sin nodo js: NO son mandos (steamos-manager, N-KEY...)
    if [ "$tiene_js" -eq 0 ] && [ "$tiene_km" -eq 1 ]; then
        AUX=$((AUX + 1)); continue
    fi
    case "$vend" in
        054c) DS_SDL=$((DS_SDL + 1)); DS_MACS_SDL="$DS_MACS_SDL $uniqv"; continue ;;
    esac
    case "$nl" in
        *"steam virtual gamepad"*|*"steam controller"*|*"steam deck controller"*)
            VIRT=$((VIRT + 1)); continue ;;
    esac
    case "$vend" in
        28de) VIRT=$((VIRT + 1)); continue ;;
    esac
    case "$nl" in
        *rog*|*ally*|*asus*|*hid-asus*)
            INTEGRADO=$((INTEGRADO + 1)); INTEGRADO_NOM="$nombre"; continue ;;
    esac
    case "$vend" in
        0b05) INTEGRADO=$((INTEGRADO + 1)); INTEGRADO_NOM="$nombre"; continue ;;
    esac
    OTROS="$OTROS
    - [$vend:$prod] $nombre (handlers: ${handlers:-ninguno})"
done

DS_BT=0
DS_MACS_BT=""
if have bluetoothctl; then
    while read -r _line; do
        set -- $_line
        mac="${2:-}"
        [ -n "$mac" ] || continue
        nom="$(bluetoothctl info "$mac" 2>/dev/null | grep -m1 -E '^\s*Name:' | sed 's/.*Name: *//')"
        case "$nom" in
            *"Wireless Controller"*|*DualSense*)
                DS_BT=$((DS_BT + 1)); DS_MACS_BT="$DS_MACS_BT $mac" ;;
        esac
    done <<EOF
$(bluetoothctl devices Connected 2>/dev/null | head -n 30)
EOF
fi

say "Dispositivos auxiliares ignorados      : $AUX"
say "DualSense vistos por SDL/sysfs         : $DS_SDL   (MACs:$DS_MACS_SDL )"
say "DualSense vistos por Bluetooth         : $DS_BT   (MACs:$DS_MACS_BT )"
say "Pads virtuales de Steam (28de)         : $VIRT"
say "Candidatos a integrado de la Ally      : $INTEGRADO  ${INTEGRADO_NOM:+($INTEGRADO_NOM)}"
say "Otros dispositivos de entrada no clasificados:$OTROS"
say ""
say "Nota: los teclados/ratones y dispositivos como 'steamos-manager' o"
say "'ASUSTeK ... N-KEY Device' se cuentan como auxiliares porque NO tienen"
say "nodo /dev/input/jsN (un mando de verdad si lo tiene)."

say ""
if [ "$DS_SDL" -gt 0 ]; then
    say "=> ESCENARIO: NATIVO (Steam Input desactivado para ES-DE)."
    say "   Eden vera los DualSense directamente."
elif [ "$VIRT" -gt 0 ]; then
    say "=> ESCENARIO: STEAM INPUT ACTIVO (Eden solo ve pads virtuales de Valve)."
    say "   Los DualSense estan conectados por Bluetooth: $DS_BT"
else
    say "=> ESCENARIO: sin DualSense y sin pads virtuales."
fi
say ""
say "RECUERDA: Eden identifica por guid+puerto, NO por MAC."
say "Con varios DualSense iguales, el puerto depende del ORDEN de conexion."

# =============================================================================
sec "ES-DE: SCRIPTS DE EVENTOS"
# =============================================================================
for d in "$HOME/ES-DE/scripts" "$HOME/.emulationstation/scripts" \
         "$HOME/ES-DE/scripts/game-start" "$HOME/ES-DE/scripts/game-end"; do
    sub "$d"
    if [ -d "$d" ]; then
        ls -la "$d" 2>/dev/null
    else
        say "(no existe)"
    fi
done
sub "ajuste 'Enable custom event scripts' y rutas en es_settings.xml"
if [ -r "$HOME/ES-DE/settings/es_settings.xml" ]; then
    grep -nE 'Script|custom|event|Scripts' "$HOME/ES-DE/settings/es_settings.xml" 2>/dev/null | head -n 20
    say "(si no aparece nada, el ajuste esta a su valor por defecto = desactivado)"
else
    say "(no existe ~/ES-DE/settings/es_settings.xml)"
fi
sub "log de ES-DE: eventos de script recientes"
if [ -r "$HOME/ES-DE/logs/es_log.txt" ]; then
    grep -nE 'Scripting::fireEvent|Executing:|game-start|game-end' "$HOME/ES-DE/logs/es_log.txt" 2>/dev/null | tail -n 20
else
    say "(no existe ~/ES-DE/logs/es_log.txt)"
fi

# =============================================================================
sec "ES-DE: DEFINICION DEL SISTEMA SWITCH"
# =============================================================================
sub "custom_systems"
if [ -d "$HOME/ES-DE/custom_systems" ]; then
    ls -la "$HOME/ES-DE/custom_systems" 2>/dev/null
    for f in "$HOME/ES-DE/custom_systems"/*.xml; do
        [ -f "$f" ] || continue
        say ""
        say "### $f (bloque switch)"
        awk '/<system>/{buf=""} {buf=buf"\n"$0} /<\/system>/{ if (buf ~ /<name>switch<\/name>/) print buf }' "$f"
    done
else
    say "(no existe ~/ES-DE/custom_systems)"
fi
sub "es_systems.xml del propio ES-DE (bloque switch)"
for f in "$HOME/ES-DE/resources/systems/linux/es_systems.xml" \
         /usr/share/es-de/resources/systems/linux/es_systems.xml \
         /usr/local/share/es-de/resources/systems/linux/es_systems.xml; do
    [ -r "$f" ] || continue
    say "### $f"
    awk '/<system>/{buf=""} {buf=buf"\n"$0} /<\/system>/{ if (buf ~ /<name>switch<\/name>/) print buf }' "$f"
done
sub "filtro rapido: cualquier '<command' con eden/EDEN"
for f in $(find "$HOME/ES-DE" /usr/share/es-de /usr/local/share/es-de -maxdepth 6 \
               -name 'es_systems*.xml' 2>/dev/null | head -n 20); do
    grep -n -iE 'eden' "$f" 2>/dev/null | head -n 10 | sed "s#^#$(short "$f"):#"
done

# =============================================================================
sec "PROCESOS"
# =============================================================================
sub "procesos que parecen Eden"
pgrep -af . 2>/dev/null | grep -Ei 'eden|appimage|\.mount_' | grep -v 'eden-diagnostico' | head -n 20 \
    || say "(ninguno)"
sub "procesos ES-DE / Steam"
pgrep -af . 2>/dev/null | grep -Ei 'es-de|emulationstation|steam' | head -n 20 || say "(ninguno)"

# =============================================================================
sec "FIN"
# =============================================================================
say "Diagnostico completado. Copia TODA esta salida y pegala."
say ""
say "========== FIN DEL DIAGNOSTICO =========="
