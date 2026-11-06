# N.E.C.A — scripts

Autoconfigura **los mandos de los emuladores de Nintendo** al lanzar el juego
desde ES-DE: **Eden** (Switch), **Dolphin** (GameCube/Wii) y **Cemu** (Wii U).
El despachador elige el driver con `--sistema switch|gc|wii|wiiu`; sin
`--sistema` se usa Eden.

Así no hay que reasignar a mano los mandos en cada emulador.

Probado con: SteamOS, EmuDeck, ES-DE, Eden en AppImage, ROG Xbox Ally X y
DualSense por Bluetooth.

---

## 0. Cómo funciona por dentro (leer primero)

El script **le pregunta a SDL** (la misma librería de mandos que usa Eden) qué
dispositivos ve, justo **antes** de que arranque Eden. Eso es imprescindible,
por dos motivos que se descubrieron en pruebas reales en una ROG Ally X:

1. **Steam Input suele estar activo** al lanzar desde ES-DE. En ese caso Eden
   **no ve los mandos reales**: ve los *pads virtuales de Steam* (guid de Valve
   `03000000de280000ff11000001000000`) "disfrazados" con el nombre del mando
   físico. En el desplegable de Eden aparecen como `DualSense Controller N` y
   `Asus Rog Ally Controller N`, pero **por dentro todos usan el guid de Valve**.
   Leer `/sys` no sirve para saber esto.
2. **Los puertos cambian entre sesiones.** Eden identifica cada mando por
   `guid` + `port`, y el `port` es la posición dentro de los mandos de ese mismo
   guid; Steam los renumera según su propio orden. De dos sesiones seguidas
   salió el DualSense en el puerto 1 y luego en el 0. **Cualquier configuración
   fija falla** (y de hecho falló: sonaba el mando integrado como P1 en vez del
   DualSense).

Por eso el script usa SDL: obtiene, **en el momento del lanzamiento**, el
nombre (que delata al mando físico), el **guid** y el **puerto** reales de cada
dispositivo, y escribe exactamente eso. Con eso:

* P1..PN son los DualSense (identificados por su nombre), con **sus puertos reales**.
* El mando integrado se identifica y se ignora cuando hay DualSense (la regla
  que querías, ahora exacta incluso con Steam Input activo).
* Cuando Steam virtualiza el mando integrado **no le pone el nombre "Asus…"**.
  Por eso, si entre los pads virtuales sobra exactamente **uno** que no es un
  DualSense, se toma como el integrado (no hay ambigüedad posible). Así el caso
  "jugar solo con la Ally" también funciona.
* Si SDL no estuviera disponible, cae al método anterior (`/sys` +
  `bluetoothctl`) y lo avisa en el log.

### Qué libSDL3 usa y el truco del CRC (importante)

El script pregunta a la `libSDL3` **del sistema** (Eden lleva la suya estática
dentro del AppImage, y su AppImage es `dwarfs`, así que no se puede extraer).

Problema que apareció en pruebas reales: la SDL del sistema y la de Eden
calculan **GUIDs distintos** para el mismo mando, porque meten un **CRC** en los
bytes 2-3 del GUID. Comparando con los GUIDs reales de Eden:

```
Eden:         0500 0000 4c05 0000 e60c …
SDL sistema:  0500 5756 4c05 0000 e60c …
```

Son idénticos **salvo el CRC**. Por eso el script pone esos dos bytes a **cero**
(`SDL_CRC_CERO="si"` en el `.conf`) y obtiene exactamente los GUIDs que espera
Eden. Todo lo demás (bus, vendor, product, versión, firma) coincide.

`--mandos` te dice siempre qué lib usa y su origen:

```
libSDL3 usada : libSDL3.so.0 version 3.2.10
origen        : sistema (CRC normalizado a 0 = guids de Eden)
```

Si algún día Eden cambiara de versión de SDL y los GUIDs no cuadraran, se puede
probar `SDL_CRC_CERO="no"` en el `.conf`.

Para ver lo mismo que ve Eden en cualquier momento:

```bash
~/eden-autoconfig/eden-autoconfig.sh --mandos
```

## 0.1 Datos reales de tu Ally (del diagnóstico)

Ya confirmado con tu `diag.txt`, para que no tengas que buscarlo:

