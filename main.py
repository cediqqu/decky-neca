# -*- coding: utf-8 -*-
# =============================================================================
#  main.py -- backend del plugin de Decky "N.E.C.A" (Nintendo-EmuDeck Controller Autoconf)
# =============================================================================
#  Este backend NO reimplementa nada del proyecto de scripts (eden_controller).
#  Solo hace tres cosas:
#
#    1. EJECUTA los scripts ya instalados en ~/eden-autoconfig
#       (eden-autoconfig.sh / eden-mandos-sdl.sh / instalar.sh).
#    2. Lee la tabla de mandos de eden-mandos-sdl.sh (formato estable:
#       nombre|guid|puerto|tipo|gamepad|nombre_sdl|serie; las lineas '#' son
#       informativas y se ignoran).
#    3. Guarda tus elecciones en un BLOQUE GESTIONADO al final de
#       ~/eden-autoconfig/eden-autoconfig.conf, que es la interfaz publica del
#       script (el hook de ES-DE lee ese mismo fichero al lanzar el juego).
#
#  El bloque se reemplaza entero cada vez: el resto del .conf queda intacto y,
#  si borras el bloque, vuelves exactamente a tu configuracion anterior.
#
#  Correr como 'deck' (el plugin NO lleva el flag "root"): escribir el .conf
#  como root dejaria a Eden sin permisos para guardar.
# =============================================================================

import asyncio
import hashlib
import json
import logging
import os
import re
import shutil
import time
import zlib

try:
    import decky
    log = decky.logger
except Exception:  # pruebas locales sin decky-loader
    decky = None
    log = logging.getLogger("eden-autoconfig-decky")

PLUGIN_DIR = os.path.dirname(os.path.realpath(__file__))
SCRIPTS_DIR = os.path.join(PLUGIN_DIR, "scripts")

SCRIPT = "eden-autoconfig.sh"
MANDOS = "eden-mandos-sdl.sh"
INSTALADOR = "instalar.sh"

BEGIN = "# >>> eden-autoconfig-decky >>>"
END = "# <<< eden-autoconfig-decky <<<"

# valores por defecto de N.E.C.A (los mismos que el script)
PREF_DEF = {
    "P1_SERIE": "",
    "JUGADORES_MAX": "4",
    "ORDEN_INTEGRADO": "primero",
    "INTEGRADO_MANUAL": "no",
    "ORDEN_DUALSENSE": "conexion",
    "RETENCION_BACKUPS": "10",
}

INTEGRADOS = ("ignorar", "primero", "ultimo")
ORDENES = ("conexion", "mac")

# una serie es una MAC (aa:bb:...) o similar; nunca dejamos pasar otra cosa
RE_SERIE = re.compile(r"^[A-Za-z0-9:._-]{0,64}$")

# cuanto texto devolvemos al panel (el QAM es pequeno)
MAX_SALIDA = 6000


# --------------------------------------------------------------- rutas ------

def _home():
    """HOME del usuario de la consola (deck), nunca el del proceso root."""
    for attr in ("DECKY_USER_HOME", "DECKY_HOME"):
        v = getattr(decky, attr, None) if decky else None
        if v:
            return v
    return os.path.expanduser("~")


def _base():
    return os.path.join(_home(), "eden-autoconfig")


def _conf():
    return os.path.join(_base(), "eden-autoconfig.conf")


def _log_txt():
    return os.path.join(_base(), "log.txt")


def _estado_dir():
    """Estado privado del plugin (backups del .conf, fuera del proyecto de scripts)."""
    return os.path.join(_home(), ".config", "eden-autoconfig-decky")


def _marca_scripts():
    return os.path.join(_estado_dir(), "scripts-instalados")


def _marcar_scripts():
    """Deja constancia de que los scripts se acaban de instalar/actualizar."""
    try:
        os.makedirs(_estado_dir(), exist_ok=True)
        with open(_marca_scripts(), "w", encoding="utf-8") as fh:
            fh.write("%d\n" % int(time.time()))
    except Exception as exc:
        log.warning("no pude marcar la instalacion de scripts: %s", exc)


def _limpiar_marca_scripts():
    try:
        os.remove(_marca_scripts())
    except FileNotFoundError:
        pass
    except Exception:
        pass


def _scripts_recientes(segundos=1800):
    """True si los scripts se instalaron hace menos de `segundos`."""
    try:
        with open(_marca_scripts(), "r", encoding="utf-8") as fh:
            cuando = int(fh.read().strip() or 0)
        return 0 <= (time.time() - cuando) < segundos
    except Exception:
        return False


def _script(nombre):
    return os.path.join(_base(), nombre)


def _env():
    env = dict(os.environ)
    env["HOME"] = _home()
    # por si el loader arranca con un PATH minimo: bash necesita encontrar
    # python3, bluetoothctl, flock, stat...
    base_path = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    env["PATH"] = base_path + (":" + env["PATH"] if env.get("PATH") else "")
    return env


# --------------------------------------------------------- ejecutar bash -----

