# AGENTS.md

## Contexto que condiciona todo

- Son **scripts de bash para una ROG Ally X con SteamOS**, no un proyecto con
  build: se copian a la consola y se ejecutan allí (`bash instalar.sh`).
- **No hay acceso a la máquina destino.** El agente trabaja en otra máquina: no
  puede ejecutar Eden, ES-DE, `bluetoothctl` ni leer `/sys/class/input` de la
  Ally. Todo se valida aquí de forma simulada; el usuario prueba en la consola.
- No es un repo git (no hay commits ni diffs que consultar).
- Solo herramientas estándar (`bash`, `sed`, `awk`/gawk, `grep`, `find`,
  `flock`, `stat`, `bluetoothctl`, `python3`). **Nada de instalar paquetes**
  (SteamOS es de solo lectura) y nada de escribir fuera de `$HOME`.
- Textos en **español** (comentarios y mensajes; con acentos ocasionales).
  Variables, funciones y claves son ASCII (`validar_salida`, `SDL_CRC_CERO`…).

## Verificación (no hay suite de tests)

Mínimo tras tocar cualquier `.sh`:

```bash
for f in *.sh es-de-hooks/*.sh; do bash -n "$f" || echo "ERROR $f"; done
```

La prueba funcional es **simulada** (aquí no hay libSDL3 ni Eden). Se usa un
`HOME` falso y se alimenta la detección con ficheros:

- `EDEN_FAKE_SDL`: `NOMBRE|GUID|PUERTO|TIPO|ES_GAMEPAD|NOMBRE_SDL|SERIE`
  (admite líneas `#lib …` / `#origen …` que los parsers ignoran).
- `EDEN_FAKE_BT`: `MAC|NOMBRE`.
- `EDEN_FAKE_INPUT_DEVICES` (respaldo `/sys`): `NOMBRE|UNIQ|VENDOR|PRODUCT|HANDLERS|SYSFS`.

```bash
T=$(mktemp -d); mkdir -p "$T/home/.config/eden"
# crear "$T/home/.config/eden/qt-config.ini" con una sección [Controls] realista
HOME="$T/home" EDEN_AUTOCONFIG_DIR="$T/estado" \
  EDEN_FAKE_SDL="$T/sdl.txt" EDEN_FAKE_BT="$T/bt.txt" \
  bash ./eden-autoconfig.sh --mandos
```

Casos que han encontrado bugs reales y hay que repetir: 0, 1 y varios DualSense;
solo integrado; modo nativo; y comprobar que **no se pierde ninguna clave**
`player_N_*`, que el número de líneas y las secciones no cambian, y que los
jugadores sobrantes quedan `connected=false`.

## Contrato de seguridad (no romperlo)

- Nunca borrar datos del usuario: backup con fecha en `~/eden-autoconfig/backups/`
  antes de cada escritura. `RETENCION_BACKUPS=0` = **no borrar nunca**.
- Escritura **atómica** (tmp + `mv`) y **validación posterior**
  (`validar_salida`): si algo no cuadra, no se toca el original.
- Nunca escribir variando el `.conf` del usuario: `instalar.sh` no pisa un
  `eden-autoconfig.conf` existente.
- Nunca aplicar si Eden está en ejecución (`eden_en_ejecucion` → exit 3).
- El hook de ES-DE **nunca** debe impedir que arranque el juego (`exit 0` siempre).
- Códigos de salida: `0` ok | `1` error | `2` nada que hacer | `3` Eden en
  ejecución | `4` no se encontró `qt-config.ini` | `5` no se encontró plantilla.
- No borres `test.txt` (es un borrador del usuario).

## Hechos del dominio (cada uno costó horas)

### `qt-config.ini` de Eden (`~/.config/eden/`)
- Sección `[Controls]`, 10 jugadores (`player_0_`…`player_9_`) y decenas de
  claves por jugador (32 en el default de EmuDeck; no asumas un número fijo).
  Cada binding lleva `guid:` y `port:` dentro de la cadena.
- El sufijo `\default` va **en la clave**: `clave\default=valor`. Para Eden,
  `\default=true` = "usa el valor por defecto e ignora el guardado": al cambiar un
  valor hay que escribir `\default=false`. Los jugadores que no cambian conservan
  su flag (diff mínimo).
- Las líneas `\default` pueden ir **antes** de la línea de valor (p. ej.
  `player_N_profile_name`): no marcar la clave como vista hasta ver el valor.