| Qué | Valor |
|---|---|
| AppImage de Eden | `/home/deck/Applications/Eden.AppImage` |
| Config de Eden | `/home/deck/.config/eden/qt-config.ini` (sin modo portable) |
| Datos de Eden | `/home/deck/.local/share/eden` |
| Perfil `emudeck` | `/home/deck/.config/eden/input/emudeck.ini` ✔ existe |
| Prefijo del perfil | **sin** prefijo (`button_a=...`); el script se adapta solo |
| Guid que usa hoy | `03000000de280000ff110001 000000` → **Valve `28de:11ff` = Steam Virtual Gamepad** |
| Lanzador de EmuDeck | **no existe** `~/Emulation/tools/launchers` → se usa el hook de ES-DE |
| Cómo lanza ES-DE | `%EMULATOR_EDEN% -f -g %ROM%` (definido en `custom_systems/es_systems.xml`) |
| Scripts de evento ES-DE | `CustomEventScripts=false` → **hay que activarlo** |
| Mando integrado | `ASUS ROG Ally X Gamepad` — **`0b05:1b4c`**, con `js0` (hid-asus, **no** xpad) |
| Pad virtual de Steam | `Microsoft X-Box 360 pad 0` — `28de:11ff`, con `js1` |
| DualSense | 4 emparejados (`48:18:8D:C5:2C:4A`, `4C:B9:9B:23:F1:FB`, `4C:B9:9B:E9:BC:26`, `D0:BC:C1:02:FB:9D`), ninguno conectado en ese momento |
| Puertos actuales | P1→4, P2→2, P3→3, **P4→4** (P1 y P4 compartían puerto) → a normalizar |

**Consecuencia importante:** como el guid que usas es el del **pad virtual de
Steam**, tienes **Steam Input activado**. Ver la sección 5 para elegir entre los
dos modos. El script funciona en ambos, pero la asignación “Player N = DualSense N”
solo es exacta con **Steam Input desactivado** para ES-DE.

---

## 1. Qué hace

Al lanzar un juego de Switch desde ES-DE, antes de que Eden arranque:

| Mandos detectados | Player 1 | Player 2 | Player 3 | Player 4 | Player 5..N |
|---|---|---|---|---|---|
| 0 DualSense | **mando integrado de la Ally** | desconectado | desconectado | desconectado | desconectados |
| 1 DualSense | DualSense 1 | desconectado | — | — | desconectados |
| 2 DualSense | DualSense 1 | DualSense 2 | desconectado | — | desconectados |
| 3 DualSense | DualSense 1 | DualSense 2 | DualSense 3 | desconectado | desconectados |
| 4 DualSense | DualSense 1 | DualSense 2 | DualSense 3 | DualSense 4 | desconectados |

Además, a cada jugador asignado se le clona **el mapeo del perfil `emudeck`**
(el que instala EmuDeck y guarda Eden en `<config>/input/emudeck.ini`), cambiando
sólo lo necesario para que apunte a ese mando:

* el prefijo `player_0_` → `player_K_`
* el puerto `port:0` → `port:K` dentro de las cadenas de mapeo
* `connected` / `type`

**El resto del `qt-config.ini` queda byte a byte intacto.** Los jugadores sobrantes
sólo cambian su línea `player_K_connected` a `false`. Nunca se borra nada.

### Ajustes configurables

En `~/eden-autoconfig/eden-autoconfig.conf`:

| Variable | Por defecto | Qué hace |
|---|---|---|
| `ORDEN_INTEGRADO` | `ignorar` | `ignorar` / `primero` / `ultimo`. Con `primero` el mando integrado es siempre P1 y los DualSense van detrás → **P1 estable y siempre identificable**. Con `ultimo`, el integrado es un jugador extra al final. |
| `JUGADORES_MAX` | `4` | máximo de DualSense a asignar |
| `PERFIL` | `emudeck` | perfil de Eden que se clona |
| `TIPO_CONTROLADOR` | `0` | 0 = Pro Controller |
| `GUID_DUALSENSE` / `GUID_INTEGRADO` | vacío | forzar un guid concreto (normalmente no hace falta) |
| `EXIGIR_P1_MAC` | vacío | MAC que quieres como P1; si no coincide, avisa |
| `AVISAR_SIN_NEGOCIAR` | `0` | `1` = si `EXIGIR_P1_MAC` no coincide, no aplica cambios |
| `RETENCION_BACKUPS` | `0` | 0 = no borrar nunca copias de seguridad |

---

## 2. Instalación (desde tu otro PC a la Ally)

Copia esta carpeta a la Ally por `scp` o USB, y allí:

```bash
cd /ruta/a/eden_controller
bash instalar.sh                 # primero prueba con --dry-run si quieres
```

Instala en:

```
~/eden-autoconfig/eden-autoconfig.sh          (+x)
~/eden-autoconfig/eden-autoconfig.conf        (no sobreescribe si ya existe)
~/eden-autoconfig/eden-diagnostico.sh         (+x)
~/eden-autoconfig/templates/
~/eden-autoconfig/backups/
~/ES-DE/scripts/game-start/10-eden-autoconfig.sh   (+x)
```

