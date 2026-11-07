#!/usr/bin/env bash
# =============================================================================
#  eden-mandos-evdev.sh  --  lista los gamepads fisicos por evdev
# =============================================================================
#  Se usa cuando Dolphin debe leer los mandos reales en vez de los pads
#  virtuales de Steam Input. Dolphin identifica estos mandos como
#      evdev/<n-esimo con ese nombre>/<nombre del kernel>
#  y este ayudante da exactamente el nombre y el orden de /proc.
#
#  Salida (mismo formato que eden-mandos-sdl.sh):
#     NOMBRE|GUID|PUERTO|TIPO|ES_GAMEPAD|NOMBRE_SDL|SERIE|INDICE
#
#  Solo lista dispositivos con handler "js" (gamepads), excluye los pads
#  virtuales de Steam (28de:11ff / "Steam Virtual Gamepad") y ordena por
#  numero de event, que es el orden que usa Dolphin al poblarlos.
#
#  Pruebas: EDEN_FAKE_EVDEV=/ruta/proc-devices bash eden-mandos-evdev.sh
# =============================================================================

set -u

PY=""
for c in python3 python; do
    command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }
done
[ -n "$PY" ] || { echo "no encuentro python" >&2; exit 1; }

exec "$PY" - "${EDEN_FAKE_EVDEV:-}" <<'PYEOF'
import os
import re
import sys

fake = sys.argv[1] if len(sys.argv) > 1 else ""
path = fake if fake and os.path.isfile(fake) else "/proc/bus/input/devices"
try:
    texto = open(path, "r", encoding="utf-8", errors="replace").read()
except OSError as exc:
    sys.stderr.write("no puedo leer %s: %s\n" % (path, exc))
    sys.exit(1)

bloques = re.split(r"\n\s*\n", texto.strip())
devs = []
for bloque in bloques:
    nombre = re.search(r'^N: Name="(.*)"', bloque, re.M)
    uniq = re.search(r'^U: Uniq=(.*)$', bloque, re.M)
    phys = re.search(r'^P: Phys=(.*)$', bloque, re.M)
    handlers = re.search(r'^H: Handlers=(.*)$', bloque, re.M)
    vendor = re.search(r'Vendor=([0-9a-fA-F]+)', bloque)
    product = re.search(r'Product=([0-9a-fA-F]+)', bloque)
    if not (nombre and handlers):
        continue
    h = handlers.group(1)
    if not re.search(r'\bjs\d+\b', h):
        continue
    ev = re.search(r'\bevent(\d+)\b', h)
    if not ev:
        continue
    name = nombre.group(1).strip()
    vend = (vendor.group(1) if vendor else "0").lower()
    prod = (product.group(1) if product else "0").lower()
    # Pads virtuales de Steam: no son mandos fisicos
    if "steam virtual" in name.lower() or (vend == "28de" and prod == "11ff"):
        continue
    devs.append({
        "name": name,
        "event": int(ev.group(1)),
        "uniq": (uniq.group(1).strip() if uniq else ""),
        "phys": (phys.group(1).strip() if phys else ""),
        "vendor": vend,
        "product": prod,
    })

# Dolphin usa el orden de udev; el numero de event es una aproximacion estable.
devs.sort(key=lambda d: d["event"])

vistos = {}
for d in devs:
    p = vistos.get(d["name"], 0)
    vistos[d["name"]] = p + 1
    guid = "evdev%s%s" % (d["vendor"], d["product"])
    serie = d["uniq"] or d["phys"]
    campos = [
        d["name"], guid, str(p), "0", "1", d["name"],
        serie, str(d["event"]),
    ]
    print("|".join(x.replace("|", " ").replace("\n", " ") for x in campos))
PYEOF
