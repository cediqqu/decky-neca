#!/usr/bin/env bash
# =============================================================================
#  eden-driver-dolphin.sh  --  Dolphin (GameCube / Wii)
# =============================================================================
#  EmuDeck ya deja GCPadNew.ini y WiimoteNew.ini con TODOS los bindings puestos.
#  Lo que cambia entre sesiones es el dispositivo y, para que los puertos 2-4
#  existan, dos ajustes mas que EmuDeck no deja activos:
#
#      GCPadNew.ini   [GCPadN]    Device = SDL/<indice>/<nombre>
#      WiimoteNew.ini [WiimoteN]  Device = SDL/<indice>/<nombre>
#      WiimoteNew.ini [WiimoteN]  Source = 1            (emulado)
#      Dolphin.ini    [Core]      SIDevice0..3 = 6|0    (6 = mando GC)
#      Hotkeys.ini    [Hotkeys]   Device = <jugador 1>
#
#  <indice> es el indice global de SDL (8.o campo de eden-mandos-sdl.sh) y
#  <nombre> el nombre SDL del mando. Este driver reescribe SOLO esas lineas;
#  el resto de cada fichero queda byte a byte igual.
#
#  Ojo con Dolphin: no existe una clave que apunte a un perfil, como
#  player_N_profile_name en Eden o <profile> en Cemu. La config activa es
#  GCPadNew.ini / WiimoteNew.ini; los ficheros de Profiles/ son plantillas que
#  se cargan a mano desde la interfaz. Por eso se parchea el ini activo.
#
#  Uso (normalmente a traves del despachador):
#     eden-autoconfig.sh --sistema gc
#     eden-autoconfig.sh --sistema gc --dry-run
#     eden-autoconfig.sh --sistema gc --status
#     eden-autoconfig.sh --sistema gc --restore [latest|stock|N]
#
#  Codigos de salida: 0 ok | 1 error | 2 nada que hacer | 3 Dolphin abierto |
#                     4 no encuentro la configuracion
# =============================================================================

set -u

DOLPHIN_DIRS=(
    "$HOME/.var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu"
    "$HOME/.config/dolphin-emu"
    "$HOME/.dolphin-emu"
    "$HOME/Documents/Dolphin Emulator"
)

QUIET=0
D_AVISOS=()
d_say()  { [ "$QUIET" = "1" ] && return 0; printf '%s\n' "$*"; }
d_warn() { printf 'AVISO: %s\n' "$*" >&2; }
d_err()  { printf 'ERROR: %s\n' "$*" >&2; }

# ------------------------------------------------------------------ rutas ---
d_dir() {
    local d
    for d in "${DOLPHIN_DIRS[@]}"; do
        if [ -f "$d/GCPadNew.ini" ] || [ -f "$d/WiimoteNew.ini" ]; then
            printf '%s' "$d"
            return 0
        fi
    done
    return 1
}

d_backups() {
    printf '%s/dolphin' "$(nucleo_base)/backups"
}

# Copia fija del estado anterior a N.E.C.A (la primera vez que se aplica).
d_stock() {
    printf '%s/stock' "$(d_backups)"
}

d_en_ejecucion() {
    pgrep -fa 'dolphin-emu|Dolphin\.AppImage|DolphinQt' 2>/dev/null \
        | grep -v -e pgrep -e eden-autoconfig >/dev/null
}

# ---------------------------------------------------------------- mandos ----
# La lista y el plan los pone el nucleo (igual que Eden y Cemu).
d_planificar() { nucleo_planificar eden; }

# Devuelve el valor de Device para el jugador N (1..).
# OJO: Dolphin no usa el indice global de SDL; asigna el id por nombre de
# dispositivo. Por eso se usa el n-esimo con ese mismo nombre (INDICE_NOMBRE).
d_device() {
    local n="$1"
    local i=$((n - 1))
    printf 'SDL/%s/%s' \
        "${PLAN_INDICE_NOMBRE[$i]:-${PLAN_INDICE[$i]}}" "${PLAN_SDL[$i]}"
}

d_njugadores() { printf '%s' "${#PLAN_NOMBRE[@]}"; }

