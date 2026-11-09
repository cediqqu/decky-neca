#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
#  test_backend.py -- pruebas del backend sin Decky ni consola
# =============================================================================
#  Uso:   python3 test_backend.py
#
#  Monta un HOME falso, ejecuta las funciones de main.py de verdad y usa
#  EDEN_FAKE_SDL (el mismo gancho que eden-autoconfig.sh) para simular mandos.
#  No toca nada real: todo vive en un directorio temporal.
# =============================================================================

import asyncio
import importlib.util
import logging
import os
import shutil
import subprocess
import sys
import tempfile
import types

AQUI = os.path.dirname(os.path.abspath(__file__))

FALLOS = []
TOTAL = 0


def check(nombre, cond, detalle=""):
    global TOTAL
    TOTAL += 1
    if cond:
        print("  ok    %s" % nombre)
    else:
        FALLOS.append(nombre)
        print("  FALLO %s   %s" % (nombre, str(detalle)[:300]))


def cargar(home):
    """Importa main.py con un 'decky' de mentira."""
    decky = types.ModuleType("decky")
    decky.DECKY_USER_HOME = home
    decky.logger = logging.getLogger("decky")
    sys.modules["decky"] = decky
    ruta = os.path.join(AQUI, "main.py")
    spec = importlib.util.spec_from_file_location("plugin_main", ruta)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


SDL_FAKE = """\
#lib libSDL3.so.0 version 3.2.0 (simulada)
#origen sistema (CRC normalizado a 0 = guids de Eden)
DualSense Wireless Controller|050000004c050000e60c000000010000|0|6|1|DualSense Wireless Controller|4c:b9:9b:e9:bc:26
DualSense Wireless Controller|050000004c050000e60c000000010000|1|6|1|DualSense Wireless Controller|48:18:fd:11:4a:0a
Asus Rog Ally Controller|03000000bd1200001501000011010000|0|1|1|Asus Rog Ally Controller|
Pad sin serie|03000000000000000000000000000000|0|1|1|Pad sin serie|
"""


