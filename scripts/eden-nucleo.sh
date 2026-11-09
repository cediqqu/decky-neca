#!/usr/bin/env bash
# =============================================================================
#  eden-nucleo.sh  --  piezas compartidas por los drivers de N.E.C.A
# =============================================================================
#  Fase 0 del refactor: aqui vive lo que necesitan TODOS los drivers. De
#  momento son las rutas y la carga de preferencias comunes; el driver de Eden
#  sigue con su propia carga (no se toca para no cambiar su comportamiento).
# =============================================================================

# Carpeta de trabajo (~/eden-autoconfig) y fichero de preferencias.
nucleo_base() { printf '%s' "${EDEN_AUTOCONFIG_DIR:-$HOME/eden-autoconfig}"; }
nucleo_conf() {
    local base
    base="$(nucleo_base)"
    printf '%s' "${EDEN_AUTOCONFIG_CONF:-$base/eden-autoconfig.conf}"
}

# Carga el .conf (si existe) y deja valores por defecto coherentes con el
# driver de Eden: cuantos mandos configurar, que hacer con el integrado y que
# mando es el principal.
nucleo_prefs() {
    local conf
    conf="$(nucleo_conf)"
    if [ -r "$conf" ]; then
        # shellcheck disable=SC1090
        . "$conf" >/dev/null 2>&1 || true
    fi
    JUGADORES_MAX="${JUGADORES_MAX:-4}"
    ORDEN_INTEGRADO="${ORDEN_INTEGRADO:-primero}"
    P1_SERIE="${P1_SERIE:-}"
    DUALSENSE_PATRON="${DUALSENSE_PATRON:-*wireless controller*|*dualsense*}"
    INTEGRADO_PATRON="${INTEGRADO_PATRON:-*rog*|*ally*|*asus*|*hid-asus*|*steam deck*|*deck controller*}"
}

# Ruta al ayudante de SDL (junto a los scripts).
nucleo_helper_sdl() {
    local base
    base="$(nucleo_base)"
    if [ -r "${AQUI:-.}/eden-mandos-sdl.sh" ]; then
        printf '%s' "${AQUI:-.}/eden-mandos-sdl.sh"
    elif [ -r "$base/eden-mandos-sdl.sh" ]; then
        printf '%s' "$base/eden-mandos-sdl.sh"
    else
        return 1
    fi
}

# Compara un nombre con un patron tipo "a|b|c" (glob, sin distinguir mayusculas)
nucleo_coincide() {
    local nombre patron p
    nombre="${1,,}"
    patron="${2,,}"
    local IFS='|'
    for p in $patron; do
        # shellcheck disable=SC2254
        case "$nombre" in $p) return 0 ;; esac
    done
    return 1
}

# ---------------------------------------------------------------------------
#  Lista de mandos y plan de asignacion (para Cemu)
# ---------------------------------------------------------------------------
# Salida, una linea por gamepad:
#   NOMBRE|SDL|SERIE|INDICE|CLASE|UUID
#     CLASE = dual | integrado | otro
#     UUID  = "<puerto>_<guid>" en el dialecto pedido ($1 = eden|cemu)
# Deja SDL_OK / SDL_ERR / SDL_LIB con el resultado de interrogar a SDL.
SDL_OK=0
SDL_ERR=""
SDL_LIB=""
NUCLEO_RAW=()