- El perfil de EmuDeck (`<config>/input/emudeck.ini`) **no** lleva prefijo
  `player_0_`; `normalizar_origen` se lo añade.
- Las plantillas (`~/eden-autoconfig/templates/*.player0.txt`) solo aportan los
  *bindings*: el mapeo de Eden es independiente del dispositivo (A→EAST, B→SOUTH,
  X→NORTH, Y→WEST, ZL/ZR→ejes), así que sirve cualquiera para cualquier mando.
  El guid y el puerto los pone la detección.

### Identificación de mandos
- Eden identifica por `guid` + `port`; `port` = "el n-ésimo mando con ese mismo
  guid", en orden de enumeración. **El guid no incluye la MAC**: no se puede
  fijar un DualSense concreto por MAC desde el fichero.
- **Los puertos cambian entre sesiones**: la detección se hace en cada
  lanzamiento; nunca guardes puertos de una sesión anterior.
- Con **Steam Input activo** (lo normal al lanzar desde ES-DE) Eden no ve los
  mandos reales, sino pads virtuales de Valve (`de28…`) con el nombre y el tipo
  del mando físico (`DualSense Controller N`). Al integrado virtualizado **no** se
  le pone nombre "Asus…": si entre los pads virtuales sobra exactamente uno que
  no es DualSense, ese es el integrado.
- El `guid` lleva un **CRC en los bytes 2-3** que depende de la versión de SDL.
  La SDL de Eden lo calcula a 0; la del sistema, distinto. `SDL_CRC_CERO="si"`
  normaliza esos bytes para que coincida con lo que espera Eden
  (`050000004c05…`, `03000000de28…`).
- Mandos vs teclados/ratones: un mando real tiene nodo `jsN` (de ahí el filtro
  por `HANDLERS` en el método de respaldo).

### El AppImage de Eden
- Usa **dwarfs**, no squashfs: `--appimage-extract` devuelve 0 ficheros.
- Se monta en `/tmp/.mount_EdenXXXX` (layout `bin/` + `lib/`) **dentro de su
  propio namespace**: no se ve desde fuera. Se llega por `/proc/<pid>/root` + la
  ruta del `exe` (`…/bin/eden`).
- Su `lib/` **no contiene `libSDL3`** (SDL va estática): no hay lib que copiar.
  De ahí la SDL del sistema + normalización del CRC.
- **Trampa ya sufrida**: no marcar funciones SDL como obligatorias. SDL3 no tiene
  `SDL_GetJoystickSerialForID`; si falta una "obligatoria", el ayudante entero
  aborta. Todo lo opcional va en `try/except` (serial, `SDL_UpdateJoysticks`,
  `SDL_GetVersion`…).

### Dolphin (GameCube / Wii)
- **No hay perfil referenciado**: a diferencia de Eden (`player_N_profile_name`) o
  Cemu (`<profile>`), Dolphin usa directamente `GCPadNew.ini`/`WiimoteNew.ini`.
  Los `Profiles/GCPad|Wiimote/*.ini` que instala EmuDeck son plantillas que se
  cargan a mano; no se autoaplican.
- EmuDeck deja `SIDevice0 = 6` y `SIDevice1..3 = 0`: **solo el puerto 1 de
  GameCube está activo**. Hay que poner `SIDeviceN = 6` para los jugadores del
  plan y `0` para el resto; `12` es el adaptador GC real y no se toca.
- Dolphin asigna el id de `SDL/<id>/<nombre>` por **(backend, nombre)**, no por
  el índice global de SDL: el primer mando de cada nombre es `0`. Por eso el
  driver usa `PLAN_INDICE_NOMBRE` y no `PLAN_INDICE`. Con un DualSense y el
  integrado, el integrado debe ser `SDL/0/Asus…`, no `SDL/1/Asus…`.
- **Puertos de los DualSense virtuales.** El ayudante SDL da el puerto real por
  guid (el integrado `de28` ocupa uno; Cemu lo necesita para su `uuid`). Eden
  renumera sus DualSense 0..N-1 dentro de `detectar_mandos_sdl`, porque coloca
  el integrado al final; el panel hace lo mismo con las tarjetas virtuales.
- **Dolphin por evdev.** `DOLPHIN_BACKEND=evdev` usa `eden-mandos-evdev.sh` y
  escribe `evdev/<id>/<nombre>`; así se saltan los pads de Steam. Por defecto
  es `sdl` (la que funcionaba); evdev es experimental. El id es el n-ésimo con
  ese nombre en el orden de `/proc` (event).