async def _run(args, timeout=60, cwd=None):
    """Ejecuta un comando y devuelve (exit, salida_combinada). Nunca lanza."""
    try:
        proc = await asyncio.create_subprocess_exec(
            *args,
            cwd=cwd,
            env=_env(),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
    except Exception as exc:
        return -1, "no se pudo ejecutar %s: %s" % (args[0], exc)

    try:
        salida, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        try:
            proc.kill()
        except Exception:
            pass
        return -2, "tiempo agotado tras %ss" % timeout
    except Exception as exc:
        return -3, "fallo leyendo la salida: %s" % exc

    return proc.returncode, (salida or b"").decode("utf-8", "replace")


def _corta(texto):
    texto = (texto or "").strip()
    if len(texto) > MAX_SALIDA:
        texto = texto[-MAX_SALIDA:]
        texto = "(...)\n" + texto
    return texto


# ------------------------------------------------------------- prefs --------

def _leer_prefs():
    prefs = dict(PREF_DEF)
    try:
        with open(_conf(), "r", encoding="utf-8", errors="replace") as fh:
            texto = fh.read()
    except Exception:
        return prefs

    m = re.search(re.escape(BEGIN) + r"(.*?)" + re.escape(END), texto, re.S)
    if not m:
        return prefs

    for linea in m.group(1).splitlines():
        linea = linea.strip()
        if not linea or linea.startswith("#") or "=" not in linea:
            continue
        clave, valor = linea.split("=", 1)
        clave = clave.strip()
        if clave in prefs:
            prefs[clave] = valor.strip().strip('"').strip("'")
    return _validar(prefs)


def _validar(prefs):
    out = {}

    serie = str(prefs.get("P1_SERIE", "") or "").strip()
    out["P1_SERIE"] = serie if RE_SERIE.match(serie) else ""

    try:
        n = int(str(prefs.get("JUGADORES_MAX", "4")).strip())
    except Exception:
        n = 4
    out["JUGADORES_MAX"] = str(n if 1 <= n <= 4 else 4)

    integ = str(prefs.get("ORDEN_INTEGRADO", "ignorar")).strip()
    out["ORDEN_INTEGRADO"] = integ if integ in INTEGRADOS else "primero"

    manual = str(prefs.get("INTEGRADO_MANUAL", "no")).strip()
    out["INTEGRADO_MANUAL"] = "si" if manual == "si" else "no"

    orden = str(prefs.get("ORDEN_DUALSENSE", "conexion")).strip()
    out["ORDEN_DUALSENSE"] = orden if orden in ORDENES else "conexion"

    try:
        ret = int(str(prefs.get("RETENCION_BACKUPS", "10")).strip())
    except Exception:
        ret = 10
    out["RETENCION_BACKUPS"] = str(ret if ret >= 0 else 10)

    return out


def _backup_conf(texto):
    """Copia del .conf (sin el bloque nuevo) en el estado privado del plugin."""
    try:
        carpeta = _estado_dir()
        os.makedirs(carpeta, exist_ok=True)
        nombre = "eden-autoconfig.conf.%s.bak" % time.strftime("%Y%m%d-%H%M%S")
        with open(os.path.join(carpeta, nombre), "w", encoding="utf-8") as fh:
            fh.write(texto)
        # conservar solo los 5 mas recientes
        backups = sorted(x for x in os.listdir(carpeta) if x.endswith(".bak"))
        for viejo in backups[:-5]:
            try:
                os.remove(os.path.join(carpeta, viejo))
            except Exception:
                pass
    except Exception as exc:
        log.warning("no pude hacer backup del .conf: %s", exc)


def _escribir_prefs(prefs):
    """Reemplaza el bloque gestionado. Escritura atomica. Devuelve (ok, msg)."""
    prefs = _validar(prefs)
    conf = _conf()

    existia = False
    try:
        with open(conf, "r", encoding="utf-8", errors="replace") as fh:
            texto = fh.read()
        existia = True
    except FileNotFoundError:
        if not _instalado()[0]:
            return False, ("no existe %s y los scripts no estan instalados.\n"
                           "Pulsa 'Instalar scripts' primero." % conf)
        texto = ("# Creado por el plugin N.E.C.A.\n"
                 "# El plugin solo gestiona el bloque marcado al final.\n")
    except Exception as exc:
        return False, "no puedo leer %s: %s" % (conf, exc)

    # fuera bloque(s) anteriores
    texto = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?",
                   "", texto, flags=re.S).rstrip("\n") + "\n"

    bloque = ["", BEGIN,
              'P1_SERIE="%s"' % prefs["P1_SERIE"],
              "JUGADORES_MAX=%s" % prefs["JUGADORES_MAX"],
              'ORDEN_INTEGRADO="%s"' % prefs["ORDEN_INTEGRADO"],
              'INTEGRADO_MANUAL="%s"' % prefs["INTEGRADO_MANUAL"],
              'ORDEN_DUALSENSE="%s"' % prefs["ORDEN_DUALSENSE"],
              "RETENCION_BACKUPS=%s" % prefs["RETENCION_BACKUPS"],
              END, ""]
    nuevo = texto + "\n".join(bloque)

    if existia:
        _backup_conf(texto)

    tmp = conf + ".decky-tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(nuevo)
            fh.flush()
            os.fsync(fh.fileno())
        if existia:
            try:
                os.chmod(tmp, os.stat(conf).st_mode & 0o777)
            except Exception:
                pass
        else:
            os.chmod(tmp, 0o644)
        os.replace(tmp, conf)
    except Exception as exc:
        try:
            os.remove(tmp)
        except Exception:
            pass
        return False, "no puedo escribir %s: %s" % (conf, exc)

    return True, ""


def _quitar_bloque():
    """Elimina el bloque gestionado del .conf. Devuelve (ok, habia_bloque)."""
    conf = _conf()
    try:
        with open(conf, "r", encoding="utf-8", errors="replace") as fh:
            texto = fh.read()
    except FileNotFoundError:
        return True, False
    except Exception:
        return False, False

    nuevo = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?",
                   "", texto, flags=re.S)
    nuevo = nuevo.rstrip("\n") + "\n"
    if nuevo == texto:
        return True, False

    _backup_conf(texto)
    tmp = conf + ".decky-tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(nuevo)
            fh.flush()
            os.fsync(fh.fileno())
        try:
            os.chmod(tmp, os.stat(conf).st_mode & 0o777)
        except Exception:
            pass
        os.replace(tmp, conf)
    except Exception as exc:
        try:
            os.remove(tmp)
        except Exception:
            pass
        log.warning("no pude limpiar el bloque: %s", exc)
        return False, False
    return True, True


# ------------------------------------------------------------ mdandos -------

def _auto_integrado(prefs, ds_n):
    """Sin eleccion manual: Jugador 1 sin externos, ultimo en cuanto hay uno."""
    try:
        tope = int(prefs.get("JUGADORES_MAX", "4"))
    except Exception:
        tope = 4
    manual = prefs.get("INTEGRADO_MANUAL") == "si"

    # Sin DualSense el integrado es siempre P1. Con DualSense, si el usuario
    # eligio manualmente (incluido P1), se respeta; si no, va ultimo o se
    # desactiva cuando el cupo esta lleno.
    if ds_n == 0:
        deseado = "primero"
        if prefs["ORDEN_INTEGRADO"] == "primero":
            return prefs, ""
    elif manual:
        return prefs, ""
    else:
        deseado = "ignorar" if ds_n >= tope else "ultimo"

    nota = ""
    if prefs["ORDEN_INTEGRADO"] != deseado:
        prefs["ORDEN_INTEGRADO"] = deseado
        ok, msg = _escribir_prefs(prefs)
        if not ok:
            nota = msg
    return prefs, nota