Todo queda bajo `$HOME`. No se instala nada en el sistema y no se usa `pacman`
ni `sudo`.

Ejemplo con `scp` desde tu PC:

```bash
scp -r eden_controller deck@IP-DE-LA-ALLY:~/
ssh deck@IP-DE-LA-ALLY 'cd ~/eden_controller && bash instalar.sh'
```

---

## 3. Primer uso: crear las dos plantillas (OPCIONAL)

> **Con la detección por SDL ya no son necesarias.** El script pone el **guid y
> el puerto** de cada mando automáticamente, y los *bindings* (qué botón hace
> qué) los saca del perfil `emudeck` que ya tiene Eden. Las plantillas solo
> sirven si algún día quieres forzar un mapeo distinto del de Eden. Si no
> quieres complicarte, sáltate esta sección y ve al punto 4.

Las plantillas son el mapeo que se clona. Hay dos: `dualsense` y `ally`.
**Se crean una sola vez** (y se rehacen si cambias de mando o de Steam Input).

> Regla de oro: la plantilla `X` se guarda **con el mando `X` configurado y
> seleccionado como Player 1 en Eden**.

> **Antes de empezar, decide el modo de Steam Input** (sección 5) y no lo
> cambies después: el guid del mapeo depende de ello (pad virtual de Valve vs
> DualSense real). Si lo cambias, hay que rehacer las plantillas.

### 3.1 Plantilla `dualsense`

1. Decide el modo: con **Steam Input desactivado** para ES-DE el perfil tendrá
   el guid real del DualSense (`054c`) — es lo recomendado para que las reglas
   “Player N = DualSense N” sean exactas.
2. Conecta **un** DualSense por Bluetooth.
3. Abre Eden → *Emulation → Configure → Controls*.
4. Player 1 → **Input Device**: selecciona el DualSense.
5. Desplegable **Profile** (arriba a la derecha): elige `emudeck`.
   Comprueba que los botones se auto-rellenan. Pulsa **OK** y cierra Eden.
6. En la terminal:

```bash
~/eden-autoconfig/eden-autoconfig.sh --save-template dualsense
```

Si el guid guardado no “parece de Sony” (`4c05`) el script avisa y pide
`--force`: suele significar que Steam Input sigue activo y lo que Eden ve es el
pad virtual.

Si el guid guardado no “parece de Sony” avisa; con `--force` continúa igual.

### 3.2 Plantilla `ally`

1. **Desconecta todos los DualSense** (que Eden sólo vea el mando integrado).
2. Eden → *Configure → Controls* → Player 1: selecciona el mando integrado,
   perfil `emudeck`, **OK**, cierra Eden.
3. En la terminal:

```bash
~/eden-autoconfig/eden-autoconfig.sh --save-template ally
```

### 3.3 Comprobar

```bash
~/eden-autoconfig/eden-autoconfig.sh --status
~/eden-autoconfig/eden-autoconfig.sh --dry-run --verbose
```

Todo se registra en `~/eden-autoconfig/log.txt`.

---

## 4. Integración con ES-DE

### Cómo funciona

ES-DE ejecuta los ficheros de `~/ES-DE/scripts/game-start/` en orden alfabético
y **espera a que terminen** antes de lanzar el emulador. Eso garantiza que el
`qt-config.ini` ya está escrito cuando Eden lee el fichero: no hace falta ningún
tipo de espera ni retardo.

A los scripts de evento `game-start` ES-DE les pasa 4 argumentos (documentado en
su `INSTALL.md`):

| Arg | Contenido |
|---|---|
| `$1` | ruta completa del fichero del juego |
| `$2` | nombre del juego |
| `$3` | **nombre del sistema** (`switch`) |
| `$4` | nombre completo (`Nintendo Switch`) |

El hook `10-eden-autoconfig.sh` comprueba que `$3` sea `switch` y, si lo es,
llama a `eden-autoconfig.sh --quiet`. Si fallara algo, **nunca impide que el
juego arranque** (siempre `exit 0`).

### Activarlo en ES-DE

Es un ajuste **desactivado por defecto**:

> ES-DE → **Other settings → Enable custom event scripts** → activar.

(Tras activarlo, ES-DE recarga. Los scripts deben tener permisos de ejecución;
`instalar.sh` ya los pone.)

### Cómo verificar que funciona

1. Lanza ES-DE desde el terminal con depuración:
   ```bash
   ~/Emulation/tools/launchers/es-de.sh --debug     # o el .sh que uses
   ```
2. Pon un juego de Switch.
3. Mira el log de ES-DE:
   ```bash
   grep -E 'Scripting::fireEvent|Executing:.*eden' ~/ES-DE/logs/es_log.txt | tail
   ```
   Debes ver algo como:
   ```
   Scripting::fireEvent(): game-start "/roms/switch/..." "Mario Kart 8 Deluxe" "switch" "Nintendo Switch"
   Executing: /home/deck/ES-DE/scripts/game-start/10-eden-autoconfig.sh "/roms/..." "..." "switch" "Nintendo Switch"
   ```