nucleo_mandos() {
    NUCLEO_RAW=()
    local modo="${1:-eden}" helper out err tmp errc
    SDL_OK=0; SDL_ERR=""; SDL_LIB=""
    helper="$(nucleo_helper_sdl)" || { SDL_ERR="no encuentro eden-mandos-sdl.sh"; return 1; }
    tmp="$(mktemp "${TMPDIR:-/tmp}/eca-sdl.XXXXXX" 2>/dev/null || echo "/tmp/eca-sdl.$$")"
    if [ "$modo" = "cemu" ]; then
        out="$(SDL_FUENTE=sistema SDL_GUID_MODO=cemu bash "$helper" 2>"$tmp")"
    else
        out="$(bash "$helper" 2>"$tmp")"
    fi
    errc=$?
    err="$(head -n 1 "$tmp" 2>/dev/null | sed 's/  */ /g' | cut -c1-160)"
    rm -f "$tmp"
    if [ "$errc" -ne 0 ]; then
        SDL_ERR="${err:-error desconocido}"
        return 1
    fi
    SDL_OK=1
    SDL_LIB="$(printf '%s\n' "$out" | grep -m1 '^#lib ' | sed 's/^#lib //')"
    local idx_sdl=0
    while IFS='|' read -r nombre guid puerto tipo esgp sdl serie _indice; do
        case "$nombre" in ''|'#'*) continue ;; esac
        [ "${esgp:-0}" = "1" ] || continue
        local clase="otro" g="$guid"
        # Cemu (SDL2/HIDAPI) guarda el bus Bluetooth como 03; SDL3 lo da como
        # 05. El CRC real (bytes 2-3) no se toca.
        if [ "$modo" = "cemu" ] && [ "${g:0:2}" = "05" ]; then
            g="03${g:2}"
        fi
        # "Wireless Controller" vale para DualShock/DualSense, pero un
        # "Xbox Wireless Controller" NO es un DualSense (lo mete el patron).
        if nucleo_coincide "$nombre" "${DUALSENSE_PATRON:-*dualsense*}" \
           && ! nucleo_coincide "$nombre" "*xbox*|*x-box*"; then
            clase="dual"
        elif nucleo_coincide "$nombre" "${INTEGRADO_PATRON:-}"; then
            clase="integrado"
        fi
        NUCLEO_RAW+=("$nombre|${sdl:-$nombre}|${serie:-}|$idx_sdl|$clase|${puerto:-0}_$g")
        idx_sdl=$((idx_sdl + 1))
    done <<<"$out"

    # Si no hay integrado pero Steam expone un unico pad virtual suelto (el
    # mando de la consola), lo tratamos como integrado (igual que Eden).
    local i n2 sdl2 serie2 ind2 clase2 uuid2 guid2 hay_int=0 virt=0 idx=-1
    for i in "${!NUCLEO_RAW[@]}"; do
        IFS='|' read -r n2 sdl2 serie2 ind2 clase2 uuid2 <<<"${NUCLEO_RAW[$i]}"
        [ "$clase2" = "integrado" ] && hay_int=1
        guid2="${uuid2#*_}"
        if [ "$clase2" = "otro" ] && [ "${guid2:8:4}" = "de28" ] && [ -z "$serie2" ]; then
            virt=$((virt + 1)); idx=$i
        fi
    done
    if [ "$hay_int" -eq 0 ] && [ "$virt" -eq 1 ] && [ "$idx" -ge 0 ]; then
        IFS='|' read -r n2 sdl2 serie2 ind2 clase2 uuid2 <<<"${NUCLEO_RAW[$idx]}"
        NUCLEO_RAW[$idx]="$n2|$sdl2|$serie2|$ind2|integrado|$uuid2"
    fi
}