# --------------------------------------------- plan de jugadores (--who) ----
RE_WHO = re.compile(r"Player\s+(\d+)\s*=\s*(.+?)\s*\(port\s+(\d+)\)", re.I)


def _parse_who(texto):
    """Lee el plan de `--who`. El script es quien decide: aqui solo se lee.

    Lineas tipo:
      Player 1 = DualSense 1  (port 0)
      Player 3 = INTEGRADO [Asus...]  (port 0)
      Player 1 = pad virtual Steam 0   (port 0)
    """
    plan = {"dual": {}, "virtual": {}, "integrado": None,
            "integrado_nombre": ""}
    for m in RE_WHO.finditer(texto or ""):
        jugador = int(m.group(1))
        que = m.group(2).strip().lower()
        puerto = m.group(3)
        if "integrado" in que:
            plan["integrado"] = jugador
            mn = re.search(r"\[([^\]]+)\]", que)
            plan["integrado_nombre"] = mn.group(1).strip() if mn else ""
        elif "virtual" in que:
            plan["virtual"][puerto] = jugador
        elif "dualsense" in que:
            plan["dual"][puerto] = jugador
    return plan


def _marcar_integrado_plan(mandos, plan):
    """Marca como Integrado el mando que el plan llama INTEGRADO.

    El panel clasifica por nombre/guid, pero el driver puede identificarlo
    ademas por el plan (p. ej. un Steam Virtual Gamepad que no parece Asus).
    """
    if any(m["clase"] == "Integrado" for m in mandos):
        return
    nombre = (plan.get("integrado_nombre") or "").strip().lower()
    if nombre:
        for m in mandos:
            if m["clase"] == "DualSense":
                continue
            if nombre in (m.get("nombre", "").lower(),
                          m.get("sdl", "").lower()):
                m["clase"] = "Integrado"
                m["familia"] = "integrado"
                m["conexion"] = "Interno"
                return
    virtuales = [m for m in mandos
                 if m["clase"] in ("Otro", "Pad virtual")
                 and m["virtual"] and not m["serie"]]
    if len(virtuales) == 1:
        virtuales[0]["clase"] = "Integrado"
        virtuales[0]["familia"] = "integrado"
        virtuales[0]["conexion"] = "Interno"


def _sincronizar_principal(prefs, ds):
    """El mando principal: con uno solo, se fija solo.

    - Si hay un unico DualSense y no hay principal fijado, se fija ese (asi al
      conectar mas sigue siendo el principal hasta que elijas otro).
    - Si el principal fijado ya no esta entre los conectados, se libera para
      que el primero disponible vuelva a ser Player 1.
    """
    original = prefs["P1_SERIE"]
    deseado = original
    nota = ""

    if deseado and ds and not any(m["serie"] == deseado for m in ds):
        deseado = ""
        nota = ("El mando principal ya no esta conectado: se libera para que el "
                "primero disponible sea el Player 1.")

    if deseado != original:
        prefs["P1_SERIE"] = deseado
        ok, msg = _escribir_prefs(prefs)
        if not ok:
            nota = (nota + "\n" if nota else "") + msg

    return prefs, nota


def _marcar_principal(mandos, prefs, integrado_jugador=None):
    """Marca cual es el mando principal (la estrella del panel)."""
    ds = [m for m in mandos if m["clase"] == "DualSense"]

    # El integrado puede ser P1 y no estar en la lista de SDL (Steam Input lo
    # expone solo al lanzar). En ese caso ningun DualSense lleva la estrella.
    if integrado_jugador == 1:
        for m in mandos:
            m["es_principal"] = False
        return

    if any(m["jugador"] == 1 for m in mandos):
        for m in mandos:
            m["es_principal"] = (m["jugador"] == 1)
    elif prefs["P1_SERIE"]:
        for m in mandos:
            m["es_principal"] = (m["serie"] == prefs["P1_SERIE"])
    else:
        primero = ds[0] if ds else None
        for m in mandos:
            m["es_principal"] = (m is primero)


# ------------------------------------------------------------- vibracion ----
#  Pulso corto para identificar un mando concreto. Se escribe el reporte de
#  salida por /dev/hidrawN (lo mismo que hace Steam), asi que no hace falta
#  root ni tocar /sys.
#
#  Formato (drivers/hid/hid-playstation.c):
#    common[0] = 0x01 | 0x02   (compatible vibration + haptics select)
#    common[2] = motor_right
#    common[3] = motor_left
#    USB : 0x02 + common(47) + 15                       -> 63 bytes
#    BT  : 0x31 + seq + 0x10 + common(47) + 24 + crc32  -> 78 bytes
#
#  OJO con el CRC: el kernel lo calcula como
#      crc32_le(0xFFFFFFFF, &0xA2, 1) ... ~crc32_le(crc, data, len-4)
#  o sea: CRC-32 de (0xA2 || reporte_sin_crc). Si se usa el CRC "normal",
#  el mando descarta el reporte en silencio (no vibra y no da error).

SEMILLA_CRC = 0xA2

MOTOR_PULSO = 0x28
PULSO_S = 0.30

_seq_bt = int(time.time()) & 0x0F


def _siguiente_seq():
    """Contador de 4 bits del reporte Bluetooth (debe cambiar siempre)."""
    global _seq_bt
    _seq_bt = (_seq_bt + 1) & 0x0F
    return _seq_bt


def _norm_mac(valor):
    return (valor or "").strip().lower().replace(":", "").replace("-", "")