4. Y en el log propio:
   ```bash
   tail ~/eden-autoconfig/log.txt
   ls -la --time-style=full-iso ~/.config/eden/qt-config.ini   # fecha reciente
   ```

Ejemplo de línea que deja en el log de ES-DE (stderr del script):

```
eden-autoconfig.sh: dual:0:0 dual:1:1 | escenario=nativo | DualSense(SDL)=2 DualSense(BT)=2 virtuales=0
```

### Alternativa: llamarlo desde el launcher de EmuDeck

Si prefieres no usar los scripts de evento, edita
`~/Emulation/tools/launchers/eden.sh` e inserta esto **justo antes** de la línea
que lanza el AppImage (`exec ...`, `"$emulatorFile" "$@"`, etc.):

```bash
# --- eden-autoconfig (insertar antes del lanzamiento) ---
if [ -z "${EDEN_AUTOCONFIG_DONE:-}" ]; then
    export EDEN_AUTOCONFIG_DONE=1
    [ -x "$HOME/eden-autoconfig/eden-autoconfig.sh" ] && \
        "$HOME/eden-autoconfig/eden-autoconfig.sh" --quiet || true
fi
# -------------------------------------------------------
```

La variable `EDEN_AUTOCONFIG_DONE` evita recursión si el script volviera a
llamar al launcher.

**Recomendación:** usa el hook de ES-DE. EmuDeck puede sobrescribir los
launchers al actualizar; los scripts de evento de ES-DE son tuyos y no se tocan.
(Esto vale también para los juegos lanzados por separado desde Eden o desde un
acceso directo de Steam: en esos casos el script no se ejecuta; para esos casos
lanza `eden-autoconfig.sh` a mano.)

---

## 5. Steam Input: el detalle que lo cambia todo

ES-DE se ejecuta desde el Modo Juego, así que **Steam Input está por medio**.
Si está activado para el acceso de ES-DE, Steam convierte cada mando en un pad
XInput virtual y **oculta los DualSense físicos** a las aplicaciones:

* Eden ya no ve “Wireless Controller”, ve **“Steam Virtual Gamepad 0”, 1, 2…**
  (guid de Valve `28de` / `ff11`).
* Consecuencia: la asignación “Player N = DualSense N” no puede garantizarse,
  porque Eden no distingue la Ally de un DualSense.

La propia documentación de EmuDeck describe su flujo con Yuzu/Eden así:
*Profile → `emudeck`*, *Input Device → **`Steam Virtual Gamepad 0`***. Es decir,
el escenario “Steam Input activado” es el normal, no el raro.

### Cómo se comporta este script (soporta los dos escenarios)

Siempre detecta y **te dice cuál ha encontrado** (`--status`, log y la línea que
queda en `es_log.txt`):

| Escenario | Cómo se detecta | Qué hace |
|---|---|---|
| **Nativo** (Steam Input desactivado para ES-DE) | Aparecen “Wireless Controller” (vendor `054c`) en `/sys/class/input` | P1..PN = los DualSense reales |
| **Steam Input activo** | No hay DualSense visibles a SDL, pero sí pads virtuales de Valve (`28de`) | P1..PN = los pads virtuales 1..N. **Avisa** de que no puede distinguir cuál es la Ally |

Truco importante: aunque Steam Input oculte los DualSense a Eden, **siguen
siendo visibles por Bluetooth**. El script cuenta los DualSense con
`bluetoothctl`, así que el **número** de jugadores es correcto en ambos casos.

### Qué ajustar en Steam

Tecla **Steam** → biblioteca → **ES-DE** → icono del mando (o ⚙ → Propiedades →
Controlador):

* **“Disable Steam Input”** (Desactivar) — **recomendado para este script**:
  Eden verá los mandos reales, con guids distintos y sin ambigüedad:
  * `ASUS ROG Ally X Gamepad` (`0b05:1b4c`, guid único) → el integrado, siempre
    identificable.
  * `DualSense Wireless Controller` ×N (guid `054c:0ce6`, idéntico entre ellos)
    → P1..PN por puerto.

  Así “Player N = DualSense N” es exacto, y `ORDEN_INTEGRADO` funciona de verdad.