# ------------------------------------------------------------ utilidades ---
# Lee una clave de una seccion concreta (vacio si no existe).
d_valor_ini() {
    awk -v sec="$2" -v key="$3" '
        /^[ \t]*\[/ {
            s = $0
            sub(/^[ \t]*\[/, "", s)
            sub(/\][ \t]*$/, "", s)
        }
        s == sec && $0 ~ ("^[ \t]*" key "[ \t]*=") {
            v = $0
            sub(/^[^=]*=[ \t]*/, "", v)
            sub(/[ \t]+$/, "", v)
            print v
            exit
        }
    ' "$1" 2>/dev/null
}

d_tiene_clave() {
    awk -v sec="$2" -v key="$3" '
        /^[ \t]*\[/ {
            s = $0
            sub(/^[ \t]*\[/, "", s)
            sub(/\][ \t]*$/, "", s)
        }
        s == sec && $0 ~ ("^[ \t]*" key "[ \t]*=") { found = 1; exit }
        END { exit(found ? 0 : 1) }
    ' "$1" 2>/dev/null
}

d_tiene_seccion() {
    awk -v sec="$2" '
        /^[ \t]*\[/ {
            s = $0
            sub(/^[ \t]*\[/, "", s)
            sub(/\][ \t]*$/, "", s)
            if (s == sec) { found = 1; exit }
        }
        END { exit(found ? 0 : 1) }
    ' "$1" 2>/dev/null
}

# Valida que el nuevo fichero solo cambia las lineas que casan con $3.
d_validar_sin() {
    local orig="$1" nuevo="$2" patron="$3"
    [ "$(grep -c '^[ \t]*\[' "$orig")" -eq "$(grep -c '^[ \t]*\[' "$nuevo")" ] || return 1
    [ "$(grep -vcE "$patron" "$orig")" -eq "$(grep -vcE "$patron" "$nuevo")" ] || return 1
    diff -q <(grep -vE "$patron" "$orig") \
            <(grep -vE "$patron" "$nuevo") >/dev/null
}

# ------------------------------------------------------------------ parche --
# Conserva el "sin salto de linea final" del original: el WiimoteNew.ini de
# EmuDeck termina en "Source = 0" sin \n y awk anadiria uno.
d_ajustar_final() {
    local orig="$1" nuevo="$2"
    if [ -n "$(tail -c 1 "$orig" 2>/dev/null)" ] \
       && [ -z "$(tail -c 1 "$nuevo" 2>/dev/null)" ]; then
        truncate -s -1 "$nuevo" 2>/dev/null || true
    fi
}

# Reescribe las lineas Device de las secciones indicadas en $2 (fichero de
# asignaciones "Seccion=valor"). Escribe atomico y valida antes de aceptar.
d_parchear() {
    local fichero="$1" asg="$2" tmp
    tmp="$fichero.tmp.$$"

    awk -v asg="$asg" '
        BEGIN {
            while ((getline l < asg) > 0) {
                if (l == "") continue
                i = index(l, "=")
                if (i == 0) continue
                mapa[substr(l, 1, i - 1)] = substr(l, i + 1)
            }
        }
        /^[ \t]*\[/ {
            sec = $0
            sub(/^[ \t]*\[/, "", sec)
            sub(/\][ \t]*$/, "", sec)
        }
        {
            if ((sec in mapa) && $0 ~ /^[ \t]*Device[ \t]*=/) {
                match($0, /^[ \t]*/)
                print substr($0, 1, RLENGTH) "Device = " mapa[sec]
            } else {
                print
            }
        }
    ' "$fichero" >"$tmp" || { rm -f "$tmp"; return 1; }
    d_ajustar_final "$fichero" "$tmp"

    if ! d_validar "$fichero" "$tmp"; then
        rm -f "$tmp"
        d_err "el resultado no es valido (¿cambio algo mas que Device?); no toco nada"
        return 1
    fi

    chmod --reference="$fichero" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$fichero"
}

# Mismas secciones, mismas lineas Device y todo igual salvo esas lineas.
d_validar() {
    local orig="$1" nuevo="$2"
    [ "$(grep -c '^[ \t]*\[' "$orig")" -eq "$(grep -c '^[ \t]*\[' "$nuevo")" ] || return 1
    [ "$(grep -c '^[ \t]*Device[ \t]*=' "$orig")" \
      -eq "$(grep -c '^[ \t]*Device[ \t]*=' "$nuevo")" ] || return 1
    diff -q <(grep -v '^[ \t]*Device[ \t]*=' "$orig") \
            <(grep -v '^[ \t]*Device[ \t]*=' "$nuevo") >/dev/null
}

# Calcula que SIDevice toca en cada puerto de GameCube.
#   6 = mando GC, 0 = ninguno, 12 = adaptador GC real (no se toca).
d_calcular_si() {
    local dir="$1" i cur n
    n="$(d_njugadores)"
    D_SI=()
    [ -f "$dir/Dolphin.ini" ] || return 0
    for i in 0 1 2 3; do
        cur="$(d_valor_ini "$dir/Dolphin.ini" Core "SIDevice$i")"
        if [ "$i" -lt "$n" ]; then
            if [ "$cur" = "12" ]; then
                D_SI[$i]=12
                D_AVISOS+=("puerto $((i + 1)) de GameCube con adaptador real (SIDevice$i=12): no lo toco")
            else
                D_SI[$i]=6
            fi
        else
            case "$cur" in
                6|'') D_SI[$i]=0 ;;
                *)    D_SI[$i]="$cur" ;;
            esac
        fi
    done
}

# Calcula el Source de cada Wiimote: 1 emulado, 0 ninguno, 2 real (se respeta).
d_calcular_wii() {
    local dir="$1" i cur n
    n="$(d_njugadores)"
    D_WII=()
    [ -f "$dir/WiimoteNew.ini" ] || return 0
    for i in 1 2 3 4; do
        cur="$(d_valor_ini "$dir/WiimoteNew.ini" "Wiimote$i" Source)"
        if [ "$i" -le "$n" ]; then
            D_WII[$i]=1
        elif [ "$cur" = "2" ]; then
            D_WII[$i]=2
        else
            D_WII[$i]=0
        fi
    done
}

# Fija SIDevice0..3 en [Core]. Inserta las claves que falten.
d_parchear_si() {
    local fichero="$1" tmp
    tmp="$fichero.tmp.$$"
    awk -v v0="${D_SI[0]}" -v v1="${D_SI[1]}" \
        -v v2="${D_SI[2]}" -v v3="${D_SI[3]}" '
        function vv(i) { return i == 0 ? v0 : (i == 1 ? v1 : (i == 2 ? v2 : v3)) }
        /^[ \t]*\[/ {
            if (en) {
                for (i = 0; i < 4; i++)
                    if (!visto[i]) print "SIDevice" i " = " vv(i)
            }
            s = $0
            sub(/^[ \t]*\[/, "", s)
            sub(/\][ \t]*$/, "", s)
            en = (s == "Core")
            print
            next
        }
        en && match($0, /^[ \t]*SIDevice[0-3][ \t]*=/) {
            pre = substr($0, 1, RSTART - 1)
            j = substr($0, RSTART + 8, 1) + 0
            print pre "SIDevice" j " = " vv(j)
            visto[j] = 1
            next
        }
        { print }
        END {
            if (en)
                for (i = 0; i < 4; i++)
                    if (!visto[i]) print "SIDevice" i " = " vv(i)
        }
    ' "$fichero" >"$tmp" || { rm -f "$tmp"; return 1; }
    d_ajustar_final "$fichero" "$tmp"

    if ! d_validar_sin "$fichero" "$tmp" \
         '^[[:space:]]*SIDevice[0-3][[:space:]]*='; then
        rm -f "$tmp"
        d_err "el resultado de Dolphin.ini no es valido; no toco nada"
        return 1
    fi
    chmod --reference="$fichero" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$fichero"
}

# Fija Source en [Wiimote1..4]; inserta la linea si el fichero no la trae
# (el WiimoteNew.ini de EmuDeck no la trae, y Dolphin solo activa el 1).
d_parchear_source() {
    local fichero="$1" tmp h1 h2 h3 h4
    tmp="$fichero.tmp.$$"
    h1=0; h2=0; h3=0; h4=0
    d_tiene_clave "$fichero" Wiimote1 Source && h1=1
    d_tiene_clave "$fichero" Wiimote2 Source && h2=1
    d_tiene_clave "$fichero" Wiimote3 Source && h3=1
    d_tiene_clave "$fichero" Wiimote4 Source && h4=1

    awk -v w1="${D_WII[1]}" -v w2="${D_WII[2]}" \
        -v w3="${D_WII[3]}" -v w4="${D_WII[4]}" \
        -v h1="$h1" -v h2="$h2" -v h3="$h3" -v h4="$h4" '
        function wv(n) { return n == 1 ? w1 : (n == 2 ? w2 : (n == 3 ? w3 : w4)) }
        function hs(n) { return n == 1 ? h1 : (n == 2 ? h2 : (n == 3 ? h3 : h4)) }
        /^[ \t]*\[/ {
            s = $0
            sub(/^[ \t]*\[/, "", s)
            sub(/\][ \t]*$/, "", s)
            cur = 0
            if (s ~ /^Wiimote[1-4]$/) cur = substr(s, 8, 1) + 0
            print
            if (cur && !hs(cur)) print "Source = " wv(cur)
            next
        }
        cur && /^[ \t]*Source[ \t]*=/ {
            match($0, /^[ \t]*/)
            print substr($0, 1, RLENGTH) "Source = " wv(cur)
            next
        }
        { print }
    ' "$fichero" >"$tmp" || { rm -f "$tmp"; return 1; }
    d_ajustar_final "$fichero" "$tmp"

    if ! d_validar_sin "$fichero" "$tmp" '^[[:space:]]*Source[[:space:]]*='; then
        rm -f "$tmp"
        d_err "el resultado de WiimoteNew.ini no es valido; no toco nada"
        return 1
    fi
    chmod --reference="$fichero" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$fichero"
}

# Fija el Device de [Hotkeys] al jugador 1.
d_parchear_hotkeys() {
    local fichero="$1" dev="$2" tmp ins
    tmp="$fichero.tmp.$$"
    ins=0
    d_tiene_clave "$fichero" Hotkeys Device || ins=1

    awk -v dev="$dev" -v ins="$ins" '
        /^[ \t]*\[/ {
            s = $0
            sub(/^[ \t]*\[/, "", s)
            sub(/\][ \t]*$/, "", s)
            cur = (s == "Hotkeys")
            print
            if (cur && ins) { print "Device = " dev; ins = 0 }
            next
        }
        cur && /^[ \t]*Device[ \t]*=/ {
            match($0, /^[ \t]*/)
            print substr($0, 1, RLENGTH) "Device = " dev
            next
        }
        { print }
    ' "$fichero" >"$tmp" || { rm -f "$tmp"; return 1; }
    d_ajustar_final "$fichero" "$tmp"

    if ! d_validar_sin "$fichero" "$tmp" \
         '^[[:space:]]*Device[[:space:]]*='; then
        rm -f "$tmp"
        d_err "el resultado de Hotkeys.ini no es valido; no toco nada"
        return 1
    fi
    chmod --reference="$fichero" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$fichero"
}

# ------------------------------------------------------------------ acciones
d_asignaciones() { # $1 = prefijo de seccion (GCPad | Wiimote)  -> stdout
    local prefijo="$1" n
    for n in $(seq 1 "${#PLAN_NOMBRE[@]}"); do
        printf '%s%s=%s\n' "$prefijo" "$n" "$(d_device "$n")"
    done
}

d_cmd_status() {
    local dir f
    dir="$(d_dir)" || { d_err "no encuentro la configuracion de Dolphin"; return 4; }
    d_say "Dolphin            : $dir"
    d_say "en ejecucion       : $(d_en_ejecucion && echo SI || echo no)"
    d_planificar || true
    nucleo_imprimir_plan
    for f in GCPadNew.ini WiimoteNew.ini; do
        [ -f "$dir/$f" ] || continue
        d_say "--- $f"
        grep -n '^[ \t]*\[.\+\][ \t]*$\|^[ \t]*Device[ \t]*=' "$dir/$f" | sed 's/^/  /'
    done
    if [ -f "$dir/WiimoteNew.ini" ]; then
        d_say "--- WiimoteNew.ini (Source)"
        grep -n '^[ \t]*\[Wiimote[1-4]\][ \t]*$\|^[ \t]*Source[ \t]*=' \
            "$dir/WiimoteNew.ini" | sed 's/^/  /'
    fi
    if [ -f "$dir/Dolphin.ini" ]; then
        d_say "--- Dolphin.ini (puertos GameCube)"
        grep -n '^[ \t]*SIDevice[0-3][ \t]*=' "$dir/Dolphin.ini" | sed 's/^/  /'
    fi
    if [ -f "$dir/Hotkeys.ini" ]; then
        d_say "--- Hotkeys.ini"
        grep -n '^[ \t]*Device[ \t]*=' "$dir/Hotkeys.ini" | sed 's/^/  /'
    fi
    return 0
}

d_cmd_dryrun() {
    local dir n i
    dir="$(d_dir)" || { d_err "no encuentro la configuracion de Dolphin"; return 4; }
    d_planificar || {
        nucleo_imprimir_plan
        nucleo_guardar_plan dolphin dry-run
        return 2
    }
    n="$(d_njugadores)"
    d_say "Dolphin: $dir"
    nucleo_imprimir_plan
    local f prefijo
    for f in GCPadNew.ini WiimoteNew.ini; do
        [ -f "$dir/$f" ] || continue
        prefijo="GCPad"
        [ "$f" = "WiimoteNew.ini" ] && prefijo="Wiimote"
        d_say "--- $f"
        for i in $(seq 1 "$n"); do
            d_say "  [$prefijo$i] Device = $(d_device "$i")"
        done
    done

    d_calcular_si "$dir"
    if [ -f "$dir/Dolphin.ini" ]; then
        d_say "--- Dolphin.ini"
        d_say "  SIDevice0=${D_SI[0]} SIDevice1=${D_SI[1]} SIDevice2=${D_SI[2]} SIDevice3=${D_SI[3]}"
    fi

    d_calcular_wii "$dir"
    if [ -f "$dir/WiimoteNew.ini" ]; then
        d_say "--- WiimoteNew.ini (Source)"
        for i in 1 2 3 4; do
            d_say "  [Wiimote$i] Source = ${D_WII[$i]}"
        done
    fi

    if [ -f "$dir/Hotkeys.ini" ]; then
        d_say "--- Hotkeys.ini"
        d_say "  Device = $(d_device 1)"
    fi

    for i in "${D_AVISOS[@]+"${D_AVISOS[@]}"}"; do
        d_say "AVISO: $i"
    done
    d_say "(dry-run: no se ha escrito nada)"
    nucleo_guardar_plan dolphin dry-run
    nucleo_registrar dolphin dry-run
    return 0
}

d_cmd_aplicar() {
    local dir n i f fallo=0
    dir="$(d_dir)" || { d_err "no encuentro la configuracion de Dolphin"; return 4; }

    if d_en_ejecucion; then
        nucleo_log "dolphin aplicar: Dolphin en ejecucion, no aplico"
        d_err "Dolphin esta en ejecucion. Cierralo y vuelve a intentarlo."
        return 3
    fi

    d_planificar || {
        [ "$QUIET" = "1" ] || nucleo_imprimir_plan
        nucleo_guardar_plan dolphin aplicar
        nucleo_registrar dolphin aplicar
        d_warn "no hay mandos que asignar: dejo la configuracion como estaba"
        return 2
    }

    n="$(d_njugadores)"
    local bk stamp
    bk="$(d_backups)"
    mkdir -p "$bk" || { d_err "no puedo crear $bk"; return 1; }
    stamp="$(date +%Y%m%d-%H%M%S)"

    # 1) copia de TODOS los ficheros que se van a tocar
    local stock
    stock="$(d_stock)"
    mkdir -p "$stock" || { d_err "no puedo crear $stock"; return 1; }
    for f in GCPadNew.ini WiimoteNew.ini Dolphin.ini Hotkeys.ini; do
        [ -f "$dir/$f" ] || continue
        cp -p "$dir/$f" "$bk/$f.$stamp" \
            || { d_err "no puedo hacer backup de $f"; return 1; }
        [ -f "$stock/$f" ] || cp -p "$dir/$f" "$stock/$f" \
            || { d_err "no puedo guardar el original de $f"; return 1; }
    done

    # 2) Device de los mandos
    if [ -f "$dir/GCPadNew.ini" ]; then
        d_asignaciones GCPad >"$bk/.asg.$$"
        if d_parchear "$dir/GCPadNew.ini" "$bk/.asg.$$"; then
            d_say "GCPadNew.ini actualizado"
            for i in $(seq 1 "$n"); do
                nucleo_log "dolphin aplicar: GCPad$i Device = $(d_device "$i")"
            done
        else
            rm -f "$bk/.asg.$$"
            d_err "no pude actualizar GCPadNew.ini (backup en $bk/GCPadNew.ini.$stamp)"
            return 1
        fi
        rm -f "$bk/.asg.$$"
    fi
    if [ -f "$dir/WiimoteNew.ini" ]; then
        d_asignaciones Wiimote >"$bk/.asg.$$"
        if d_parchear "$dir/WiimoteNew.ini" "$bk/.asg.$$"; then
            d_say "WiimoteNew.ini actualizado"
            for i in $(seq 1 "$n"); do
                nucleo_log "dolphin aplicar: Wiimote$i Device = $(d_device "$i")"
            done
        else
            rm -f "$bk/.asg.$$"
            d_err "no pude actualizar WiimoteNew.ini (backup en $bk/WiimoteNew.ini.$stamp)"
            return 1
        fi
        rm -f "$bk/.asg.$$"
    fi

    # 3) puertos de GameCube (SIDevice) en Dolphin.ini
    if [ -f "$dir/Dolphin.ini" ]; then
        if d_tiene_seccion "$dir/Dolphin.ini" Core; then
            d_calcular_si "$dir"
            if d_parchear_si "$dir/Dolphin.ini"; then
                d_say "Dolphin.ini: puertos GC 1-$n activos"
                nucleo_log "dolphin aplicar: SIDevice0..3 = ${D_SI[0]},${D_SI[1]},${D_SI[2]},${D_SI[3]}"
            else
                fallo=1
            fi
        else
            d_warn "Dolphin.ini no tiene [Core]: no puedo activar los puertos GC"
        fi
    else
        d_warn "no hay Dolphin.ini: los puertos 2-4 de GameCube no se activan"
    fi

    # 4) Wiimotes emulados en WiimoteNew.ini
    if [ -f "$dir/WiimoteNew.ini" ]; then
        d_calcular_wii "$dir"
        if d_parchear_source "$dir/WiimoteNew.ini"; then
            d_say "WiimoteNew.ini: Wiimote 1-$n emulados"
            nucleo_log "dolphin aplicar: Source Wiimote1..4 = ${D_WII[1]},${D_WII[2]},${D_WII[3]},${D_WII[4]}"
        else
            fallo=1
        fi
    fi

    # 5) atajos de teclado/mando al jugador 1
    if [ -f "$dir/Hotkeys.ini" ]; then
        if d_tiene_seccion "$dir/Hotkeys.ini" Hotkeys; then
            if d_parchear_hotkeys "$dir/Hotkeys.ini" "$(d_device 1)"; then
                d_say "Hotkeys.ini: mandos del jugador 1"
                nucleo_log "dolphin aplicar: Hotkeys Device = $(d_device 1)"
            else
                fallo=1
            fi
        else
            d_warn "Hotkeys.ini no tiene [Hotkeys]: lo dejo como estaba"
        fi
    fi

    # 6) secciones que falten (EmuDeck trae las 4, pero por si acaso)
    if [ -f "$dir/GCPadNew.ini" ]; then
        for i in $(seq 1 "$n"); do
            d_tiene_seccion "$dir/GCPadNew.ini" "GCPad$i" \
                || d_warn "GCPadNew.ini no tiene [GCPad$i]: ese jugador no tendra mando GC"
        done
    fi
    if [ -f "$dir/WiimoteNew.ini" ]; then
        for i in $(seq 1 "$n"); do
            d_tiene_seccion "$dir/WiimoteNew.ini" "Wiimote$i" \
                || d_warn "WiimoteNew.ini no tiene [Wiimote$i]: ese jugador no tendra Wiimote"
        done
    fi
    for i in "${D_AVISOS[@]+"${D_AVISOS[@]}"}"; do
        d_warn "$i"
    done

    # retencion (misma idea que en Eden)
    local ret="${RETENCION_BACKUPS:-10}"
    if [ "$ret" -gt 0 ] 2>/dev/null; then
        for f in GCPadNew.ini WiimoteNew.ini Dolphin.ini Hotkeys.ini; do
            ls -1t "$bk"/$f.* 2>/dev/null | tail -n +$((ret + 1)) \
                | while read -r viejo; do
                    rm -f "$viejo"
                done
        done
    fi

    nucleo_guardar_plan dolphin aplicar
    nucleo_registrar dolphin aplicar
    [ "$fallo" -eq 0 ] || return 1
    return 0
}

d_cmd_restore() {
    local cual="${1:-latest}" bk stock dir f origen
    bk="$(d_backups)"
    stock="$(d_stock)"
    [ -d "$bk" ] || { d_err "no hay copias de Dolphin"; return 1; }
    dir="$(d_dir)" || { d_err "no encuentro la configuracion de Dolphin"; return 4; }

    for f in GCPadNew.ini WiimoteNew.ini Dolphin.ini Hotkeys.ini; do
        if [ "$cual" = "stock" ] || [ "$cual" = "original" ]; then
            # estado anterior a N.E.C.A; si no hay copia fija, la mas antigua
            origen="$stock/$f"
            [ -f "$origen" ] || origen="$(ls -1t "$bk"/$f.* 2>/dev/null | tail -n 1)"
        elif [ "$cual" = "latest" ]; then
            origen="$(ls -1t "$bk"/$f.* 2>/dev/null | head -n 1)"
        else
            origen="$(ls -1t "$bk"/$f.* 2>/dev/null | sed -n "${cual}p")"
        fi
        if [ -z "${origen:-}" ] || [ ! -f "$origen" ]; then
            d_warn "no hay copia de $f"
            continue
        fi
        cp -f "$origen" "$dir/$f" \
            && d_say "restaurado $f <- $(basename "$origen")"
    done
    return 0
}

# ------------------------------------------------------------------- CLI ----
d_usage() {
    cat <<EOF
driver Dolphin (GameCube / Wii)

USO
  eden-autoconfig.sh --sistema gc                aplica
  eden-autoconfig.sh --sistema gc --dry-run      enseña el plan, sin escribir
  eden-autoconfig.sh --sistema gc --status       estado, Device, SIDevice y Source
  eden-autoconfig.sh --sistema gc --restore [latest|stock|N]
  eden-autoconfig.sh --sistema gc --help

Aplica Device en GCPadNew.ini/WiimoteNew.ini, SIDevice0..3 en Dolphin.ini,
Source en los Wiimotes y el Device de Hotkeys.ini.
EOF
}

main() {
    local modo="aplicar" restore_arg="latest"
    while [ $# -gt 0 ]; do
        case "$1" in
            --status)   modo="status" ;;
            --dry-run|--dryrun) modo="dryrun" ;;
            --restore)
                modo="restore"
                case "${2:-}" in
                    ''|--*) : ;;
                    *) restore_arg="$2"; shift ;;
                esac
                ;;
            --help|-h) d_usage; return 0 ;;
            --quiet|-q) QUIET=1 ;;
            --verbose|-v) : ;;
            *)
                d_err "opcion no reconocida: $1"
                d_usage >&2
                return 1
                ;;
        esac
        shift
    done

    case "$modo" in
        status)  d_cmd_status ;;
        dryrun)  d_cmd_dryrun ;;
        restore) d_cmd_restore "$restore_arg" ;;
        *)       d_cmd_aplicar ;;
    esac
}