def _leer_texto(ruta):
    with open(ruta, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read().strip()


def _raiz_hidraw():
    return os.environ.get("EDEN_HIDRAW_ROOT", "").strip() or "/sys/class/hidraw"


def _devdir():
    return os.environ.get("EDEN_DEVDIR", "").strip() or "/dev"


def _hidraw_de(clave):
    """(/dev/hidrawN, 'usb'|'bt') del mando con esa MAC, o None."""
    if not clave:
        return None
    for ruta, bus, mac in _hidraws_ds5():
        if mac == clave:
            return (ruta, bus)
    return None


def _mac_de_hidraw(base):
    """MAC del mando, mirando uniq, uniq anidado y el uevent del HID."""
    for rel in ("device/uniq", "device/device/uniq"):
        try:
            valor = _leer_texto(os.path.join(base, rel))
        except Exception:
            valor = ""
        if valor:
            return _norm_mac(valor)

    for rel in ("device/uevent", "device/device/uevent"):
        try:
            with open(os.path.join(base, rel), "r",
                      encoding="utf-8", errors="replace") as fh:
                for linea in fh:
                    if linea.startswith("HID_UNIQ="):
                        return _norm_mac(linea.split("=", 1)[1])
        except Exception:
            continue
    return ""


def _hidraws_ds5():
    """[(/dev/hidrawN, 'usb'|'bt', mac)] de los DualSense, en orden."""
    raiz = _raiz_hidraw()
    salida = []
    try:
        nombres = sorted(os.listdir(raiz))
    except Exception:
        return salida

    for nombre in nombres:
        base = os.path.join(raiz, nombre)
        try:
            real = os.path.realpath(os.path.join(base, "device")).upper()
        except Exception:
            real = ""
        if "054C" not in real:
            continue

        # fuera interfaces auxiliares (touchpad, sensores...) si las hubiera
        nombre_hid = ""
        try:
            for linea in _leer_texto(os.path.join(base, "device/uevent")).splitlines():
                if linea.startswith("HID_NAME="):
                    nombre_hid = linea.split("=", 1)[1].strip().lower()
                    break
        except Exception:
            pass
        if any(x in nombre_hid for x in ("touchpad", "motion sensor", "sensors")):
            continue

        bus = "bt" if "0005:" in real else "usb"
        salida.append((os.path.join(_devdir(), nombre), bus, _mac_de_hidraw(base)))
    return salida


def _diagnostico_hidraw(buscando):
    raiz = _raiz_hidraw()
    lineas = ["No encuentro su /dev/hidraw.",
              "  buscando: %s" % (buscando or "-")]
    try:
        nombres = sorted(os.listdir(raiz))
    except Exception as exc:
        lineas.append("  no puedo leer %s: %s" % (raiz, exc))
        return "\n".join(lineas)

    lineas.append("  %s: %s" % (raiz, ", ".join(nombres[:8]) or "(vacia)"))
    for nombre in nombres[:8]:
        base = os.path.join(raiz, nombre)
        uniq = ""
        for rel in ("device/uniq", "device/device/uniq"):
            try:
                uniq = _leer_texto(os.path.join(base, rel))
            except Exception:
                uniq = ""
            if uniq:
                break
        hid_uniq = ""
        hid_id = ""
        try:
            for linea in _leer_texto(os.path.join(base, "device/uevent")).splitlines():
                if linea.startswith("HID_UNIQ="):
                    hid_uniq = linea.split("=", 1)[1]
                elif linea.startswith("HID_ID="):
                    hid_id = linea.split("=", 1)[1]
        except Exception:
            pass
        lineas.append("    %s  uniq=%r HID_UNIQ=%r HID_ID=%r"
                      % (nombre, uniq, hid_uniq, hid_id))
    return "\n".join(lineas)


def _reporte_ds5(bus, motor, seq=None):
    comun = bytearray(47)
    comun[0] = 0x01 | 0x02          # compatible vibration + haptics select
    comun[2] = motor & 0xFF         # motor_right
    comun[3] = motor & 0xFF         # motor_left

    if bus == "usb":
        return bytes([0x02]) + bytes(comun) + bytes(15)

    if seq is None:
        seq = _siguiente_seq()
    cuerpo = bytes([0x31, (seq & 0x0F) << 4, 0x10]) + bytes(comun) + bytes(24)
    crc = zlib.crc32(bytes([SEMILLA_CRC]) + cuerpo) & 0xFFFFFFFF
    return cuerpo + crc.to_bytes(4, "little")


FICHEROS_SCRIPTS = (
    SCRIPT, MANDOS, "eden-diagnostico.sh", "eden-nucleo.sh",
    "eden-driver-yuzu.sh", "eden-driver-cemu.sh",
    "eden-plantilla-cemu.xml",
)


def _faltan_scripts(carpeta):
    """Nombres de los scripts que faltan en una instalacion."""
    faltan = []
    for nombre in FICHEROS_SCRIPTS:
        ruta = os.path.join(carpeta, nombre)
        if not (os.path.isfile(ruta) and os.access(ruta, os.R_OK)):
            faltan.append(nombre)
    return faltan


def _hash_scripts(carpeta):
    h = hashlib.sha256()
    for nombre in FICHEROS_SCRIPTS:
        ruta = os.path.join(carpeta, nombre)
        try:
            with open(ruta, "rb") as fh:
                h.update(fh.read())
        except Exception:
            return ""
    return h.hexdigest()[:12]


def _instalado():
    ruta = _script(SCRIPT)
    ok = os.path.isfile(ruta) and os.access(ruta, os.R_OK)
    return ok, ruta


def _version_bundle():
    try:
        with open(os.path.join(SCRIPTS_DIR, "VERSION"), "r",
                  encoding="utf-8", errors="replace") as fh:
            for linea in fh:
                if linea.lower().startswith("version:"):
                    return linea.split(":", 1)[1].strip()
    except Exception:
        pass
    return "?"


def _maquina():
    """Datos de la maquina (DMI). Sirve para poner su logo y su nombre."""
    def leer(campo):
        try:
            with open("/sys/class/dmi/id/%s" % campo, "r",
                      encoding="utf-8", errors="replace") as fh:
                return fh.read().strip()
        except Exception:
            return ""
    return {
        "vendor": leer("sys_vendor"),
        "producto": leer("product_name"),
        "placa": leer("board_name"),
    }


def _maquina_con_integrado(m):
    """True si la maquina es una handheld con mando integrado conocido."""
    t = " ".join([(m or {}).get("vendor", ""),
                  (m or {}).get("producto", ""),
                  (m or {}).get("placa", "")]).lower()
    return any(x in t for x in (
        "asus", "asustek", "rog", "ally",
        "valve", "steam deck", "jupiter", "galileo",
        "msi", "claw", "lenovo", "legion",
    ))


def _leer_plan(nombre):
    """Lee ~/eden-autoconfig/plan-<sistema>.txt (lo escriben los drivers)."""
    ruta = os.path.join(_base(), "plan-%s.txt" % nombre)
    if not os.path.isfile(ruta):
        return None
    datos = {"sistema": nombre, "fecha": "", "modo": "", "max": "", "sdl": "",
             "lib": "", "detectados": "0", "mandos": [], "fuera": [], "aviso": []}
    try:
        with open(ruta, "r", encoding="utf-8", errors="replace") as fh:
            for linea in fh:
                if "=" not in linea:
                    continue
                clave, valor = linea.rstrip("\n").split("=", 1)
                if clave == "mando":
                    partes = valor.split("|")
                    if len(partes) >= 3:
                        datos["mandos"].append(
                            {"n": partes[0], "nombre": partes[1], "clase": partes[2]})
                elif clave in ("fuera", "aviso"):
                    datos[clave].append(valor)
                elif clave in datos:
                    datos[clave] = valor
    except Exception:
        return None
    return datos


def _conexion(guid):
    bus = (guid or "")[:2].lower()
    if bus == "05":
        return "Bluetooth"
    if bus == "03":
        return "USB"
    if bus == "06":
        return "Virtual"
    return "?"


def _clase(nombre, guid, virtual):
    n = (nombre or "").lower()
    if "dualsense" in n or "wireless controller" in n:
        return "DualSense"
    if any(x in n for x in ("rog", "ally", "asus", "x-box", "xbox")):
        return "Integrado"
    if virtual:
        return "Pad virtual"
    return "Otro"


def _familia(nombre, guid, virtual):
    """Familia del mando: decide el icono del panel.

    'playstation' | 'xbox' | 'switch' | 'steam' | 'integrado' | 'desconocido'
    """
    n = (nombre or "").lower()
    vendor = guid[8:12].lower() if len(guid) >= 12 else ""

    if "rog" in n or "ally" in n or "asus" in n:
        return "integrado"
    if "xbox" in n or "x-box" in n:
        return "xbox"
    if "dualsense" in n or "wireless controller" in n or vendor == "054c":
        return "playstation"
    if "switch" in n or "pro controller" in n or "joy-con" in n or "joycon" in n:
        return "switch"
    if "steam" in n or virtual or vendor == "de28":
        return "steam"
    return "desconocido"


def _parse_mandos(texto):
    mandos = []
    for cruda in (texto or "").splitlines():
        linea = cruda.strip()
        if not linea or linea.startswith("#"):
            continue
        partes = linea.split("|")
        if len(partes) < 7:
            continue
        nombre, guid, puerto, _tipo, gamepad, nombre_sdl, serie = partes[:7]
        virtual = (guid[8:12].lower() == "de28")
        clase = _clase(nombre if nombre else nombre_sdl, guid, virtual)
        if virtual:
            conexion = "Virtual (Steam)"
        elif clase == "Integrado":
            conexion = "Interno"
        else:
            conexion = _conexion(guid)
        mandos.append({
            "nombre": nombre,
            "sdl": nombre_sdl,
            "clase": clase,
            "familia": _familia(nombre if nombre else nombre_sdl, guid, virtual),
            "conexion": conexion,
            "guid": guid,
            "puerto": puerto,
            "serie": serie,
            "virtual": virtual,
            "gamepad": gamepad == "1",
        })
    # si no hay integrado pero hay un unico pad virtual suelto, es el integrado
    if not any(m["clase"] == "Integrado" for m in mandos):
        virtuales = [m for m in mandos
                     if m["clase"] in ("Otro", "Pad virtual")
                     and m["virtual"] and not m["serie"]]
        if len(virtuales) == 1:
            virtuales[0]["clase"] = "Integrado"
            virtuales[0]["familia"] = "integrado"
            virtuales[0]["conexion"] = "Interno"
    return mandos


def _esde_eventos():
    """True/False si CustomEventScripts esta activo; None si no hay ES-DE."""
    ruta = os.path.join(_home(), "ES-DE", "settings", "es_settings.xml")
    try:
        with open(ruta, "r", encoding="utf-8", errors="replace") as fh:
            texto = fh.read()
    except Exception:
        return None
    m = re.search(r'<bool[^>]*name="CustomEventScripts"[^>]*>', texto)
    if not m:
        return False
    return 'value="true"' in m.group(0)


def _hook_instalado():
    return os.path.isfile(os.path.join(
        _home(), "ES-DE", "scripts", "game-start", "10-eden-autoconfig.sh"))


def _escenario(mandos):
    if not mandos:
        return "sin_mandos"
    ds = [m for m in mandos if m["clase"] == "DualSense"]
    virt = any(m["virtual"] for m in mandos)
    if ds and virt:
        return "steam_input"
    if ds:
        return "nativo"
    if virt:
        return "steam_input_integrado"
    return "solo_integrado"


# -------------------------------------------------------------- plugin ------

class Plugin:

    # ------------------------------------------------------------------ vida
    async def _main(self):
        ok, ruta = _instalado()
        log.info("N.E.C.A listo. HOME=%s scripts=%s",
                 _home(), "instalados" if ok else "NO instalados (%s)" % ruta)
        viejo = os.path.join(os.path.dirname(PLUGIN_DIR), "EdenAutoconfig")
        if os.path.isdir(viejo):
            log.warning("hay una instalacion antigua en %s: desinstalala en Decky "
                        "para no tener dos paneles", viejo)
        if not ok:
            log.info("Pulsa 'Instalar scripts' en el panel para instalarlos.")
            return
        await self._auto_actualizar()

    async def _auto_actualizar(self):
        """Si los scripts instalados estan viejos o incompletos, los repone."""
        faltan = _faltan_scripts(_base())
        has_inst = _hash_scripts(_base())
        has_bundle = _hash_scripts(SCRIPTS_DIR)
        if not faltan and (not has_bundle or has_inst == has_bundle):
            return
        inst = os.path.join(SCRIPTS_DIR, INSTALADOR)
        if not os.path.isfile(inst):
            return
        log.info("scripts desactualizados: auto-instalando desde el bundle")
        rc, salida = await _run(["bash", inst], timeout=180)
        log.info("auto-instalacion: exit %s %s", rc, _corta(salida)[-300:])
        if rc == 0:
            _marcar_scripts()

    async def _unload(self):
        log.info("N.E.C.A descargado (no se toca ~/eden-autoconfig)")

    # --------------------------------------------------------------- estado
    async def estado(self):
        ok, ruta = _instalado()
        prefs = _leer_prefs()
        mandos = []
        salida = ""
        salida_who = ""
        aviso = ""
        maquina = _maquina()

        if ok:
            # El ayudante soporta EDEN_FAKE_SDL; panel y --who trabajan con la
            # misma lista y los mismos puertos reales.
            rc, salida = await _run(["bash", _script(MANDOS)], timeout=45)
            mandos = _parse_mandos(salida)
            if rc != 0 and not mandos:
                aviso = ("No he podido interrogar a SDL:\n" +
                         _corta(salida)[-800:])
        else:
            aviso = ("Los scripts no estan instalados en %s.\n"
                     "Pulsa 'Instalar scripts' para copiarlos desde el plugin."
                     % _base())

        ds = [m for m in mandos if m["clase"] == "DualSense"]
        ds_n = len(ds)

        prefs, nota_int = _auto_integrado(prefs, ds_n)
        prefs, nota_principal = _sincronizar_principal(prefs, ds)
        for n in (nota_int, nota_principal):
            if n:
                aviso = ((aviso + "\n") if aviso else "") + n

        # Los jugadores los decide el script (`--who`): aqui no se reimplementa.
        if ok:
            args_who = ["bash", _script(SCRIPT), "--who"]
            # En una consola con mando integrado, Steam Input solo lo expone
            # dentro de la sesion de ES-DE. Para las tarjetas mostramos el plan
            # esperado; el aplicar/hook sigue usando la deteccion real.
            if _maquina_con_integrado(maquina):
                args_who.append("--asumir-integrado")
            _rc, salida_who = await _run(args_who, timeout=60)
        plan = _parse_who(salida_who if ok else "")
        _marcar_integrado_plan(mandos, plan)

        limite = int(prefs["JUGADORES_MAX"])
        for m in mandos:
            m["principal"] = bool(prefs["P1_SERIE"]) and m["serie"] == prefs["P1_SERIE"]
            if m["clase"] == "Integrado":
                jug = plan["integrado"]
            elif m["clase"] == "DualSense":
                # Los DualSense virtuales se planifican como "dual", no como
                # "virtual"; probar ambos para que el panel muestre P1/P2.
                jug = plan["dual"].get(m["puerto"])
                if jug is None:
                    jug = plan["virtual"].get(m["puerto"])
            elif m["virtual"]:
                jug = plan["virtual"].get(m["puerto"])
            else:
                jug = None
            # el script puede repartir mas jugadores de los configurados
            m["jugador"] = jug if (jug is not None and jug <= limite) else None

        _marcar_principal(mandos, prefs, plan["integrado"])

        # Steam Input a veces repite la misma serie en varios pads: se avisa,
        # porque entonces no se pueden distinguir entre si.
        series = [m["serie"] for m in mandos if m["serie"]]
        dups = sorted({s for s in series if series.count(s) > 1})
        if dups:
            aviso = ((aviso + "\n") if aviso else "") + (
                "La serie se repite en varios mandos (%s).\n"
                "No se pueden distinguir: manda el orden de conexion."
                % ", ".join(dups[:3]))

        if len(mandos) >= 2 and all(m["virtual"] for m in mandos):
            aviso = ((aviso + "\n") if aviso else "") + (
                "Steam Input presenta todos los mandos como pads virtuales: "
                "el orden de jugadores lo decide Steam. Si P2/P3 no coinciden, "
                "desactiva Steam Input para ES-DE o reordena los mandos en Steam.")

        has_inst = _hash_scripts(_base())
        has_bundle = _hash_scripts(SCRIPTS_DIR)
        faltan = _faltan_scripts(_base()) if ok else []

        return {
            "ok": True,
            "instalado": ok,
            "ruta": ruta,
            "base": _base(),
            "conf": _conf(),
            "prefs": prefs,
            "mandos": mandos,
            "escenario": _escenario(mandos),
            "ds_conectados": ds_n,
            "otros_conectados": len([m for m in mandos if m["clase"] == "Otro"]),
            "jugador_integrado": plan["integrado"],
            "integrado_nombre": plan.get("integrado_nombre", ""),
            "hook": _hook_instalado(),
            "esde": _esde_eventos(),
            "version": _version_bundle(),
            "hash_instalado": has_inst,
            "scripts_nuevos": _scripts_recientes(),
            "faltan": faltan,
            "reparar": bool(ok and faltan),
            "desactualizado": bool(
                ok and (faltan or (has_bundle and has_inst and has_inst != has_bundle))
            ),
            "planes": {"wiiu": _leer_plan("wiiu")},
            "maquina": maquina,
            "aviso": aviso,
        }

    # ------------------------------------------------------------- acciones
    async def contar(self):
        """Numero de gamepads que ve SDL ahora mismo (sondeo ligero)."""
        ok, _ = _instalado()
        if not ok:
            return 0
        rc, salida = await _run(["bash", _script(MANDOS)], timeout=30)
        if rc != 0:
            return -1
        return len(_parse_mandos(salida))

    async def comprobar(self):
        """Recalcula el plan de Cemu sin escribir nada (para el panel)."""
        ok, _ = _instalado()
        if not ok:
            return await self.estado()
        notas = []
        for sistema, etiqueta in (("wiiu", "Cemu"),):
            rc, salida = await _run(
                ["bash", _script(SCRIPT), "--sistema", sistema, "--dry-run"],
                timeout=90,
            )
            if rc not in (0, 2):
                notas.append("%s: %s" % (etiqueta, _corta(salida).splitlines()[-1]
                                         if _corta(salida) else "error %s" % rc))
        estado = await self.estado()
        if notas:
            estado["aviso"] = "\n".join(notas)
        return estado

    async def alternar_principal(self, serie):
        """Marca/desmarca un mando concreto como Player 1."""
        serie = (serie or "").strip()
        prefs = _leer_prefs()
        if not serie:
            return await self.estado()

        if prefs["P1_SERIE"] == serie:
            prefs["P1_SERIE"] = ""
        else:
            prefs["P1_SERIE"] = serie
            # al elegir un mando externo como Player 1, el integrado pasa a ultimo
            prefs["ORDEN_INTEGRADO"] = "ultimo"
            prefs["INTEGRADO_MANUAL"] = "no"
        ok, msg = _escribir_prefs(prefs)
        estado = await self.estado()
        if not ok:
            estado["aviso"] = msg
        return estado

    async def integrado_modo(self, modo):
        """Elige el hueco del mando integrado: primero | ultimo | ignorar."""
        modo = (modo or "").strip()
        if modo not in INTEGRADOS:
            return await self.estado()
        prefs = _leer_prefs()
        prefs["ORDEN_INTEGRADO"] = modo
        prefs["INTEGRADO_MANUAL"] = "si"
        if modo == "primero":
            # el integrado pasa a Player 1 y los externos se corren un puesto
            prefs["P1_SERIE"] = ""
        ok, msg = _escribir_prefs(prefs)
        estado = await self.estado()
        if not ok:
            estado["aviso"] = msg
        return estado

    async def ciclar(self, clave):
        """Cicla la cantidad de jugadores ('max')."""
        prefs = _leer_prefs()

        if clave == "max":
            n = int(prefs["JUGADORES_MAX"])
            prefs["JUGADORES_MAX"] = str(1 if n >= 4 else n + 1)
        else:
            return await self.estado()

        ok, msg = _escribir_prefs(prefs)
        estado = await self.estado()
        if not ok:
            estado["aviso"] = msg
        return estado

    async def aplicar(self):
        """Escribe solo Eden (API/legado; el panel usa aplicar_todo)."""
        ok, _ = _instalado()
        if not ok:
            return {"exit": 4, "salida": "Los scripts no estan instalados."}
        # sincroniza antes (p. ej. el integrado con 4 DualSense)
        await self.estado()
        rc, salida = await _run(["bash", _script(SCRIPT)], timeout=120)
        return {"exit": rc, "salida": _corta(salida), "mensaje": _mensaje_exit(rc)}

    async def aplicar_todo(self):
        """Escribe Eden y Cemu con las preferencias guardadas."""
        ok, _ = _instalado()
        if not ok:
            return {"ok": False, "exit": 4,
                    "salida": "Los scripts no estan instalados."}
        # sincroniza antes (p. ej. el integrado con 4 DualSense)
        await self.estado()

        lineas = []
        errores = []
        for sistema, etiqueta in (("switch", "Eden"), ("wiiu", "Cemu")):
            rc, salida = await _run(
                ["bash", _script(SCRIPT), "--sistema", sistema], timeout=120)
            texto = _corta(salida).strip()
            ultima = texto.splitlines()[-1].strip() if texto else ""
            if rc == 0:
                lineas.append("%s: %s" % (etiqueta, ultima or "aplicado"))
            elif rc == 2:
                lineas.append("%s: nada que asignar, sin cambios" % etiqueta)
            elif rc == 3:
                errores.append("%s: en ejecucion, cierralo y reintenta" % etiqueta)
            elif rc == 4:
                lineas.append("%s: no encontrado, sin cambios" % etiqueta)
            else:
                errores.append("%s: %s" % (etiqueta,
                                           ultima or _mensaje_exit(rc)))

        salida = "\n".join(lineas + errores) or "nada que hacer"
        if not errores:
            _limpiar_marca_scripts()
        return {"ok": not errores,
                "exit": 0 if not errores else 1,
                "salida": salida,
                "mensaje": "hecho" if not errores else "con problemas"}

    async def restaurar_todo(self):
        """Vuelve al estado anterior a N.E.C.A: config, preferencias y hook."""
        base = _base()
        backups = os.path.join(base, "backups")
        stock_dir = os.path.join(base, "stock")
        stock = os.path.join(stock_dir, "qt-config.ini")

        lineas = []
        errores = []

        # 1) copia fija del original (la primera vez, la mas antigua)
        copias = []
        if os.path.isdir(backups):
            for nombre in os.listdir(backups):
                if (nombre.startswith("qt-config.ini.")
                        and "stock" not in nombre):
                    copias.append(os.path.join(backups, nombre))
        copias.sort(key=lambda p: os.path.getmtime(p))

        if not os.path.isfile(stock):
            if not copias:
                return {"ok": False,
                        "salida": "No hay ninguna copia de seguridad: no puedo "
                                  "volver al estado original."}
            try:
                os.makedirs(stock_dir, exist_ok=True)
                shutil.copyfile(copias[0], stock)
                lineas.append("Original guardado en %s" % stock)
            except Exception as exc:
                return {"ok": False,
                        "salida": "No puedo guardar el original: %s" % exc}
        else:
            lineas.append("Usando el original guardado (%s)" % stock)

        # 2) restaurar con el script (valida y copia el estado actual)
        tmp_restore = os.path.join(backups, "qt-config.ini.stock-restore")
        try:
            os.makedirs(backups, exist_ok=True)
            shutil.copyfile(stock, tmp_restore)
        except Exception as exc:
            return {"ok": False,
                    "salida": "No puedo preparar la restauracion: %s" % exc}

        rc, _salida = await _run(
            ["bash", _script(SCRIPT), "--restore", "stock-restore"], timeout=90)
        try:
            os.remove(tmp_restore)
        except Exception:
            pass

        if rc == 0:
            lineas.append("Eden: qt-config.ini restaurado al estado original")
        else:
            errores.append("restaurar Eden: %s" % _mensaje_exit(rc))

        # 2b) Cemu: deshace el ultimo aplicar (latest)
        for sistema, etiqueta in (("wiiu", "Cemu"),):
            rc, salida = await _run(
                ["bash", _script(SCRIPT), "--sistema", sistema, "--restore"],
                timeout=90)
            texto = _corta(salida).strip()
            lineas_ok = [l.strip() for l in texto.splitlines()
                         if l.strip() and not l.strip().lower().startswith("aviso")]
            if rc == 0:
                if lineas_ok:
                    lineas.append("%s: %s" % (etiqueta, ", ".join(lineas_ok)))
                elif "no hay copia" in texto.lower():
                    lineas.append("%s: sin copias, no se toca" % etiqueta)
                else:
                    lineas.append("%s: sin cambios" % etiqueta)
            elif rc == 4:
                lineas.append("%s: no encontrado, sin cambios" % etiqueta)
            elif "no hay copia" in texto.lower():
                lineas.append("%s: sin copias, no se toca" % etiqueta)
            else:
                detalle = lineas_ok[-1] if lineas_ok else _mensaje_exit(rc)
                errores.append("%s: %s" % (etiqueta, detalle))

        # 3) quitar preferencias del plugin
        ok, habia = _quitar_bloque()
        if not ok:
            errores.append("no pude limpiar las preferencias del .conf")
        elif habia:
            lineas.append("Preferencias del plugin eliminadas del .conf")
        else:
            lineas.append("No habia preferencias guardadas")

        # 4) desactivar el hook de ES-DE
        hook = os.path.join(_home(), "ES-DE", "scripts", "game-start",
                            "10-eden-autoconfig.sh")
        fuera = os.path.join(_home(), "ES-DE", "scripts",
                             "10-eden-autoconfig.sh.desactivado")
        if os.path.isfile(hook):
            try:
                os.makedirs(os.path.dirname(fuera), exist_ok=True)
                os.replace(hook, fuera)
                lineas.append("Hook de ES-DE desactivado")
            except Exception as exc:
                errores.append("no pude desactivar el hook: %s" % exc)
        else:
            lineas.append("El hook ya estaba desactivado")

        texto = "\n".join(lineas)
        if errores:
            texto += ("\n\nProblemas:\n" if texto else "") + "\n".join(errores)
        return {"ok": not errores, "salida": texto}

    async def vibrar(self, serie, puerto=""):
        """Pulso corto de vibracion en un mando (para identificarlo)."""
        clave = _norm_mac(serie)
        if not clave:
            return {"ok": False, "salida": "Ese mando no informa de su serie."}

        destino = _hidraw_de(clave)
        metodo = "por MAC"

        if not destino:
            sony = _hidraws_ds5()
            indice = int(puerto) if str(puerto).isdigit() else -1
            if len(sony) == 1:
                destino = (sony[0][0], sony[0][1])
                metodo = "unico DualSense"
            elif 0 <= indice < len(sony):
                destino = (sony[indice][0], sony[indice][1])
                metodo = "por orden"

        if not destino:
            return {"ok": False, "salida": _diagnostico_hidraw(clave)}

        ruta, bus = destino
        try:
            with open(ruta, "wb") as fh:
                fh.write(_reporte_ds5(bus, MOTOR_PULSO))
        except Exception as exc:
            return {"ok": False,
                    "salida": "No puedo escribir en %s (%s)." % (ruta, exc)}

        # la parada va en la misma llamada: nunca se queda vibrando
        await asyncio.sleep(PULSO_S)
        try:
            with open(ruta, "wb") as fh:
                fh.write(_reporte_ds5(bus, 0))
        except Exception:
            pass

        return {"ok": True,
                "salida": "vibrando (%s · %s)" % (metodo, os.path.basename(ruta))}

    async def ver_log(self, sistema="todo"):
        try:
            with open(_log_txt(), "r", encoding="utf-8", errors="replace") as fh:
                lineas = fh.readlines()
        except FileNotFoundError:
            return {"salida": "todavia no hay log (%s)" % _log_txt()}
        except Exception as exc:
            return {"salida": "no puedo leer el log: %s" % exc}

        # El panel llama a --who cada pocos segundos; esas lineas (7 por
        # llamada) inundan el log y esconden los aplicar. Se quitan al vuelo.
        limpias = []
        saltar = 0
        for linea in lineas:
            if "modo=who" in linea:
                saltar = 6
                continue
            if saltar > 0:
                saltar -= 1
                continue
            limpias.append(linea)

        sistema = (sistema or "todo").strip().lower()
        if sistema == "cemu":
            # El driver de Cemu escribe con la etiqueta "wiiu".
            limpias = [l for l in limpias
                       if "cemu" in l.lower() or "wiiu" in l.lower()]
        elif sistema == "eden":
            # Ultimo bloque de Eden: desde su cabecera hasta el siguiente
            # driver (que empieza por "[fecha]").
            idx = None
            for i, l in enumerate(limpias):
                if "=== eden-autoconfig.sh" in l:
                    idx = i
            if idx is not None:
                bloque = []
                for l in limpias[idx:]:
                    if bloque and l.startswith("["):
                        break
                    bloque.append(l)
                limpias = bloque
            else:
                limpias = [l for l in limpias if "eden" in l.lower()]
        return {"salida": "".join(limpias[-600:]) or "(log vacio)"}

    async def instalar_scripts(self):
        inst = os.path.join(SCRIPTS_DIR, INSTALADOR)
        if not os.path.isfile(inst):
            return {"ok": False, "exit": 1,
                    "salida": "falta %s en el plugin (bundle incompleto)" % inst}
        rc, salida = await _run(["bash", inst], timeout=240, cwd=SCRIPTS_DIR)
        if rc == 0:
            _marcar_scripts()
        return {"ok": rc == 0, "exit": rc, "salida": _corta(salida)}


def _mensaje_exit(rc):
    return {
        0: "hecho",
        1: "error (mira el resultado)",
        2: "no habia nada que hacer",
        3: "Eden esta en ejecucion: cierralo y reintenta",
        4: "no encuentro qt-config.ini de Eden",
        5: "no encuentro la plantilla del perfil",
    }.get(rc, "salida %s" % rc)