* **Dejar Steam Input activado**: Eden solo verá `Microsoft X-Box 360 pad 0..N`
  (guid Valve `28de:11ff`) y **no se puede saber cuál es la Ally y cuál un
  DualSense**. El script asigna igualmente los pads virtuales 1..N y te avisa
  con el número exacto (`hay 5 pads virtuales y 4 DualSense por Bluetooth → el
  sobrante es casi seguro el integrado`).

  Además, los nombres que crea Steam en el kernel (`... pad 0`, `... pad 1`…)
  siguen el **orden de mandos de Steam**, así que lo que reordenes en Steam se
  refleja en los puertos de Eden.

### Cómo saber en qué modo estás

```bash
~/eden-autoconfig/eden-autoconfig.sh --status
```

* `DualSense (sysfs/SDL): N` con guid `4c05...` → **nativo**.
* `Pads virtuales Steam: N` y `DualSense (Bluetooth): M` → **Steam Input activo**.

---

## 6. Orden de los mandos y quién es el “Player 1”

### Lo que YA no es un problema

El script lee el **puerto real** de cada mando en el momento de lanzar el juego
(vía SDL), así que ya no hay que adivinar ni configurar puertos a mano: escriba
lo que escriba Steam ese día, la asignación es la correcta. Antes esto fallaba
(el DualSense quedaba en el puerto 1 y P1 acababa siendo el mando integrado).

Verificado en el código de SDL y de Eden:

* El **guid** se construye con *bus + vendor + product + version + nombres*:
  **no incluye la MAC ni el número de serie**. → **Dos DualSense iguales tienen
  el mismo guid.**
* Eden identifica cada mando por `guid` + `port`, y `port` = *“el n-ésimo mando
  con ese mismo guid”*, en el orden en que SDL los enumera (y Steam los numera).
* Por tanto: **no se puede fijar un DualSense concreto por MAC desde
  `qt-config.ini`**. Es una limitación del emulador, no del script.

Tranquilidad: si tienes 4 DualSense y cada uno cae en un slot distinto,
**todos juegan**; lo único que puede bailar es *qué* mando físico es “P1”.

### Cómo fijar quién es P1 (nuevo)

Sin tocar nada, P1..PN se asignan **por orden de enumeración** (normalmente el
orden de conexión), así que el primero que conectas suele quedar como P1. Si
quieres algo **determinista**, en `eden-autoconfig.conf`:

```ini
# un DualSense CONCRETO siempre P1 (por su número de serie / MAC)
P1_SERIE="4c:b9:9b:e9:bc:26"

# o bien: ordenar por número de serie (el de serie más bajo es P1)
ORDEN_DUALSENSE="mac"
```

El número de serie lo ves en la columna **SERIE** de:

```bash
~/eden-autoconfig/eden-autoconfig.sh --mandos
```

(Si aparece `?`, ese mando no publica serie; en ese caso usa el orden de Steam.)

### Cómo saber quién controla los menús

1. **Orden de mandos de Steam** *(la otra vía con Steam Input activo)*.
   En la pantalla *Play* de ES-DE → icono del mando → reordena los mandos.
   Steam recuerda ese orden, y ese orden es el que acaba en los puertos. Para
   saber cuál es cuál, en el juego mira la pantalla de selección de jugador.
2. **`ORDEN_INTEGRADO=primero`**: el mando integrado es P1 **siempre** (el
   script lo identifica por su nombre, así que funciona también con Steam
   Input activo) y los DualSense van detrás. P1 determinista garantizado.
3. **`--who`** te dice qué MAC ocupa qué puerto **predicho** por Bluetooth
   (orientativo: los puertos reales los da SDL en cada lanzamiento).
4. **`--mandos`** te dice, en el momento actual, exactamente lo que ve Eden:
   nombre, guid, puerto y a qué jugador se asignaría.
5. **`EXIGIR_P1_MAC`**: si rellenas la MAC que quieres como P1, el script avisa
   cuando el primer DualSense detectado es otro. No puede cambiarlo, pero deja
   de ser sorpresa en mitad de la partida. Con `AVISAR_SIN_NEGOCIAR=1` no aplica
   cambios.

### Truco para ver los nombres que usa Eden

En *Eden → Configure → Controls*, el desplegable **Input Device** muestra los
mandos con el puerto añadido: en tu Ally aparecen como **`DualSense Controller N`**
y **`Asus Rog Ally Controller N`** (Eden los nombra por su *tipo*, no con el
nombre del kernel). Lo mismo que imprime `--mandos`.

---

## 7. Diagnóstico

```bash
~/eden-autoconfig/eden-diagnostico.sh > ~/diagnostico.txt 2>&1
```

**Sólo lee**, no escribe nada. Saca:

1. Entorno (SO, `$HOME`, herramientas disponibles).
2. Ubicación del AppImage de Eden y del launcher de EmuDeck (con su contenido).
3. Ruta real del `qt-config.ini` (probando `~/.config/eden/`,
   `~/.local/share/eden/`, modo portable `user/` junto al AppImage, etc.).