# Rellena el plan y todo lo necesario para explicarlo:
#   PLAN_NOMBRE/SDL/SERIE/INDICE/CLASE/UUID   -> los asignados (en orden)
#   NUCLEO_TODOS    -> todos los detectados ("nombre|sdl|serie|indice|clase|uuid")
#   NUCLEO_ASIGNADO -> 1/0 por cada uno de NUCLEO_TODOS
#   NUCLEO_FUERA    -> "nombre|motivo" de los que no entran
#   NUCLEO_AVISOS   -> avisos legibles
# Devuelve 0 si hay algo asignado, 2 si no.
nucleo_planificar() { # $1 = eden|cemu
    local modo="${1:-eden}" linea nombre sdl serie indice clase uuid
    nucleo_prefs
    PLAN_NOMBRE=(); PLAN_SDL=(); PLAN_SERIE=(); PLAN_INDICE=()
    PLAN_CLASE=(); PLAN_UUID=()
    NUCLEO_TODOS=(); NUCLEO_ASIGNADO=(); NUCLEO_FUERA=(); NUCLEO_AVISOS=()

    nucleo_mandos "$modo"
    local duales=() integrados=() otros=()
    for linea in "${NUCLEO_RAW[@]+"${NUCLEO_RAW[@]}"}"; do
        [ -n "$linea" ] || continue
        IFS='|' read -r nombre sdl serie indice clase uuid <<<"$linea"
        NUCLEO_TODOS+=("$linea")
        case "$clase" in
            dual)      duales+=("$linea") ;;
            integrado) integrados+=("$linea") ;;
            *)         otros+=("$linea") ;;
        esac
    done

    if [ "$SDL_OK" -ne 1 ]; then
        NUCLEO_AVISOS+=("no he podido interrogar a SDL: ${SDL_ERR:-sin detalle}")
        return 2
    fi
    if [ "${#NUCLEO_TODOS[@]}" -eq 0 ]; then
        NUCLEO_AVISOS+=("SDL no ve ningun mando (¿estan encendidos?)")
        return 2
    fi

    local lista=() orden_int="ultimo" incluir_int=0
    case "${ORDEN_INTEGRADO:-ignorar}" in
        ignorar) incluir_int=0 ;;
        primero) incluir_int=1; orden_int="primero" ;;
        *)       incluir_int=1; orden_int="ultimo" ;;
    esac
    # sin ningun DualSense el integrado entra siempre, y de primero
    if [ "${#duales[@]}" -eq 0 ]; then
        incluir_int=1
        orden_int="primero"
        if [ "${#integrados[@]}" -gt 0 ]; then
            NUCLEO_AVISOS+=("no hay DualSense: uso el integrado como Player 1")
        elif [ "${#otros[@]}" -gt 0 ]; then
            NUCLEO_AVISOS+=("no hay DualSense ni integrado: uso los mandos disponibles")
        fi
    elif [ "${ORDEN_INTEGRADO:-ignorar}" = "ignorar" ] && [ "${#integrados[@]}" -gt 0 ]; then
        NUCLEO_AVISOS+=("el integrado no entra (ORDEN_INTEGRADO=ignorar)")
    fi

    # ordenar cada grupo por indice SDL (orden de conexion)
    local ordenada
    if [ "${#duales[@]}" -gt 0 ]; then
        ordenada=(); while IFS= read -r linea; do ordenada+=("$linea"); done < <(
            printf '%s\n' "${duales[@]}" | sort -t'|' -k4,4n)
        duales=("${ordenada[@]}")
    fi
    if [ "${#integrados[@]}" -gt 0 ]; then
        ordenada=(); while IFS= read -r linea; do ordenada+=("$linea"); done < <(
            printf '%s\n' "${integrados[@]}" | sort -t'|' -k4,4n)
        integrados=("${ordenada[@]}")
    fi
    if [ "${#otros[@]}" -gt 0 ]; then
        ordenada=(); while IFS= read -r linea; do ordenada+=("$linea"); done < <(
            printf '%s\n' "${otros[@]}" | sort -t'|' -k4,4n)
        otros=("${ordenada[@]}")
    fi

    local tope="${JUGADORES_MAX:-4}" i
    [ "$tope" -gt 8 ] 2>/dev/null && tope=8
    [ "$tope" -lt 1 ] 2>/dev/null && tope=1

    if [ "${#duales[@]}" -gt 0 ]; then
        if [ "$incluir_int" -eq 1 ] && [ "$orden_int" = "primero" ]; then
            [ "${#integrados[@]}" -gt 0 ] && lista+=("${integrados[0]}")
            lista+=("${duales[@]}")
        else
            lista+=("${duales[@]}")
            if [ "$incluir_int" -eq 1 ] && [ "${#integrados[@]}" -gt 0 ]; then
                lista+=("${integrados[0]}")
            fi
        fi
    else
        [ "${#integrados[@]}" -gt 0 ] && lista+=("${integrados[@]}")
        [ "${#otros[@]}" -gt 0 ] && lista+=("${otros[@]}")
    fi
    [ "${#lista[@]}" -gt 0 ] || return 2

    # el principal (P1_SERIE) va primero
    if [ -n "${P1_SERIE:-}" ]; then
        local i out=()
        for i in "${!lista[@]}"; do
            IFS='|' read -r nombre sdl serie indice clase uuid <<<"${lista[$i]}"
            if [ "$serie" = "$P1_SERIE" ]; then
                out=("${lista[$i]}")
                unset 'lista[$i]'
                break
            fi
        done
        [ "${#out[@]}" -gt 0 ] && lista=("${out[@]}" "${lista[@]}")
    fi

    # Si el integrado entra y no cabe, se caen los ultimos DualSense (el
    # candidato a P4) para reservarle el ultimo hueco.
    if [ "$incluir_int" -eq 1 ] && [ "${#integrados[@]}" -gt 0 ]; then
        while [ "${#lista[@]}" -gt "$tope" ]; do
            local ultimo_ds=-1 j
            for j in "${!lista[@]}"; do
                IFS='|' read -r _n _s _se _i clase _u <<<"${lista[$j]}"
                [ "$clase" = "dual" ] && ultimo_ds=$j
            done
            [ "$ultimo_ds" -ge 0 ] || break
            unset 'lista[$ultimo_ds]'
            lista=("${lista[@]}")
        done
    fi

    for i in "${!lista[@]}"; do
        [ "$i" -lt "$tope" ] || break
        IFS='|' read -r nombre sdl serie indice clase uuid <<<"${lista[$i]}"
        PLAN_NOMBRE+=("$nombre")
        PLAN_SDL+=("$sdl")
        PLAN_SERIE+=("$serie")
        PLAN_INDICE+=("$indice")
        PLAN_CLASE+=("$clase")
        PLAN_UUID+=("$uuid")
    done

    # marcar asignados y explicar el resto
    local t dentro
    for t in "${!NUCLEO_TODOS[@]}"; do
        IFS='|' read -r nombre sdl serie indice clase uuid <<<"${NUCLEO_TODOS[$t]}"
        dentro=0
        for i in "${!PLAN_UUID[@]}"; do
            [ "${PLAN_UUID[$i]}" = "$uuid" ] && { dentro=1; break; }
        done
        NUCLEO_ASIGNADO+=("$dentro")
        if [ "$dentro" -eq 0 ]; then
            local en_lista=0 l
            for l in "${lista[@]+"${lista[@]}"}"; do
                [ "${l##*|}" = "$uuid" ] && { en_lista=1; break; }
            done
            if [ "$en_lista" -eq 1 ]; then
                NUCLEO_FUERA+=("$nombre|limite de jugadores ($tope)")
            else
                case "$clase" in
                    integrado) NUCLEO_FUERA+=("$nombre|integrado fuera (orden=ignorar)") ;;
                    otro)      NUCLEO_FUERA+=("$nombre|no es DualSense") ;;
                    *)         NUCLEO_FUERA+=("$nombre|limite de jugadores ($tope)") ;;
                esac
            fi
        fi
    done
    if [ "${#lista[@]}" -gt "$tope" ]; then
        NUCLEO_AVISOS+=("${#lista[@]} mandos detectados y solo entran $tope: sube «Mandos a configurar»")
    fi
    [ "${#PLAN_UUID[@]}" -gt 0 ] || return 2
    return 0
}