- **Dolphin corre en Flatpak y usa SU SDL** (3.2.30), distinta de la del host
  (3.4.12). Los nombres/orden pueden no coincidir. El driver pone
  `NUCLEO_SDL_MODO=dolphin` y `NUCLEO_SDL_FLATPAK=<app>`; `nucleo_mandos`
  ejecuta `eden-mandos-sdl.sh` **dentro del Flatpak** con `SDL_LIB` del sandbox
  y `SDL_HINTS_MODO=dolphin` (sin forzar el HIDAPI de Xbox). Si falla, cae al
  host y lo avisa; `log.txt` registra `fuente=flatpak|host`. Sin esto, Dolphin
  guarda nombres que no corresponden a los mandos físicos.
- El driver **no crea bindings ni carga perfiles**: los `GC_base`/`Wiimote*` de
  `Profiles/` son plantillas manuales. Solo cambia `Device`, `SIDevice`,
  `Source` y `Hotkeys`. Si el usuario carga un perfil, sobrescribe `Device` y
  hay que volver a aplicar.
- `WiimoteNew.ini` no trae líneas `Source`. Dolphin por defecto pone
  **Wiimote1 = Emulated (1)** y **Wiimote2..4 = None (0)**. Hay que **insertar**
  `Source = 1` en los Wiimotes del plan (y `0` para el resto); `2` es un Wiimote
  real y se respeta.
- `Hotkeys.ini` lleva su propio `Device`; si no apunta al P1, los atajos pueden
  no responder. EmuDeck lo actualiza en su AutoMap.
- El **AutoMap de EmuDeck** (`autoMapDolphin=true`) copia su plantilla y
  reescribe `Device`/`SIDevice`/`Source`/Hotkeys al lanzar con su lanzador; eso
  pisaría a N.E.C.A. Con AutoMap desactivado no toca nada.
- El `WiimoteNew.ini` de EmuDeck **no termina en salto de línea**; el driver
  conserva esa propiedad al reescribir.
- El driver guarda una copia fija del estado anterior en
  `backups/dolphin/stock/` para que `--restore stock` (lo usa el botón
  Restaurar) vuelva al estado real anterior a N.E.C.A; `latest` deshace solo el
  último aplicar. Cemu hace lo mismo en `backups/cemu/stock/`.

### ES-DE
- Evento `game-start`: `$1` ruta del juego, `$2` nombre, `$3` sistema (`switch`),
  `$4` nombre completo. ES-DE **espera** a que el script termine.
- Ejecuta **todos** los ficheros de `~/ES-DE/scripts/game-start/` (da igual la
  extensión): para desactivar el hook hay que **sacarlo de la carpeta**.
- Ajuste en `~/ES-DE/settings/es_settings.xml`
  (`<bool name="CustomEventScripts" value="true"/>`).

### Configs por juego (`<config>/custom/<title id>.ini`)
- Solo afectan si tienen `player_N_profile_name` **no vacío**; si está vacío o
  ausente, Eden usa el `[Controls]` global (verificado en su código). Una
  sección `[Controls]` vacía no sustituye nada.

## Mapa de ficheros

| Fichero | Papel |
|---|---|
| `eden-autoconfig.sh` | **Despachador**: elige driver por `--sistema` y le pasa los argumentos |
| `eden-nucleo.sh` | Piezas compartidas: rutas, `.conf`, preferencias comunes |
| `eden-driver-yuzu.sh` | Eden y sus fork: `qt-config.ini` (todo el flujo anterior) |
| `eden-driver-dolphin.sh` | Dolphin (GC/Wii): `Device`, `SIDevice`, `Source` y `Hotkeys` en sus cuatro ini |
| `eden-driver-cemu.sh` | Cemu (Wii U): fija el dispositivo (uuid/display_name) en `controllerN.xml` |
| `eden-plantilla-cemu.xml` | Plantilla de emergencia (Wii U Pro Controller) si no hay `Deck-PN.xml` |
| `eden-mandos-sdl.sh` | Interroga a libSDL3 (python + ctypes); lista lo que ve Eden |
| `eden-mandos-evdev.sh` | Lista gamepads físicos por `/proc/bus/input/devices` para Dolphin (`evdev/<id>/<nombre>`) |
| `eden-diagnostico.sh` | Solo lectura; volcado para que el usuario lo pegue |
| `instalar.sh` | Copia a `~/eden-autoconfig` (incluido `VERSION`), repone el hook y verifica SDL |
| `es-de-hooks/10-eden-autoconfig.sh` | Hook `game-start`: `switch` → Eden, `gc`/`wii` → Dolphin, `wiiu` → Cemu |
| `eden-autoconfig.conf.example` | Variables; el `.conf` instalado no se sobreescribe |
| `README.md` | Guía de usuario; fuente de verdad de los pasos en la consola |