4. **`~/eden-autoconfig/eden-diagnostico.sh`** lista `<config>/input/*.ini` y
   muestra el contenido del perfil `emudeck` (incluido su `.bak`).
5. La sección `[Controls]` completa + tabla resumen por jugador (connected / type
   / puerto / guid) e interpretación de los guid por vendor.
6. Mandos: `bluetoothctl` (nombre, MAC, Connected) y `/sys/class/input` +
   `/proc/bus/input/devices` (nombre, MAC/`uniq`, vendor, product, handlers).
7. Detección provisional: qué escenario y qué asignación haría el script.
8. ES-DE: `~/ES-DE/scripts/`, el ajuste de scripts de evento, las líneas
   relevantes de `es_log.txt` y el bloque `switch` de `es_systems.xml`.
9. Procesos de Eden / ES-DE activos.

---

## 8. Verificación en la Ally (checklist)

- [ ] `bash instalar.sh` termina sin errores y existe
      `~/ES-DE/scripts/game-start/10-eden-autoconfig.sh` con permisos `755`.
- [ ] `eden-diagnostico.sh` **encuentra** el AppImage, el `qt-config.ini` y el
      perfil `emudeck`.
- [ ] El `qt-config.ini` que usa es el mismo que edita Eden (compáralo
      cambiando algo en la GUI y viendo la fecha del fichero).
- [ ] Con un DualSense conectado: `--status` dice **NATIVO** (o **STEAM INPUT
      ACTIVO** si lo tienes activado) y el número de DualSense coincide con los
      que tienes.
- [ ] `--save-template dualsense` guarda una plantilla cuyo guid contiene
      `4c05` (Sony) si el DualSense se ve nativo.
- [ ] `--save-template ally` guarda una plantilla con un guid **distinto**
      (ASUS/xpad/Valve).
- [ ] `--dry-run --verbose` muestra un diff **pequeño**: sólo líneas
      `player_*_connected`, `port:` y el prefijo de jugador.
- [ ] `--dry-run` no modifica el `qt-config.ini` (compara fechas).
- [ ] Con Eden cerrado, aplicar funciona; con Eden abierto, se **niega** (exit 3).
- [ ] Tras aplicar, en Eden → Controles los mandos aparecen ya asignados y
      los botones responden en el juego.
- [ ] Lanzando desde ES-DE aparece la línea `Executing: .../10-eden-autoconfig.sh`
      en `es_log.txt` y la fecha del `qt-config.ini` cambia justo antes del juego.
- [ ] Con 0 DualSense, P1 es el mando integrado y se puede jugar.
- [ ] Los jugadores sobrantes quedan desconectados (y el juego no se queja).
- [ ] `--restore` devuelve el fichero al estado anterior.

Ya confirmado con tu diagnóstico (sección 0): rutas, perfil `emudeck` con su
formato real, e `0b05:1b4c` para el integrado. **No hace falta tocar
`INTEGRADO_PATRON`.**

Pendiente de comprobar en la Ally:

1. Que con un DualSense conectado por Bluetooth `--status` cuenta los que hay
   (prueba con 1, 2, 3 y 4).
2. Que `--dry-run --verbose` muestra un `--- cambios ---` de solo unas pocas
   líneas `player_N_connected` (y `port:` las primeras veces).
3. Que tras aplicar, en Eden → *Ajustes → Controles* los mandos aparecen ya
   asignados (los verás como `Wireless Controller 0/1/...`) y los botones
   responden en el juego.
4. Que con 0 DualSense, P1 es el **integrado** y el juego arranca.
5. Si sales de un juego y vuelves a entrar, que sigue funcionando sin tocar nada.
6. Los 3 ficheros de `~/.config/eden/custom/`: confirmar que **ninguno** tiene
   claves `player_N_*` dentro de `[Controls]` (el diagnóstico v1.1 te lo dice
   explícitamente; por lo pegado, solo tienen `player_select_applet_mode`).
7. Con Steam Input desactivado, que el guid de la plantilla `dualsense` contiene
   `4c05` (Sony) en lugar de `de28` (Valve).

---

## 9. Problemas frecuentes

**“No encuentro el qt-config.ini de Eden”**
Pásalo a mano: `--config /ruta/exacta/qt-config.ini`. La ruta te la da el
diagnóstico.

**“Eden está en ejecución” (exit 3)**
Es intencionado: Eden reescribe `qt-config.ini` al cerrar y machacaría los
cambios. Ciérralo y vuelve a lanzar.

**Los mandos no responden en el juego**
Casi siempre es el **guid** de la plantilla: significa que la plantilla se
guardó con otro mando/otro modo de conexión (USB vs Bluetooth cambia el guid).
Vuelve a hacer `--save-template` con ese mando configurado en Eden.
El script avisa de esto cuando usa el perfil en vez de una plantilla.