# Imprime el plan con su explicacion (para --status / --dry-run / --diagnostico)
nucleo_imprimir_plan() {
    local i
    if [ "$SDL_OK" -eq 1 ]; then
        printf 'deteccion SDL      : ok%s\n' "${SDL_LIB:+ ($SDL_LIB)}"
    else
        printf 'deteccion SDL      : ERROR: %s\n' "${SDL_ERR:-sin detalle}"
    fi
    printf 'detectados         : %d\n' "${#NUCLEO_TODOS[@]}"
    for i in "${!NUCLEO_TODOS[@]}"; do
        local nombre sdl serie indice clase uuid
        IFS='|' read -r nombre sdl serie indice clase uuid <<<"${NUCLEO_TODOS[$i]}"
        if [ "${NUCLEO_ASIGNADO[$i]:-0}" = "1" ]; then
            printf '  [ok]  %-30s %-10s %s\n' "$sdl" "$clase" "$uuid"
        else
            printf '  [--]  %-30s %-10s\n' "$sdl" "$clase"
        fi
    done
    if [ "${#PLAN_UUID[@]}" -gt 0 ]; then
        printf 'asignados          : %d\n' "${#PLAN_UUID[@]}"
        for i in "${!PLAN_UUID[@]}"; do
            printf '  Mando %d = %s  [%s]\n' "$((i + 1))" "${PLAN_SDL[$i]}" "${PLAN_CLASE[$i]}"
            printf '           uuid %s\n' "${PLAN_UUID[$i]}"
        done
    else
        printf 'asignados          : ninguno\n'
    fi
    if [ "${#NUCLEO_FUERA[@]}" -gt 0 ]; then
        printf 'fuera              :\n'
        for i in "${!NUCLEO_FUERA[@]}"; do
            printf '  - %s\n' "${NUCLEO_FUERA[$i]//|/: }"
        done
    fi
    for i in "${!NUCLEO_AVISOS[@]}"; do
        printf 'AVISO: %s\n' "${NUCLEO_AVISOS[$i]}"
    done
}