async def main():
    tmp = tempfile.mkdtemp(prefix="eden-plugin-test-")
    home = os.path.join(tmp, "home")
    os.makedirs(home)
    os.makedirs(os.path.join(home, "ES-DE"))          # para que instalar.sh ponga el hook
    conf_dir = os.path.join(home, "eden-autoconfig")
    os.environ["HOME"] = home

    mod = cargar(home)
    base = os.path.join(home, "eden-autoconfig")

    # ------------------------------------------------------------------ 1
    print("1) sin scripts instalados")
    est = await mod.Plugin().estado()
    check("instalado=False", est["instalado"] is False)
    check("avisa de que faltan", "no estan instalados" in est["aviso"])
    check("sin mandos", est["mandos"] == [])

    # ------------------------------------------------------------------ 2
    print("2) instalar scripts (ejecuta scripts/instalar.sh del bundle)")
    r = await mod.Plugin().instalar_scripts()
    check("instalar ok", r["ok"] is True, r["salida"])
    for f in ("eden-autoconfig.sh", "eden-mandos-sdl.sh",
              "eden-diagnostico.sh", "eden-autoconfig.conf"):
        check("existe %s" % f, os.path.isfile(os.path.join(base, f)))
    check("hook de ES-DE",
          os.path.isfile(os.path.join(home, "ES-DE", "scripts", "game-start",
                                      "10-eden-autoconfig.sh")))

    est = await mod.Plugin().estado()
    check("ahora instalado", est["instalado"] is True)
    check("no marca desactualizado", est["desactualizado"] is False)
    check("scripts recien instalados", est["scripts_nuevos"] is True)
    check("sin SDL avisa y no rompe", "SDL" in est["aviso"] or est["mandos"] == [],
          est["aviso"])

    # si falta un script nuevo (instalacion antigua) hay que ofrecer reparar
    falta = os.path.join(base, "eden-driver-cemu.sh")
    with open(falta, "w", encoding="utf-8") as fh:
        fh.write("#!/bin/bash\n")
    est = await mod.Plugin().estado()
    check("hash distinto -> desactualizado", est["desactualizado"] is True)
    check("no es reparacion (esta todo)", est["reparar"] is False, est.get("faltan"))
    os.remove(falta)
    est = await mod.Plugin().estado()
    check("falta fichero -> desactualizado", est["desactualizado"] is True)
    check("falta fichero -> reparar", est["reparar"] is True)
    check("dice cual falta", "eden-driver-cemu.sh" in est["faltan"], est.get("faltan"))
    r = await mod.Plugin().instalar_scripts()
    check("reinstalar arregla", r["ok"] is True, r["salida"])
    est = await mod.Plugin().estado()
    check("ya no falta nada", est["reparar"] is False and est["desactualizado"] is False)

    # al cargar, el plugin repone solo lo que falte
    os.remove(os.path.join(base, "eden-driver-cemu.sh"))
    await mod.Plugin()._main()
    est = await mod.Plugin().estado()
    check("auto-repara al cargar", est["reparar"] is False, est.get("faltan"))

    # el plan que dejan los drivers se lee para el panel
    with open(os.path.join(base, "plan-wiiu.txt"), "w", encoding="utf-8") as fh:
        fh.write("fecha=2026-01-01 10:00:00\nsistema=wiiu\nmodo=aplicar\n"
                 "max=3\nsdl=ok\nlib=libSDL3\ndetectados=2\n"
                 "mando=1|DualSense Wireless Controller 1|dual\n"
                 "mando=2|Asus Rog Ally Controller|integrado\n"
                 "aviso=el integrado no entra\n")
    est = await mod.Plugin().estado()
    plan = est["planes"]["wiiu"]
    check("lee el plan de Cemu", plan is not None and len(plan["mandos"]) == 2,
          plan)
    check("mando 1 del plan", plan["mandos"][0]["nombre"].startswith("DualSense"),
          plan["mandos"][0])
    check("aviso del plan", plan["aviso"] == ["el integrado no entra"], plan["aviso"])
    check("datos de la maquina", isinstance(est.get("maquina"), dict)
          and set(est["maquina"]) == {"vendor", "producto", "placa"},
          est.get("maquina"))

    # ------------------------------------------------------------------ 3
    print("3) deteccion simulada (EDEN_FAKE_SDL)")
    fake = os.path.join(tmp, "sdl.txt")
    with open(fake, "w", encoding="utf-8") as fh:
        fh.write(SDL_FAKE)
    os.environ["EDEN_FAKE_SDL"] = fake

    est = await mod.Plugin().estado()
    check("4 mandos", len(est["mandos"]) == 4, [m["nombre"] for m in est["mandos"]])
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("2 DualSense", len(ds) == 2)
    check("conexion Bluetooth", all(m["conexion"] == "Bluetooth" for m in ds),
          [m["conexion"] for m in ds])
    check("puertos 0 y 1", [m["puerto"] for m in ds] == ["0", "1"])
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    check("integrado Interno", len(integ) == 1 and integ[0]["conexion"] == "Interno",
          [(m["clase"], m["conexion"]) for m in est["mandos"]])
    check("escenario nativo", est["escenario"] == "nativo", est["escenario"])
    check("nadie es principal al empezar", not any(m["principal"] for m in est["mandos"]))

    # ------------------------------------------------------------------ 4
    print("4) elegir Player 1")
    conf = os.path.join(base, "eden-autoconfig.conf")
    with open(conf, "r", encoding="utf-8") as fh:
        antes = fh.read()

    est = await mod.Plugin().alternar_principal("4c:b9:9b:e9:bc:26")
    with open(conf, "r", encoding="utf-8") as fh:
        despues = fh.read()

    check("escribe el bloque", mod.BEGIN in despues and mod.END in despues)
    check("P1_SERIE correcto", 'P1_SERIE="4c:b9:9b:e9:bc:26"' in despues)
    check("el resto del .conf no cambia",
          despues.split(mod.BEGIN)[0] == antes.split(mod.BEGIN)[0])
    check("un solo bloque", despues.count(mod.BEGIN) == 1)
    princ = [m for m in est["mandos"] if m["principal"]]
    check("un unico principal",
          len(princ) == 1 and princ[0]["serie"] == "4c:b9:9b:e9:bc:26", princ)
    check("elegir un externo manda el integrado al final",
          est["prefs"]["ORDEN_INTEGRADO"] == "ultimo", est["prefs"])

    estado_dir = os.path.join(home, ".config", "eden-autoconfig-decky")
    check("backup del .conf fuera del proyecto",
          os.path.isdir(estado_dir) and any(x.endswith(".bak")
                                            for x in os.listdir(estado_dir)))

    est = await mod.Plugin().alternar_principal("4c:b9:9b:e9:bc:26")
    check("volver a pulsar lo libera", not any(m["principal"] for m in est["mandos"]))

    await mod.Plugin().alternar_principal("4c:b9:9b:e9:bc:26")
    est = await mod.Plugin().alternar_principal("48:18:fd:11:4a:0a")
    princ = [m for m in est["mandos"] if m["principal"]]
    check("cambiar de mando no acumula",
          len(princ) == 1 and princ[0]["serie"] == "48:18:fd:11:4a:0a", princ)

    est = await mod.Plugin().alternar_principal("")
    check("serie vacia no rompe", len([m for m in est["mandos"] if m["principal"]]) <= 1)

    # ------------------------------------------------------------------ 5
    print("5) ajustes que ciclan")
    est = await mod.Plugin().ciclar("max")
    check("max 4 -> 1", est["prefs"]["JUGADORES_MAX"] == "1", est["prefs"])
    for _ in range(3):
        est = await mod.Plugin().ciclar("max")
    check("max vuelve a 4", est["prefs"]["JUGADORES_MAX"] == "4", est["prefs"])

    est = await mod.Plugin().integrado_modo("primero")
    check("con DS, primero pasa a ultimo",
          est["prefs"]["ORDEN_INTEGRADO"] == "ultimo"
          and est["prefs"]["INTEGRADO_MANUAL"] == "no", est["prefs"])
    check("Jugador 1 limpia el principal externo", est["prefs"]["P1_SERIE"] == "")
    est = await mod.Plugin().integrado_modo("ultimo")
    check("integrado -> ultimo", est["prefs"]["ORDEN_INTEGRADO"] == "ultimo")
    est = await mod.Plugin().integrado_modo("ignorar")
    check("integrado -> desactivado", est["prefs"]["ORDEN_INTEGRADO"] == "ignorar")
    est = await mod.Plugin().integrado_modo("loquesea")
    check("modo invalido no rompe", est["ok"] is True)

    est = await mod.Plugin().ciclar("clave-que-no-existe")
    check("clave desconocida no rompe", est["ok"] is True)

    # ------------------------------------------------------------------ 6
    print("6) valores peligrosos no llegan al .conf")
    await mod.Plugin().alternar_principal('x"; rm -rf / #')
    with open(conf, "r", encoding="utf-8") as fh:
        txt = fh.read()
    check("sin inyeccion de shell", "rm -rf" not in txt)
    for linea in txt.splitlines():
        if linea.startswith("P1_SERIE="):
            check("P1_SERIE saneado", linea in ('P1_SERIE=""',),
                  linea)

    # ------------------------------------------------------------------ 7
    print("7) aplicar sin Eden instalado")
    r = await mod.Plugin().aplicar()
    check("aplicar devuelve mensaje", bool(r.get("mensaje")), r)
    check("aplicar sin Eden -> no toca nada", r["exit"] in (1, 4), r["exit"])

    # ------------------------------------------------------------------ 8
    print("8) log")
    with open(os.path.join(base, "log.txt"), "w", encoding="utf-8") as fh:
        fh.write("linea vieja\nlinea nueva\n")
    r = await mod.Plugin().ver_log()
    check("lee el log", "linea nueva" in r["salida"], r["salida"])

    # ------------------------------------------------------------------ 9
    print("9) idempotencia")
    for _ in range(3):
        await mod.Plugin().ciclar("orden")
    with open(conf, "r", encoding="utf-8") as fh:
        txt = fh.read()
    check("sigue habiendo un solo bloque", txt.count(mod.BEGIN) == 1)
    check("no crece sin control", len(txt) < 12000, len(txt))

    # ------------------------------------------------------------------ 10
    print("10) series duplicadas (tipico de Steam Input)")
    dup = os.path.join(tmp, "sdl_dup.txt")
    with open(dup, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Controller|03000000de280000ff11000001000000|0|6|1|DualSense Controller|4c:b9:9b:e9:bc:26\n"
            "DualSense Controller|03000000de280000ff11000001000000|1|6|1|DualSense Controller|4c:b9:9b:e9:bc:26\n"
        )
    os.environ["EDEN_FAKE_SDL"] = dup
    est = await mod.Plugin().estado()
    check("avisa de series repetidas", "repite" in est["aviso"], est["aviso"])
    check("marca los dos como virtuales",
          all(m["conexion"] == "Virtual (Steam)" for m in est["mandos"]),
          [m["conexion"] for m in est["mandos"]])
    check("escenario steam_input", est["escenario"] == "steam_input", est["escenario"])

    # ------------------------------------------------------------------ 11
    print("11) avisos de ES-DE")
    est = await mod.Plugin().estado()
    check("hook detectado", est["hook"] is True)
    check("sin es_settings.xml no adivina", est["esde"] is None, est["esde"])

    cfg_dir = os.path.join(home, "ES-DE", "settings")
    os.makedirs(cfg_dir, exist_ok=True)
    xml = os.path.join(cfg_dir, "es_settings.xml")
    with open(xml, "w", encoding="utf-8") as fh:
        fh.write('<config><bool name="CustomEventScripts" value="false"/></config>')
    est = await mod.Plugin().estado()
    check("eventos desactivados", est["esde"] is False)

    with open(xml, "w", encoding="utf-8") as fh:
        fh.write('<config><bool value="true" name="CustomEventScripts"/></config>')
    est = await mod.Plugin().estado()
    check("eventos activados (atributos al reves)", est["esde"] is True)

    # ------------------------------------------------------------------ 12
    print("12) plan de jugadores (--who)")
    cfg = os.path.join(home, ".config", "eden", "qt-config.ini")
    os.makedirs(os.path.dirname(cfg), exist_ok=True)
    with open(cfg, "w", encoding="utf-8") as fh:
        fh.write("[Controls]\n")
        for i in range(10):
            fh.write("player_%d_profile_name=\n" % i)

    plan = os.path.join(tmp, "plan.txt")
    with open(plan, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Wireless Controller|050000004c050000e60c000000010000|0|6|1|DualSense Wireless Controller|4c:b9:9b:e9:bc:26\n"
            "DualSense Wireless Controller|050000004c050000e60c000000010000|1|6|1|DualSense Wireless Controller|48:18:fd:11:4a:0a\n"
            "Asus Rog Ally Controller|03000000bd1200001501000011010000|0|1|1|Asus Rog Ally Controller|\n"
        )
    os.environ["EDEN_FAKE_SDL"] = plan

    await mod.Plugin().integrado_modo("ignorar")
    est = await mod.Plugin().estado()
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("P1 y P2 salen del script", [m["jugador"] for m in ds] == [1, 2],
          [(m["puerto"], m["jugador"]) for m in ds])
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    check("integrado sin jugador (ignorar)", integ and integ[0]["jugador"] is None,
          [(m["clase"], m["jugador"]) for m in est["mandos"]])

    # con el integrado como ultimo, el script le da el Player 3
    await mod.Plugin().integrado_modo("ultimo")
    est = await mod.Plugin().estado()
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    check("integrado como Player 3", integ and integ[0]["jugador"] == 3,
          est["prefs"])

    # ------------------------------------------------------------------ 13
    print("13) 4 DualSense: el integrado reserva P4")
    cuatro = os.path.join(tmp, "cuatro.txt")
    with open(cuatro, "w", encoding="utf-8") as fh:
        for i in range(4):
            fh.write(
                "DualSense Wireless Controller|050000004c050000e60c000000010000"
                "|%d|6|1|DualSense Wireless Controller|4c:b9:9b:e9:bc:%02d\n"
                % (i, i)
            )
        fh.write("Asus Rog Ally Controller|03000000bd1200001501000011010000"
                 "|0|1|1|Asus Rog Ally Controller|\n")
    os.environ["EDEN_FAKE_SDL"] = cuatro

    est = await mod.Plugin().estado()
    check("4 DualSense detectados", est["ds_conectados"] == 4, est["ds_conectados"])
    check("la eleccion no se toca",
          est["prefs"]["ORDEN_INTEGRADO"] == "ultimo", est["prefs"])
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    ds_on = [m for m in ds if m["jugador"] is not None]
    check("3 DS P1..P3 y el de P4 fuera",
          [m["jugador"] for m in ds_on] == [1, 2, 3]
          and [m["puerto"] for m in ds_on] == ["0", "1", "2"]
          and len([m for m in ds if m["jugador"] is None]) == 1,
          [(m["puerto"], m["jugador"]) for m in ds])
    ds_off = [m for m in ds if m["jugador"] is None]
    check("el DS de P4 es el que se cae",
          len(ds_off) == 1 and ds_off[0]["puerto"] == "3",
          [(m["puerto"], m["jugador"]) for m in ds])
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    check("el integrado ocupa P4", integ and integ[0]["jugador"] == 4,
          [(m["clase"], m["jugador"]) for m in est["mandos"]])

    # vuelven a quedar 2: el integrado recupera su hueco solo
    os.environ["EDEN_FAKE_SDL"] = plan
    est = await mod.Plugin().estado()
    check("sigue en ultimo", est["prefs"]["ORDEN_INTEGRADO"] == "ultimo",
          est["prefs"])
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    check("vuelve a ser Player 3", integ and integ[0]["jugador"] == 3, est["prefs"])

    # ------------------------------------------------------------------ 14
    print("14) parser de --who")
    pw = mod._parse_who(
        "Prediccion de asignacion:\n"
        "      Player 1 = pad virtual Steam 0   (port 0)\n"
        "      Player 2 = pad virtual Steam 1   (port 1)\n"
    )
    check("pads virtuales por puerto", pw["virtual"] == {"0": 1, "1": 2}, pw)
    check("vacio no rompe", mod._parse_who("") ==
          {"dual": {}, "virtual": {}, "integrado": None,
           "integrado_nombre": ""})

    # ------------------------------------------------------------------ 15
    print("15) mando principal automatico")
    uno = os.path.join(tmp, "uno.txt")
    with open(uno, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Wireless Controller|050000004c050000e60c000000010000"
            "|0|6|1|DualSense Wireless Controller|4c:b9:9b:e9:bc:26\n"
            "Asus Rog Ally Controller|03000000bd1200001501000011010000"
            "|0|1|1|Asus Rog Ally Controller|\n"
        )

    # partir sin principal fijado
    prefs = mod._leer_prefs()
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)

    os.environ["EDEN_FAKE_SDL"] = uno
    est = await mod.Plugin().estado()
    check("no se fija solo", est["prefs"]["P1_SERIE"] == "", est["prefs"])
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("estrella en el Player 1", ds and ds[0]["es_principal"] is True,
          [(m["clase"], m["es_principal"]) for m in est["mandos"]])
    check("sin aviso de fijacion", "mando principal" not in est["aviso"],
          est["aviso"])

    os.environ["EDEN_FAKE_SDL"] = plan        # ahora dos DualSense
    est = await mod.Plugin().estado()
    check("sigue sin principal fijado", est["prefs"]["P1_SERIE"] == "",
          est["prefs"])

    # fijado a mano: si desaparece, se libera
    await mod.Plugin().alternar_principal("4c:b9:9b:e9:bc:26")

    tres = os.path.join(tmp, "tres.txt")
    with open(tres, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Wireless Controller|050000004c050000e60c000000010000"
            "|0|6|1|DualSense Wireless Controller|11:11:11:11:11:11\n"
            "DualSense Wireless Controller|050000004c050000e60c000000010000"
            "|1|6|1|DualSense Wireless Controller|22:22:22:22:22:22\n"
        )
    os.environ["EDEN_FAKE_SDL"] = tres
    est = await mod.Plugin().estado()
    check("libera el principal ausente", est["prefs"]["P1_SERIE"] == "", est["prefs"])
    check("avisa de la liberacion", "ya no esta conectado" in est["aviso"], est["aviso"])
    check("hay estrella igualmente",
          len([m for m in est["mandos"] if m["es_principal"]]) == 1,
          [(m["serie"], m["es_principal"]) for m in est["mandos"]])

    # ------------------------------------------------------------------ 16
    print("16) desglose de mandos (cabecera)")
    mixto = os.path.join(tmp, "mixto.txt")
    with open(mixto, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Wireless Controller|050000004c050000e60c000000010000"
            "|0|6|1|DualSense Wireless Controller|4c:b9:9b:e9:bc:26\n"
            "8BitDo Pro 2|03000000c82d00000000000000000000"
            "|0|1|1|8BitDo Pro 2|\n"
        )
    os.environ["EDEN_FAKE_SDL"] = mixto
    est = await mod.Plugin().estado()
    check("cuenta DualSense y otros", (est["ds_conectados"], est["otros_conectados"]) == (1, 1),
          (est["ds_conectados"], est["otros_conectados"]))
    clases = [m["clase"] for m in est["mandos"]]
    check("el 8BitDo es 'Otro'", "Otro" in clases, clases)

    # ------------------------------------------------------------------ 17
    print("17) reporte de vibracion")
    usb = mod._reporte_ds5("usb", mod.MOTOR_PULSO)
    check("USB 63 bytes", len(usb) == 63, len(usb))
    check("USB report id 0x02", usb[0] == 0x02, usb[0])
    check("USB flags vibracion", usb[1] == 0x03, usb[1])
    check("USB motores", (usb[3], usb[4]) == (mod.MOTOR_PULSO,) * 2, (usb[3], usb[4]))

    bt = mod._reporte_ds5("bt", mod.MOTOR_PULSO, seq=7)
    import zlib as _zlib

    check("BT 78 bytes", len(bt) == 78, len(bt))
    check("BT report id 0x31", bt[0] == 0x31, bt[0])
    check("BT secuencia en el nibble alto", bt[1] == 0x70, bt[1])
    check("BT tag 0x10", bt[2] == 0x10, bt[2])
    check("BT flags vibracion", bt[3] == 0x03, bt[3])
    check("BT motores", (bt[5], bt[6]) == (mod.MOTOR_PULSO,) * 2, (bt[5], bt[6]))
    check("BT crc32 con semilla 0xA2",
          _zlib.crc32(b"\xA2" + bt[:-4]) & 0xFFFFFFFF
          == int.from_bytes(bt[-4:], "little"))
    check("el CRC no es el normal (por eso fallaba)",
          _zlib.crc32(bt[:-4]) & 0xFFFFFFFF != int.from_bytes(bt[-4:], "little"))

    # ------------------------------------------------------------------ 18
    print("18) vibrar un mando concreto")
    raiz_hid = os.path.join(tmp, "hidraw")
    devdir = os.path.join(tmp, "dev")
    os.makedirs(os.path.join(raiz_hid, "hidraw3"), exist_ok=True)
    os.makedirs(devdir, exist_ok=True)
    busdir = os.path.join(tmp, "0005:054C:0CE6.0003")
    os.makedirs(busdir, exist_ok=True)
    os.symlink(busdir, os.path.join(raiz_hid, "hidraw3", "device"))
    with open(os.path.join(raiz_hid, "hidraw3", "device", "uniq"), "w",
              encoding="utf-8") as fh:
        fh.write("4c:b9:9b:e9:bc:26\n")
    os.environ["EDEN_HIDRAW_ROOT"] = raiz_hid
    os.environ["EDEN_DEVDIR"] = devdir

    r = await mod.Plugin().vibrar("4c:b9:9b:e9:bc:26")
    check("vibra", r["ok"] is True, r)

    with open(os.path.join(devdir, "hidraw3"), "rb") as fh:
        escrito = fh.read()
    check("acaba con la parada (motores a 0)",
          len(escrito) == 78 and escrito[5] == 0 and escrito[6] == 0,
          (len(escrito), escrito[5:7] if len(escrito) > 6 else b""))

    r = await mod.Plugin().vibrar("")
    check("sin serie avisa", r["ok"] is False and "serie" in r["salida"], r)

    r = await mod.Plugin().vibrar("aa:bb:cc:dd:ee:ff")
    check("con un solo DualSense usa ese",
          r["ok"] is True and "unico" in r["salida"], r)

    print("19) sin uniq: MAC por uevent, y respaldo por orden")
    raiz2 = os.path.join(tmp, "hidraw_b")
    os.makedirs(os.path.join(raiz2, "hidraw4"), exist_ok=True)
    bus4 = os.path.join(tmp, "0003:054C:0CE6.0001")
    os.makedirs(bus4, exist_ok=True)
    os.symlink(bus4, os.path.join(raiz2, "hidraw4", "device"))
    with open(os.path.join(raiz2, "hidraw4", "device", "uevent"), "w",
              encoding="utf-8") as fh:
        fh.write("HID_ID=0003:0000054C:00000CE6\nHID_UNIQ=48:18:fd:11:4a:0a\n")
    os.environ["EDEN_HIDRAW_ROOT"] = raiz2

    r = await mod.Plugin().vibrar("48:18:fd:11:4a:0a")
    check("MAC sacada del uevent", r["ok"] is True and "por MAC" in r["salida"], r)

    # dos DualSense sin MAC en ningun sitio -> por orden de puerto
    raiz3 = os.path.join(tmp, "hidraw_c")
    for nombre, dirbus in (("hidraw5", "0005:054C:0CE6.0001"),
                           ("hidraw6", "0005:054C:0CE6.0002")):
        os.makedirs(os.path.join(raiz3, nombre), exist_ok=True)
        d = os.path.join(tmp, dirbus)
        os.makedirs(d, exist_ok=True)
        os.symlink(d, os.path.join(raiz3, nombre, "device"))
    os.environ["EDEN_HIDRAW_ROOT"] = raiz3
    for nombre in ("hidraw5", "hidraw6"):
        ruta = os.path.join(devdir, nombre)
        if os.path.exists(ruta):
            os.remove(ruta)

    r = await mod.Plugin().vibrar("aa:bb:cc:dd:ee:01")
    check("sin puerto y sin MAC avisa con diagnostico",
          r["ok"] is False and "buscando" in r["salida"], r)

    r = await mod.Plugin().vibrar("aa:bb:cc:dd:ee:01", "1")
    check("por orden usa el segundo", r["ok"] is True and "por orden" in r["salida"], r)
    check("escribe en hidraw6 (no en el 5)",
          os.path.exists(os.path.join(devdir, "hidraw6"))
          and not os.path.exists(os.path.join(devdir, "hidraw5")))

    # ------------------------------------------------------------------ 20
    print("20) familia de cada mando (decide el icono)")
    fam = os.path.join(tmp, "familias.txt")
    with open(fam, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Wireless Controller|050000004c050000e60c000000010000|0|6|1|DualSense Wireless Controller|aa:00:00:00:00:01\n"
            "Xbox Wireless Controller|030000005e0400000000000000000000|0|1|1|Xbox Wireless Controller|aa:00:00:00:00:02\n"
            "Pro Controller|030000007e0500000000000000000000|0|1|1|Pro Controller|aa:00:00:00:00:03\n"
            "8BitDo Pro 2|03000000c82d00000000000000000000|0|1|1|8BitDo Pro 2|\n"
            "Asus Rog Ally Controller|03000000bd1200001501000011010000|0|1|1|Asus Rog Ally Controller|\n"
            "Generic Pad|03000000de280000ff11000001000000|0|6|1|Generic Pad|\n"
        )
    os.environ["EDEN_FAKE_SDL"] = fam
    est = await mod.Plugin().estado()
    fams = {m["nombre"]: m["familia"] for m in est["mandos"]}
    check("DualSense -> playstation",
          fams.get("DualSense Wireless Controller") == "playstation", fams)
    check("Xbox -> xbox", fams.get("Xbox Wireless Controller") == "xbox", fams)
    check("Pro Controller -> switch", fams.get("Pro Controller") == "switch", fams)
    check("8BitDo -> desconocido", fams.get("8BitDo Pro 2") == "desconocido", fams)
    check("Asus -> integrado",
          fams.get("Asus Rog Ally Controller") == "integrado", fams)
    check("pad virtual de Valve -> steam", fams.get("Generic Pad") == "steam", fams)

    # ------------------------------------------------------------------ 21
    print("21) restaurar todo")
    base = os.path.join(home, "eden-autoconfig")
    bk = os.path.join(base, "backups")
    os.makedirs(bk, exist_ok=True)
    viejo = os.path.join(bk, "qt-config.ini.aaa")
    nuevo = os.path.join(bk, "qt-config.ini.bbb")
    with open(viejo, "w", encoding="utf-8") as fh:
        fh.write("[Controls]\nplayer_0_profile_name=ORIGINAL\n")
    with open(nuevo, "w", encoding="utf-8") as fh:
        fh.write("[Controls]\nplayer_0_profile_name=RECIENTE\n")
    os.utime(viejo, (1000000, 1000000))
    os.utime(nuevo, (2000000, 2000000))

    conf = os.path.join(base, "eden-autoconfig.conf")
    with open(conf, encoding="utf-8") as fh:
        antes = fh.read()
    check("habia bloque del plugin", mod.BEGIN in antes)

    # copias de Cemu para comprobar que tambien se restauran
    cem = os.path.join(home, ".config", "Cemu", "controllerProfiles")
    os.makedirs(cem, exist_ok=True)
    with open(os.path.join(cem, "controller0.xml"), "w", encoding="utf-8") as fh:
        fh.write("<nuevo/>")
    cbk = os.path.join(bk, "cemu")
    os.makedirs(cbk, exist_ok=True)
    viejo_cem = os.path.join(cbk, "controller0.xml.20260101-000000")
    nuevo_cem = os.path.join(cbk, "controller0.xml.20260102-000000")
    with open(viejo_cem, "w", encoding="utf-8") as fh:
        fh.write("<viejo/>")
    with open(nuevo_cem, "w", encoding="utf-8") as fh:
        fh.write("<mas-nuevo/>")
    os.utime(viejo_cem, (1000000, 1000000))
    os.utime(nuevo_cem, (3000000, 3000000))

    r = await mod.Plugin().restaurar_todo()
    check("restaurar_todo ok", r["ok"] is True, r)

    with open(os.path.join(cem, "controller0.xml"), encoding="utf-8") as fh:
        check("Cemu restaurado (latest)", "<mas-nuevo/>" in fh.read())

    check("el resumen menciona Cemu", "Cemu" in r["salida"], r["salida"])

    stock = os.path.join(base, "stock", "qt-config.ini")
    check("guarda el original", os.path.isfile(stock))
    with open(stock, encoding="utf-8") as fh:
        check("original = la copia mas antigua", "ORIGINAL" in fh.read())

    cfg = os.path.join(home, ".config", "eden", "qt-config.ini")
    with open(cfg, encoding="utf-8") as fh:
        check("config restaurado", "ORIGINAL" in fh.read())

    with open(conf, encoding="utf-8") as fh:
        despues = fh.read()
    check("bloque eliminado", mod.BEGIN not in despues)
    check("el resto del conf se conserva", "PERFIL" in despues)

    hook = os.path.join(home, "ES-DE", "scripts", "game-start",
                        "10-eden-autoconfig.sh")
    fuera = os.path.join(home, "ES-DE", "scripts",
                         "10-eden-autoconfig.sh.desactivado")
    check("hook desactivado", (not os.path.exists(hook)) and os.path.isfile(fuera),
          (os.path.exists(hook), os.path.isfile(fuera)))

    # sin copias de seguridad
    shutil.rmtree(bk, ignore_errors=True)
    os.remove(stock)
    r = await mod.Plugin().restaurar_todo()
    check("sin copias avisa", r["ok"] is False and "copia" in r["salida"], r)

    # Eden con stock pero Cemu con carpeta de backup vacia:
    # el resumen debe decir "sin copias", no "restaurado"
    os.makedirs(os.path.dirname(stock), exist_ok=True)
    with open(stock, "w", encoding="utf-8") as fh:
        fh.write("[Controls]\nplayer_0_profile_name=ORIGINAL\n")
    os.makedirs(os.path.join(bk, "cemu"), exist_ok=True)
    r = await mod.Plugin().restaurar_todo()
    check("Cemu sin copias -> sin cambios",
          "Cemu: sin cambios" in r["salida"], r["salida"])
    check("no dice restaurado en falso",
          "Cemu: restaurado" not in r["salida"], r["salida"])
    shutil.rmtree(bk, ignore_errors=True)

    # el integrado se coloca solo: J1 sin externos, ultimo con externos
    prefs = mod._leer_prefs()
    prefs["INTEGRADO_MANUAL"] = "no"
    prefs["ORDEN_INTEGRADO"] = "ignorar"
    mod._escribir_prefs(prefs)

    solo_int = os.path.join(tmp, "solo_int.txt")
    with open(solo_int, "w", encoding="utf-8") as fh:
        fh.write("Asus Rog Ally Controller|03000000bd1200001501000011010000"
                 "|0|1|1|Asus Rog Ally Controller|\n")
    os.environ["EDEN_FAKE_SDL"] = solo_int
    est = await mod.Plugin().estado()
    check("solo integrado -> Jugador 1",
          est["prefs"]["ORDEN_INTEGRADO"] == "primero", est["prefs"])

    os.environ["EDEN_FAKE_SDL"] = uno          # ahora con un DualSense
    est = await mod.Plugin().estado()
    check("con externo -> ultimo jugador",
          est["prefs"]["ORDEN_INTEGRADO"] == "ultimo", est["prefs"])

    # 2 externos con 2 jugadores: el integrado no cabe -> desactivado
    prefs = mod._leer_prefs()
    prefs["INTEGRADO_MANUAL"] = "no"
    prefs["JUGADORES_MAX"] = "2"
    prefs["ORDEN_INTEGRADO"] = "ultimo"
    mod._escribir_prefs(prefs)
    os.environ["EDEN_FAKE_SDL"] = plan
    est = await mod.Plugin().estado()
    check("sin hueco -> desactivado",
          est["prefs"]["ORDEN_INTEGRADO"] == "ignorar", est["prefs"])

    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "4"
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    check("con hueco -> ultimo", est["prefs"]["ORDEN_INTEGRADO"] == "ultimo",
          est["prefs"])

    # Con DualSense, "Primero" no vale: pasa a ultimo o desactivado.
    await mod.Plugin().integrado_modo("primero")
    est = await mod.Plugin().estado()
    check("primero con DS pasa a ultimo",
          est["prefs"]["ORDEN_INTEGRADO"] == "ultimo"
          and est["prefs"]["INTEGRADO_MANUAL"] == "no", est["prefs"])

    # "Desactivado" manual si se respeta.
    await mod.Plugin().integrado_modo("ignorar")
    est = await mod.Plugin().estado()
    check("manual desactivado se respeta",
          est["prefs"]["ORDEN_INTEGRADO"] == "ignorar"
          and est["prefs"]["INTEGRADO_MANUAL"] == "si", est["prefs"])

    # La estrella: si el integrado es P1, ningun DualSense la lleva.
    prueba = [
        {"clase": "DualSense", "jugador": 1, "serie": "aa", "es_principal": False},
        {"clase": "Integrado", "jugador": None, "serie": "", "es_principal": False},
    ]
    mod._marcar_principal(prueba, mod._leer_prefs(), 1)
    check("integrado P1: DS sin estrella",
          not any(m["es_principal"] for m in prueba), prueba)

    prueba = [
        {"clase": "DualSense", "jugador": 1, "serie": "aa", "es_principal": False},
        {"clase": "Integrado", "jugador": 2, "serie": "", "es_principal": False},
    ]
    mod._marcar_principal(prueba, mod._leer_prefs(), 2)
    check("DS P1 conserva estrella", prueba[0]["es_principal"], prueba)

    # ------------------------------------------------------------------ 22
    print("22) aplicar todo y avisos de Steam Input")

    # Steam Input: todos los mandos como pads virtuales -> aviso en el panel
    virtuales = os.path.join(tmp, "sdl_virtual.txt")
    with open(virtuales, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Wireless Controller 1|03000000de280000ff11000001000000"
            "|0|6|1|DualSense Wireless Controller 1||0\n"
            "DualSense Wireless Controller 2|03000000de280000ff11000001000000"
            "|1|6|1|DualSense Wireless Controller 2||1\n"
            "Asus Rog Ally Controller|03000000de280000ff11000001000000"
            "|2|1|1|Asus Rog Ally Controller||2\n"
        )
    os.environ["EDEN_FAKE_SDL"] = virtuales
    est = await mod.Plugin().estado()
    check("Steam Input avisa del orden de jugadores",
          "Steam Input" in est["aviso"], est["aviso"])

    # Aplicar todo desde el panel: Eden + Cemu y limpiar el aviso
    os.environ["EDEN_FAKE_SDL"] = virtuales
    # plantilla minima para Eden y Cemu sin perfil valido (entorno de prueba)
    tpl = os.path.join(base, "templates")
    os.makedirs(tpl, exist_ok=True)
    for nombre in ("dualsense", "ally"):
        with open(os.path.join(tpl, nombre + ".player0.txt"), "w",
                  encoding="utf-8") as fh:
            fh.write("player_0_A=button:b\nplayer_0_B=button:a\n"
                     "player_0_X=button:y\nplayer_0_Y=button:x\n")
    shutil.rmtree(os.path.join(home, ".config", "Cemu"), ignore_errors=True)
    r = await mod.Plugin().aplicar_todo()
    check("Aplicar todo ok", r["ok"] is True, r)
    for etiqueta in ("Eden:", "Cemu:"):
        check("Aplicar todo menciona %s" % etiqueta[:-1],
              etiqueta in r["salida"], r["salida"])
    with open(os.path.join(base, "log.txt"), encoding="utf-8") as fh:
        log_txt = fh.read()
    check("el log guarda version/hash",
          "version=" in log_txt and "hash=" in log_txt, log_txt[-500:])
    est = await mod.Plugin().estado()
    check("Aplicar todo quita el aviso de scripts",
          est["scripts_nuevos"] is False)

    # Con el integrado desactivado, Eden no debe asignarlo como P2
    # (config de Eden realista: 10 jugadores, como el default de EmuDeck)
    cfg_eden = os.path.join(home, ".config", "eden", "qt-config.ini")
    os.makedirs(os.path.dirname(cfg_eden), exist_ok=True)
    with open(cfg_eden, "w", encoding="utf-8") as fh:
        fh.write("[Controls]\n")
        for n in range(10):
            fh.write("player_%d_profile_name=\n" % n)
    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "2"
    prefs["ORDEN_INTEGRADO"] = "ignorar"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    por_nombre = {m["nombre"]: m for m in est["mandos"]}
    check("Eden: integrado desactivado no es P2",
          por_nombre.get("Asus Rog Ally Controller", {}).get("jugador") is None,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])
    ds_jug = sorted([m["jugador"] for m in est["mandos"]
                     if m["clase"] == "DualSense"])
    check("Eden: los dos DualSense son P1/P2", ds_jug == [1, 2], ds_jug)

    # 4 DualSense + integrado, con el integrado en medio en la SDL del host:
    # el panel muestra los puertos reales; Eden renumera internamente.
    cuatro = os.path.join(tmp, "sdl_4virtual.txt")
    with open(cuatro, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Wireless Controller 1|03000000de280000ff11000001000000"
            "|0|6|1|DualSense Wireless Controller 1||0\n"
            "Asus Rog Ally Controller|03000000de280000ff11000001000000"
            "|1|1|1|Asus Rog Ally Controller||1\n"
            "DualSense Wireless Controller 2|03000000de280000ff11000001000000"
            "|2|6|1|DualSense Wireless Controller 2||2\n"
            "DualSense Wireless Controller 3|03000000de280000ff11000001000000"
            "|3|6|1|DualSense Wireless Controller 3||3\n"
            "DualSense Wireless Controller 4|03000000de280000ff11000001000000"
            "|4|6|1|DualSense Wireless Controller 4||4\n"
        )
    os.environ["EDEN_FAKE_SDL"] = cuatro
    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "4"
    prefs["ORDEN_INTEGRADO"] = "ignorar"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("Eden: 4 DualSense son P1..P4",
          sorted(m["jugador"] for m in ds) == [1, 2, 3, 4],
          [(m["nombre"], m["jugador"]) for m in ds])
    asus = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    check("Eden: integrado fuera con 4 DS",
          bool(asus) and all(m["jugador"] is None for m in asus),
          [(m["nombre"], m["jugador"]) for m in asus])
    check("Eden: el panel muestra los puertos reales",
          sorted(int(m["puerto"]) for m in ds) == [0, 2, 3, 4],
          [m["puerto"] for m in ds])

    # El ayudante devuelve los puertos reales (Cemu los necesita)
    script = os.path.join(AQUI, "eden_controller", "eden-autoconfig.sh")
    env_u = os.environ.copy()
    env_u["HOME"] = home
    env_u["EDEN_AUTOCONFIG_DIR"] = base
    env_u["EDEN_FAKE_SDL"] = cuatro
    r = subprocess.run(["bash", os.path.join(base, "eden-mandos-sdl.sh")],
                       env=env_u, capture_output=True, text=True)
    puertos = [l.split("|")[2] for l in r.stdout.splitlines()
               if l.startswith("DualSense")]
    check("helper: puertos raw 0,2,3,4", puertos == ["0", "2", "3", "4"],
          puertos)

    # Cemu usa los puertos reales (uuid 0,2,3,4), no los renumerados de Eden
    cem = os.path.join(home, ".config", "Cemu", "controllerProfiles")
    os.makedirs(cem, exist_ok=True)
    with open(os.path.join(cem, "controller0.xml"), "w", encoding="utf-8") as fh:
        fh.write("<xml/>")
    r = subprocess.run(["bash", script, "--sistema", "wiiu", "--dry-run"],
                       env=env_u, capture_output=True, text=True)
    check("Cemu dry-run ok", r.returncode == 0, r.stdout + r.stderr)
    out = r.stdout + r.stderr
    for u in ("0_", "2_", "3_", "4_"):
        check("Cemu uuid %s raw" % u, ("uuid         = %s" % u) in out,
              out[-600:])

    # Con Steam Input off, SDL3 da el bus Bluetooth como 05 y Cemu (SDL2) lo
    # guarda como 03. El CRC real no se toca.
    fisico = os.path.join(tmp, "sdl_bt.txt")
    with open(fisico, "w", encoding="utf-8") as fh:
        for n, mac in enumerate(("4c:b9:9b:e9:bc:26", "48:18:fd:11:4a:0a",
                                 "4c:b9:9b:23:f1:fb", "d0:bc:c1:02:fb:9d")):
            fh.write("DualSense Wireless Controller|"
                     "050057564c050000e60c000000006800|%d|6|1|"
                     "DualSense Wireless Controller|%s\n" % (n, mac))
    env_u["EDEN_FAKE_SDL"] = fisico
    r = subprocess.run(["bash", script, "--sistema", "wiiu", "--dry-run"],
                       env=env_u, capture_output=True, text=True)
    check("Cemu dry-run bus SDL2 ok", r.returncode == 0, r.stdout + r.stderr)
    out = r.stdout + r.stderr
    for u in ("0_", "1_", "2_", "3_"):
        check("Cemu uuid %s bus 03" % u,
              ("uuid         = %s030057564c050000e60c000000006800" % u) in out,
              out[-600:])
    check("Cemu no escribe el bus 05", "050057564c05" not in out, out[-600:])

    # Integrado como Ultimo jugador con 4 DS y tope 4: reserva P4 y deja fuera
    # el DS que seria P4 (no los cuatro activos).
    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "4"
    prefs["ORDEN_INTEGRADO"] = "ultimo"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    os.environ["EDEN_FAKE_SDL"] = cuatro
    est = await mod.Plugin().estado()
    por_nombre = {m["nombre"]: m for m in est["mandos"]}
    check("integrado ultimo: P4",
          por_nombre.get("Asus Rog Ally Controller", {}).get("jugador") == 4,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])
    ds_jug = sorted(m["jugador"] for m in est["mandos"]
                    if m["clase"] == "DualSense" and m["jugador"] is not None)
    check("integrado ultimo: 3 DS activos", ds_jug == [1, 2, 3], ds_jug)
    check("integrado ultimo: DS4 fuera",
          por_nombre.get("DualSense Wireless Controller 4",
                         {}).get("jugador") is None,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])

    env_u["EDEN_FAKE_SDL"] = cuatro
    r = subprocess.run(["bash", script, "--sistema", "wiiu", "--dry-run"],
                       env=env_u, capture_output=True, text=True)
    out = r.stdout + r.stderr
    check("Cemu integrado ultimo ok", r.returncode == 0, out)
    check("Cemu integrado ultimo P4",
          "uuid         = 1_03000000de280000ff11000001000000" in out
          and "display_name = Asus Rog Ally Controller" in out, out[-800:])
    for u in ("0_", "2_", "3_"):
        check("Cemu integrado ultimo DS %s" % u,
              ("uuid         = %s03000000de280000ff11000001000000" % u) in out,
              out[-800:])
    check("Cemu integrado ultimo DS4 fuera",
          "4_03000000de28" not in out, out[-800:])

    # Con 3 DS + integrado ultimo y tope 4 no se cae ningun DS.
    tres = os.path.join(tmp, "sdl_3virtual.txt")
    with open(tres, "w", encoding="utf-8") as fh:
        fh.write(
            "DualSense Wireless Controller 1|03000000de280000ff11000001000000"
            "|0|6|1|DualSense Wireless Controller 1||0\n"
            "Asus Rog Ally Controller|03000000bd1200001501000011010000"
            "|1|1|1|Asus Rog Ally Controller||1\n"
            "DualSense Wireless Controller 2|03000000de280000ff11000001000000"
            "|2|6|1|DualSense Wireless Controller 2||2\n"
            "DualSense Wireless Controller 3|03000000de280000ff11000001000000"
            "|3|6|1|DualSense Wireless Controller 3||3\n"
        )
    os.environ["EDEN_FAKE_SDL"] = tres
    est = await mod.Plugin().estado()
    por_nombre = {m["nombre"]: m for m in est["mandos"]}
    check("3 DS + integrado ultimo: todos entran",
          sorted(m["jugador"] for m in est["mandos"]
                 if m["clase"] == "DualSense") == [1, 2, 3]
          and por_nombre.get("Asus Rog Ally Controller", {}).get("jugador") == 4,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])

    # P1_SERIE: el DS fijado sigue P1 y se cae el ultimo de la lista.
    cuatro_serie = os.path.join(tmp, "sdl_4virtual_serie.txt")
    with open(cuatro_serie, "w", encoding="utf-8") as fh:
        for n, mac in enumerate(("aa:aa", "bb:bb", "cc:cc", "dd:dd")):
            fh.write(
                "DualSense Wireless Controller %d|"
                "03000000de280000ff11000001000000|%d|6|1|"
                "DualSense Wireless Controller %d|%s|%d\n"
                % (n + 1, n, n + 1, mac, n))
        fh.write(
            "Asus Rog Ally Controller|03000000bd1200001501000011010000"
            "|4|1|1|Asus Rog Ally Controller||4\n")
    prefs = mod._leer_prefs()
    prefs["P1_SERIE"] = "dd:dd"
    mod._escribir_prefs(prefs)
    os.environ["EDEN_FAKE_SDL"] = cuatro_serie
    est = await mod.Plugin().estado()
    por_nombre = {m["nombre"]: m for m in est["mandos"]}
    check("P1_SERIE ultimo: DS4 sigue P1",
          por_nombre.get("DualSense Wireless Controller 4",
                         {}).get("jugador") == 1,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])
    check("P1_SERIE ultimo: se cae el DS3",
          por_nombre.get("DualSense Wireless Controller 3",
                         {}).get("jugador") is None,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])
    check("P1_SERIE ultimo: integrado P4",
          por_nombre.get("Asus Rog Ally Controller", {}).get("jugador") == 4,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])
    prefs = mod._leer_prefs()
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)

    # Matriz completa de tarjetas: 5 cantidades de DS x 3 modos x 4 cupos.
    # Comprueba quien tiene jugador y quien queda desactivado.
    errores = []
    for d in range(5):
        matriz = os.path.join(tmp, "matriz_%d.txt" % d)
        with open(matriz, "w", encoding="utf-8") as fh:
            for k in range(d):
                fh.write(
                    "DualSense %d|050057564c050000e60c000000006800"
                    "|%d|6|1|DualSense %d|4c:b9:9b:e9:bc:%02x|%d\n"
                    % (k + 1, k, k + 1, k, k)
                )
            fh.write(
                "Asus Rog Ally Controller|03000000bd1200001501000011010000"
                "|0|1|1|Asus Rog Ally Controller||0\n"
            )
        os.environ["EDEN_FAKE_SDL"] = matriz
        for modo in ("ignorar", "primero", "ultimo"):
            for cupo in range(1, 5):
                prefs = mod._leer_prefs()
                prefs["JUGADORES_MAX"] = str(cupo)
                prefs["ORDEN_INTEGRADO"] = modo
                prefs["INTEGRADO_MANUAL"] = "si"
                prefs["P1_SERIE"] = ""
                mod._escribir_prefs(prefs)
                est = await mod.Plugin().estado()
                got = {}
                for m in est["mandos"]:
                    if m["clase"] == "DualSense":
                        got["D%d" % (int(m["puerto"]) + 1)] = m["jugador"]
                    elif m["clase"] == "Integrado":
                        got["I"] = m["jugador"]
                exp = {"D%d" % (k + 1): None for k in range(d)}
                exp["I"] = None
                modo_ef = modo
                if d > 0 and modo == "primero":
                    modo_ef = "ignorar" if d >= cupo else "ultimo"
                if d == 0:
                    exp["I"] = 1
                elif modo_ef == "ignorar":
                    for k in range(min(d, cupo)):
                        exp["D%d" % (k + 1)] = k + 1
                else:
                    n = min(d, cupo - 1)
                    for k in range(n):
                        exp["D%d" % (k + 1)] = k + 1
                    exp["I"] = n + 1
                if got != exp:
                    errores.append((d, modo, cupo, exp, got))
    check("matriz 60 escenarios: jugadores y desactivados",
          not errores, errores[:3])

    # El integrado puede llegar como un unico pad virtual de Steam (no como
    # "Asus"): el panel debe clasificarlo igual que el driver.
    virtual = os.path.join(tmp, "sdl_virtual_integrado.txt")
    with open(virtual, "w", encoding="utf-8") as fh:
        for k in range(4):
            fh.write(
                "DualSense %d|050057564c050000e60c000000006800"
                "|%d|6|1|DualSense %d|4c:b9:9b:e9:bc:%02x\n"
                % (k + 1, k, k + 1, k)
            )
        fh.write("Steam Virtual Gamepad|03000000de280000ff11000001000000"
                 "|0|1|1|Steam Virtual Gamepad|\n")
    os.environ["EDEN_FAKE_SDL"] = virtual
    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "4"
    prefs["ORDEN_INTEGRADO"] = "ultimo"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    check("integrado virtual detectado", len(integ) == 1
          and integ[0]["nombre"] == "Steam Virtual Gamepad", est["mandos"])
    check("integrado virtual no es tarjeta externa",
          not any(m["clase"] == "Pad virtual" for m in est["mandos"]),
          [(m["nombre"], m["clase"]) for m in est["mandos"]])
    check("integrado virtual P4", integ and integ[0]["jugador"] == 4,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("integrado virtual: DS4 fuera",
          [m["jugador"] for m in ds] == [1, 2, 3, None],
          [(m["puerto"], m["jugador"]) for m in ds])

    prefs["ORDEN_INTEGRADO"] = "primero"
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("integrado virtual con 4 DS: se desactiva",
          integ and integ[0]["jugador"] is None
          and [m["jugador"] for m in ds] == [1, 2, 3, 4],
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])

    prefs["ORDEN_INTEGRADO"] = "ignorar"
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("integrado virtual desactivado: 4 DS",
          integ and integ[0]["jugador"] is None
          and [m["jugador"] for m in ds] == [1, 2, 3, 4],
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])

    # Aunque el pad virtual tenga serie (y el fallback no lo promueva), el
    # plan de --who dice que es el integrado: el panel debe usar ese dato.
    virtual_serial = os.path.join(tmp, "sdl_virtual_serial.txt")
    with open(virtual_serial, "w", encoding="utf-8") as fh:
        for k in range(4):
            fh.write(
                "DualSense %d|050057564c050000e60c000000006800"
                "|%d|6|1|DualSense %d|4c:b9:9b:e9:bc:%02x\n"
                % (k + 1, k, k + 1, k)
            )
        fh.write("Steam Virtual Gamepad|03000000de280000ff11000001000000"
                 "|0|1|1|Steam Virtual Gamepad|aa:aa\n")
    os.environ["EDEN_FAKE_SDL"] = virtual_serial
    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "4"
    prefs["ORDEN_INTEGRADO"] = "ultimo"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    integ = [m for m in est["mandos"] if m["clase"] == "Integrado"]
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("plan marca el integrado aunque tenga serie",
          len(integ) == 1 and integ[0]["nombre"] == "Steam Virtual Gamepad",
          [(m["nombre"], m["clase"]) for m in est["mandos"]])
    check("plan integrado P4", integ and integ[0]["jugador"] == 4,
          [(m["nombre"], m["jugador"]) for m in est["mandos"]])
    check("estado expone jugador_integrado",
          est["jugador_integrado"] == 4
          and (est["integrado_nombre"] or "").lower() == "steam virtual gamepad",
          (est.get("jugador_integrado"), est.get("integrado_nombre")))
    check("plan integrado: DS4 fuera",
          [m["jugador"] for m in ds] == [1, 2, 3, None],
          [(m["puerto"], m["jugador"]) for m in ds])

    # Sin integrado real en SDL no debe aparecer un "INTEGRADO [] (port )"
    # fantasma que robe P1. La consola sigue siendo una ROG Xbox Ally X.
    sin_integrado = os.path.join(tmp, "sdl_sin_integrado.txt")
    with open(sin_integrado, "w", encoding="utf-8") as fh:
        for k in range(4):
            fh.write(
                "DualSense %d|050057564c050000e60c000000006800"
                "|%d|6|1|DualSense %d|4c:b9:9b:e9:bc:%02x\n"
                % (k + 1, k, k + 1, k)
            )
    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "3"
    prefs["ORDEN_INTEGRADO"] = "primero"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    os.environ["EDEN_FAKE_SDL"] = sin_integrado
    env_u["EDEN_FAKE_SDL"] = sin_integrado
    r = subprocess.run(["bash", script, "--who"],
                       env=env_u, capture_output=True, text=True)
    out = r.stdout + r.stderr
    check("sin integrado: no hay INTEGRADO fantasma",
          "INTEGRADO" not in out and "Player 1 = DualSense 1" in out,
          out[-500:])
    original_maquina = mod._maquina
    mod._maquina = lambda: {
        "vendor": "ASUSTeK COMPUTER INC.",
        "producto": "ROG Xbox Ally X RC73XA_RC73XA",
        "placa": "RC73XA",
    }
    est = await mod.Plugin().estado()
    check("maquina ROG Xbox Ally X",
          (est["maquina"] or {}).get("producto", "").startswith("ROG Xbox Ally X"),
          est.get("maquina"))
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("consola conocida: con DS lleno, integrado off",
          est["jugador_integrado"] is None,
          (est["jugador_integrado"], est["mandos"]))
    check("consola conocida: DS P1..P3",
          [m["jugador"] for m in ds][:3] == [1, 2, 3],
          [(m["puerto"], m["jugador"]) for m in ds])

    # 0 DS: el integrado es siempre P1, aunque estuviera en Desactivado.
    os.environ["EDEN_FAKE_SDL"] = solo_int
    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "4"
    prefs["ORDEN_INTEGRADO"] = "ignorar"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    check("0 DS: integrado siempre P1",
          est["prefs"]["ORDEN_INTEGRADO"] == "primero"
          and est["jugador_integrado"] == 1, est["prefs"])

    # 1 DS: el DualSense pasa a P1 y el integrado a ultimo.
    os.environ["EDEN_FAKE_SDL"] = uno
    prefs = mod._leer_prefs()
    prefs["ORDEN_INTEGRADO"] = "primero"
    prefs["INTEGRADO_MANUAL"] = "si"
    mod._escribir_prefs(prefs)
    est = await mod.Plugin().estado()
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("1 DS: DS P1 y integrado P2",
          est["prefs"]["ORDEN_INTEGRADO"] == "ultimo"
          and [m["jugador"] for m in ds] == [1]
          and est["jugador_integrado"] == 2
          and ds and ds[0]["es_principal"],
          (est["prefs"], [(m["nombre"], m["jugador"], m["es_principal"])
                          for m in est["mandos"]]))

    # Consola desconocida: sin integrado real no se asume nada.
    os.environ["EDEN_FAKE_SDL"] = sin_integrado
    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "3"
    prefs["ORDEN_INTEGRADO"] = "primero"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    mod._maquina = lambda: {"vendor": "Generic", "producto": "PC",
                            "placa": "Generic"}
    est = await mod.Plugin().estado()
    ds = [m for m in est["mandos"] if m["clase"] == "DualSense"]
    check("consola desconocida: sin integrado fantasma",
          est["jugador_integrado"] is None
          and [m["jugador"] for m in ds][:3] == [1, 2, 3],
          (est["jugador_integrado"],
           [(m["puerto"], m["jugador"]) for m in ds]))
    mod._maquina = original_maquina

    prefs = mod._leer_prefs()
    prefs["JUGADORES_MAX"] = "4"
    prefs["ORDEN_INTEGRADO"] = "ignorar"
    prefs["INTEGRADO_MANUAL"] = "si"
    prefs["P1_SERIE"] = ""
    mod._escribir_prefs(prefs)
    os.environ["EDEN_FAKE_SDL"] = cuatro

    # El log del panel filtra por emulador y quita los bloques de --who
    with open(os.path.join(base, "log.txt"), "w", encoding="utf-8") as fh:
        fh.write("2026-01-01 10:00:00 [INFO] [1] === eden-autoconfig.sh v2 modo=who args='--who' ===\n")
        for _ in range(6):
            fh.write("2026-01-01 10:00:00 [INFO] [1] deteccion SDL: ruido\n")
        fh.write("2026-01-01 10:00:00 [INFO] [1] === eden-autoconfig.sh v2 modo=aplicar args='' ===\n")
        fh.write("2026-01-01 10:00:00 [INFO] [1] aplicado. plan: dual:0:0\n")
        fh.write("[2026-01-01 10:00:02] wiiu aplicar: Mando 1 = X\n")
    r = await mod.Plugin().ver_log()
    check("el log filtra los --who", "modo=who" not in r["salida"], r["salida"])
    check("el log conserva el aplicar", "aplicado. plan" in r["salida"],
          r["salida"])

    r = await mod.Plugin().ver_log("eden")
    check("filtro Eden", "aplicado. plan" in r["salida"]
          and "wiiu aplicar" not in r["salida"], r["salida"])
    r = await mod.Plugin().ver_log("cemu")
    check("filtro Cemu (wiiu)", "wiiu aplicar" in r["salida"]
          and "aplicado. plan" not in r["salida"], r["salida"])

    shutil.rmtree(tmp, ignore_errors=True)

    print()
    if FALLOS:
        print("FALLAN %d de %d:" % (len(FALLOS), TOTAL))
        for f in FALLOS:
            print("  - %s" % f)
        return 1
    print("TODO OK (%d comprobaciones)" % TOTAL)
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