**Un DualSense va a un jugador que no esperaba**
Ver punto 6. Con DualSense idénticos no se puede fijar por MAC. Usa Steam Input
+ orden en Steam, o `ORDEN_INTEGRADO=primero`, o conecta el de P1 el primero.

**Todo el mundo ve el mismo mando**
Comprueba que no has puesto el mismo `port:` en todos. El script lo hace solo,
pero si editas las plantillas a mano, ojo: `port:K` debe ser distinto por
jugador cuando comparten guid.

**El diff es enorme**
Revisa con `--dry-run --verbose`. Un diff grande sólo debería pasar la primera
vez si tu `qt-config.ini` tenía CRLF (el script normaliza a LF, que es lo que
escribe Eden en Linux). Después de la primera pasada, el diff es mínimo.

**EmuDeck sobrescribe la configuración**
“Manage Emulators → Eden → reset configuration” y las actualizaciones de EmuDeck
pueden reescribir `qt-config.ini`. Las plantillas siguen en
`~/eden-autoconfig/templates/`, así que basta con volver a aplicar
(`eden-autoconfig.sh`) — no hay que repetir el `--save-template`.

**`AVISO: el guid de la plantilla 'X' no aparece en tu qt-config.ini`**
La plantilla se guardó con otro modo de conexión o con otro estado de Steam
Input. Es el aviso más importante que da el script: si lo ignoras, los mandos
pueden no responder dentro del juego. Rehaz la plantilla (sección 3).

**Cambié de Steam Input (activado ⇄ desactivado) y ya no responde nada**
Normal: el guid del pad virtual de Valve no es el del DualSense real. Rehaz las
plantillas en el modo nuevo (sección 3).

**Un juego concreto ignora la configuración**
Comprueba si ese juego tiene *config por juego* en `~/.config/eden/custom/`.
Si un `<title id>.ini` define claves `player_N_*` **dentro de `[Controls]`**,
Eden ignora el `[Controls]` global para ese juego. `--status` y el diagnóstico
te avisan:
```
AVISO: hay configs POR JUEGO que definen jugadores y pueden ignorar el [Controls] global:
   0100152000022000(3)
```
En tu diagnóstico, los 3 ficheros de `custom/` solo tenían
`player_select_applet_mode` (que **no** es una clave de mando), así que en
principio no hay problema; vuelve a pasar el diagnóstico v1.1 para confirmarlo.

**En `--dry-run` veo líneas `-`/`+` idénticas**
Es solo **reordenación**: Eden/QSettings reordena las claves al guardar, así que
el orden no significa nada. Fíjate en `--- cambios ---` (donde el script te dice
las líneas cuyo *contenido* cambia de verdad) y no en el diff crudo.

---

## 10. Ficheros

```
eden_controller/
├── README.md
├── instalar.sh                        # instala en $HOME
├── eden-diagnostico.sh                # solo lectura: diagnóstico
├── eden-autoconfig.sh                 # despachador (--sistema)
├── eden-nucleo.sh                     # rutas, .conf y preferencias comunes
├── eden-driver-yuzu.sh                # Eden / Switch (qt-config.ini)
├── eden-driver-dolphin.sh             # Dolphin / GC y Wii
├── eden-driver-cemu.sh                # Cemu / Wii U (controllerN.xml)
├── eden-plantilla-cemu.xml            # plantilla de emergencia para Cemu
├── eden-mandos-sdl.sh                 # lista los mandos como los ve Eden (SDL)
├── eden-autoconfig.conf.example       # ajustes (copiar como .conf)
└── es-de-hooks/
    └── 10-eden-autoconfig.sh          # hook game-start de ES-DE
```

En la Ally, tras instalar:

```
~/eden-autoconfig/
├── eden-autoconfig.sh
├── eden-diagnostico.sh
├── eden-mandos-sdl.sh
├── eden-autoconfig.conf
├── sdl/                               # caché de la libSDL3 usada (y dump.py)
├── log.txt
├── templates/{dualsense,ally}.player0.txt
├── backups/qt-config.ini.AAAAMMDD-HHMMSS
└── preview/qt-config.ini.new          # sólo con --dry-run
~/ES-DE/scripts/game-start/10-eden-autoconfig.sh
```

### Notas técnicas

* **El AppImage de Eden usa `dwarfs`, no squashfs.** Al ejecutarse se monta en
  `/tmp/.mount_EdenXXXX` con un layout `bin/` + `lib/` (no `usr/bin` + `usr/lib`),
  y **`--appimage-extract` no sirve** (devuelve 0 ficheros). Para sacar su
  `libSDL3` hay que copiarla desde el montaje mientras Eden está abierto; el
  ayudante lo hace solo con `--copiar` usando `/proc/<pid>/exe` para localizar
  la raíz (`…/bin/eden` → `…`).