Orden de llamada: despachador (según `--sistema`) → driver → `main` → `localizar_qconfig` → `detectar_mandos`
(`cargar_mandos_sdl`/`detectar_mandos_sdl`, con la ruta `/sys` como respaldo) →
`planificar` (`planificar_sdl`) → `montar_fichero` (`render_player`) →
`validar_salida` → backup → `escribir_atomico`.

## Al cambiar el código

- Mantén funcionando el **método de respaldo** (`/sys` + `bluetoothctl`): es lo
  que se usa si SDL falla.
- Los tokens del plan son `tipo:jugador:puerto[:guid]` (`datos_de_jugador`); el
  4º campo es opcional y si falta se usan `GUID_DUALSENSE`/`GUID_INTEGRADO`.
- En la salida de `eden-mandos-sdl.sh`, las líneas que empiezan por `#` son
  informativas: los parsers **deben saltarlas**.
- Formato de cada mando (8 campos desde 2026-11):
  `NOMBRE|GUID|PUERTO|TIPO|ES_GAMEPAD|NOMBRE_SDL|SERIE|INDICE_SDL`.
  `PUERTO` es el "n-ésimo con ese guid" (Eden); `INDICE_SDL` es el índice global
  de SDL. **Dolphin NO usa ese índice global**: asigna el id por
  `(backend, nombre)`, así que hay que usar el n-ésimo con ese **mismo nombre**
  (`NUCLEO_IND_NOMBRE` / `PLAN_INDICE_NOMBRE`). Si se usa el global, P1 acierta
  (suele ser 0) pero P2 con otro nombre falla (`SDL/1/Asus…` cuando Dolphin
  espera `SDL/0/Asus…`).
- Dialecto del GUID (`SDL_GUID_MODO`): Eden guarda el CRC de los bytes 2-3 a
  cero; Cemu lo guarda **real**. Por eso el driver de Cemu llama al ayudante con
  `SDL_FUENTE=sistema SDL_GUID_MODO=cemu` (SDL del sistema sin normalizar y
  `PUERTO` contado solo entre gamepads, como hace Cemu).
- El **plan compartido** (Dolphin y Cemu) vive en `eden-nucleo.sh`
  (`nucleo_mandos` + `nucleo_planificar`): clasifica `dual|integrado|otro`,
  respeta `ORDEN_INTEGRADO`, `P1_SERIE` y `JUGADORES_MAX`. Eden mantiene su
  propio planificador. `nucleo_planificar` nunca se llama en subshell: deja
  `SDL_OK`/`SDL_ERR` y los arrays `NUCLEO_*` para poder explicar el plan.
- Los drivers dejan `plan-<sistema>.txt` (lo lee el panel) y escriben en
  `log.txt`; `nucleo_guardar_plan` / `nucleo_registrar` son los únicos que
  tocan esos ficheros. `nucleo_registrar` incluye `version=` y `hash=` del
  bundle; los drivers añaden los `Device`/`SIDevice`/`Source`/`Hotkeys`
  escritos. Si el emulador está abierto, salen con 3 y dejan
  `en ejecucion, no aplico` en el log.
- La version del driver se lee de `VERSION`; `build.sh` la genera y `instalar.sh`
  la copia. No volver a fijarla a mano en el script.
- El driver de Eden desactiva el **applet de mandos** al aplicar: evita la
  ventana que pide OK al iniciar el juego. Eden solo usa el valor si ademas
  `controller_applet_mode\default=false`; `forzar_applet_apagado` escribe las
  dos lineas y no toca nada si ya estan bien.
- Cemu identifica el mando por `uuid = <puerto>_<guid>`; `display_name`,
  `<profile>` y `<type>` no intervienen en la búsqueda. El driver solo cambia el
  dispositivo: conserva tipo, perfil, bindings y las entradas no-SDL (DSU).
- Si cambias `eden-mandos-sdl.sh` de forma incompatible, actualiza la guarda de
  `instalar.sh` (busca la marca `raices_de_pid`) o la instalación abortará.
- Antes de entregar: `bash -n` de todo + una pasada con `EDEN_FAKE_SDL` en los
  casos de arriba.