# --- registro y estado para el panel ---------------------------------------
nucleo_log() {
    local base f
    base="$(nucleo_base)"
    f="$base/log.txt"
    mkdir -p "$base" 2>/dev/null || return 0
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$f" 2>/dev/null || true
    if [ "$(wc -l <"$f" 2>/dev/null || echo 0)" -gt 800 ]; then
        tail -n 500 "$f" >"$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f" 2>/dev/null
    fi
}

# Guarda el plan en ~/eden-autoconfig/plan-<sistema>.txt para el panel.
nucleo_guardar_plan() { # $1 = sistema, $2 = modo
    local sistema="$1" modo="$2" base f i
    base="$(nucleo_base)"
    f="$base/plan-$sistema.txt"
    mkdir -p "$base" 2>/dev/null || return 0
    {
        printf 'fecha=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'sistema=%s\n' "$sistema"
        printf 'modo=%s\n' "$modo"
        printf 'max=%s\n' "${JUGADORES_MAX:-?}"
        printf 'sdl=%s\n' "$([ "$SDL_OK" -eq 1 ] && echo ok || echo error)"
        printf 'lib=%s\n' "${SDL_LIB:-}"
        printf 'detectados=%s\n' "${#NUCLEO_TODOS[@]}"
        for i in "${!PLAN_UUID[@]}"; do
            printf 'mando=%s|%s|%s\n' "$((i + 1))" "${PLAN_SDL[$i]}" "${PLAN_CLASE[$i]}"
        done
        for i in "${!NUCLEO_FUERA[@]}"; do
            printf 'fuera=%s\n' "${NUCLEO_FUERA[$i]}"
        done
        for i in "${!NUCLEO_AVISOS[@]}"; do
            printf 'aviso=%s\n' "${NUCLEO_AVISOS[$i]}"
        done
    } >"$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f" 2>/dev/null
}

# Vuelca el plan al log (una linea por cosa, facil de leer con tail)
nucleo_registrar() { # $1 = sistema, $2 = modo
    local i ver hash vf
    vf="$(nucleo_base)/VERSION"
    ver=""; hash=""
    if [ -r "$vf" ]; then
        ver="$(sed -n 's/^version:[[:space:]]*//p' "$vf" | head -n 1)"
        hash="$(sed -n 's/^hash:[[:space:]]*//p' "$vf" | head -n 1)"
    fi
    nucleo_log "$1 $2: version=${ver:-?} hash=${hash:-?} SDL=$([ "$SDL_OK" -eq 1 ] && echo ok || echo "error(${SDL_ERR:-?})") lib=${SDL_LIB:-?} detectados=${#NUCLEO_TODOS[@]} max=${JUGADORES_MAX:-?}"
    for i in "${!PLAN_UUID[@]}"; do
        nucleo_log "$1 $2: Mando $((i + 1)) = ${PLAN_SDL[$i]} [${PLAN_CLASE[$i]}] uuid=${PLAN_UUID[$i]}"
    done
    for i in "${!NUCLEO_FUERA[@]}"; do
        nucleo_log "$1 $2: fuera ${NUCLEO_FUERA[$i]}"
    done
    for i in "${!NUCLEO_AVISOS[@]}"; do
        nucleo_log "$1 AVISO: ${NUCLEO_AVISOS[$i]}"
    done
}