* Los procesos del AppImage **no usan chroot**: `/proc/<pid>/root` es `/`. La
  raíz del AppImage se deduce del ejecutable, no de `/proc/<pid>/root`.

* Los perfiles de Eden/Yuzu viven en `<config>/input/<nombre>.ini` (verificado en
  `yuzu/configuration/input_profiles.cpp`).
* Para distinguir mandos de teclados/ratones se usan los **handlers del kernel**
  (`/sys/class/input/inputN`): un mando de verdad tiene un nodo `jsN`. Esto
  evita contar como mando cosas como `steamos-manager` (`28de`, `kbd`) o
  `ASUSTeK ... N-KEY Device` (`0b05`, `mouse0`), que en tu Ally aparecen con los
  mismos vendor/product que los mandos.
* El orden de `/sys/class/input/input*` se ordena **numéricamente**
  (`input2` antes que `input10`); el glob normal se expande alfabéticamente y
  daría un orden falso.
* Formato de `qt-config.ini`: `clave\default=valor`. Cuando un valor cambia, el
  script escribe `\default=false`; cuando no cambia, conserva el flag original
  (así el fichero queda idéntico byte a byte en lo que no se toca).
* La calibración de los sticks (`offset_x` / `offset_y`) es de cada mando físico:
  **no** se copia de la plantilla, se conserva la del jugador original.
* Escritura **atómica** (fichero temporal + `mv`) y **validación posterior**
  (secciones, número de jugadores, claves no-jugador intactas, `connected`).
  Si la validación falla, no se toca el original.
* Copia de seguridad con fecha antes de cada cambio. `RETENCION_BACKUPS=0` =
  nunca se borra ninguna.
* Bloqueo con `flock` para que dos lanzamientos simultáneos no se pisen.
* Nunca escribe fuera de `$HOME`.

---

## 11. Dolphin (GameCube/Wii) y Cemu (Wii U)

El mismo script sirve para los tres emuladores; se elige con `--sistema`
(sin él, Eden):

```
eden-autoconfig.sh --sistema gc     # Dolphin: GCPadNew.ini / WiimoteNew.ini
eden-autoconfig.sh --sistema wii    # lo mismo (Wii)
eden-autoconfig.sh --sistema wiiu   # Cemu: controllerProfiles/controllerN.xml
```

El hook de ES-DE ya lo hace solo: `switch` → Eden, `gc`/`wii` → Dolphin,
`wiiu` → Cemu.

**Dolphin** reescribe el dispositivo de cada puerto (`Device = SDL/<indice>/<nombre>`),
activa los puertos de GameCube (`SIDevice0..3`), pone `Source = 1` en los Wiimotes
emulados y apunta `Hotkeys.ini` al jugador 1. EmuDeck ya deja los botones
configurados; N.E.C.A no los toca. Si un puerto usa el adaptador GC real
(`SIDeviceN = 12`), se respeta y se avisa.

**Cemu** solo cambia el dispositivo de cada mando. El `uuid` que guarda Cemu es
`<n>_<guid>` con el CRC **real** (Eden lo pone a cero), por eso el driver pide
el guid a la SDL del sistema. Se conservan el tipo (GamePad/Pro), el perfil y
los bindings; las ranuras que sobran quedan en `Disconnected`.

En los dos, el integrado entra según `ORDEN_INTEGRADO`: `ignorar` (por
defecto), `primero` (Player 1) o `ultimo` (detrás de los DualSense). Si no hay
ningún DualSense, entra siempre y de primero. `P1_SERIE` sigue mandando.

Cada ejecución (también la del hook, en silencio) deja rastro:

- `~/eden-autoconfig/log.txt`: qué se detectó, el plan y los avisos.
- `~/eden-autoconfig/plan-wiiu.txt` / `plan-dolphin.txt`: el último plan, que
  es lo que enseña la sección **Asignación** del panel.

Comandos útiles:

```bash
eden-autoconfig.sh --sistema wiiu --status        # qué hay ahora
eden-autoconfig.sh --sistema wiiu --dry-run       # qué haría, sin escribir
eden-autoconfig.sh --sistema wiiu --diagnostico   # carpetas y ficheros de Cemu
eden-autoconfig.sh --sistema wiiu --restore       # deshacer el último aplicar
eden-autoconfig.sh --sistema wiiu --restore stock # volver al estado anterior a N.E.C.A
```

Si Cemu está en una carpeta rara, se fija en el `.conf`:

```
CEMU_DIR=/ruta/a/Cemu
```
