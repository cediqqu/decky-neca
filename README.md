# N.E.C.A: Nintendo-EmuDeck Controller Autoconf

Plugin de [Decky](https://decky.xyz/) que autoconfigura los mandos de los
emuladores de Nintendo desde el menú rápido de Steam (QAM): **[Eden](https://eden-emu.dev/)**
(Switch), **Dolphin** (GameCube/Wii) y **Cemu** (Wii U). Fija el **Player 1**,
elige **cuántos mandos** usar y **qué hacer con el integrado**, y lo aplica al
lanzar el juego desde [ES-DE](https://es-de.org/). Sin root.

[![Release](https://img.shields.io/github/v/release/CeDiqqu/decky-neca?label=release)](https://github.com/CeDiqqu/decky-neca/releases/latest)
[![Licencia](https://img.shields.io/github/license/CeDiqqu/decky-neca)](https://github.com/CeDiqqu/decky-neca/blob/main/LICENSE)

[English](https://github.com/CeDiqqu/decky-neca/blob/main/README.en.md) · **Español**

> **Estado:** v2.0.0 (6 nov 2026). Primera versión de N.E.C.A; sustituye a
> E.C.A 1.0.0. Probada en **ROG Xbox Ally X** con SteamOS y DualSense por
> Bluetooth. Mantenida por [CeDiqqu](https://github.com/CeDiqqu), sin cadencia
> fija.

Cambios por versión: [CHANGELOG.md](https://github.com/CeDiqqu/decky-neca/blob/main/CHANGELOG.md).

Pensado para PC de mano con SteamOS y ES-DE (EmuDeck), no para Windows.

## Por qué N.E.C.A

- **Tres emuladores, una sola configuración.** Eden, Dolphin y Cemu reciben el
  mando que les toca al lanzar.
- **Puedes fijar el Player 1 por MAC**, no por puerto. Steam puede renumerar los
  puertos entre sesiones; N.E.C.A fija el mando concreto.
- **Dolphin y Cemu no rehacen los bindings.** Conservan el mapeo que dejó
  EmuDeck; Dolphin además activa los puertos (`SIDevice`/`Source`) y ajusta
  `Hotkeys.ini`.
- **En el `.conf`, solo escribe un bloque marcado** al final de
  `eden-autoconfig.conf`. El resto del fichero, tus plantillas y tus copias
  quedan intactos.
- **Corre como `deck`, sin root**, para que los emuladores sigan pudiendo
  escribir sus ficheros.
- **Auto-instalación y reparación.** Si los scripts están viejos o incompletos,
  el plugin los repone al cargar.
- **Desactiva el applet de mandos de Eden** al aplicar, para que no pida
  confirmación al iniciar el juego.

Cuándo **no** usarlo: si no lanzas los juegos desde ES-DE (el hook vive ahí), si
tu handheld no es ASUS (el patrón del integrado puede necesitar ajuste) o si
necesitas fijar más de un jugador por MAC.

## Requisitos

- **Decky Loader** con `api_version: 1` (el plugin declara ese valor).
- **SteamOS** en un PC de mano. No soporta Windows.
- **EmuDeck** con la configuración de los emuladores que uses:

| Sistema ES-DE | Emulador | Configuración que lee N.E.C.A |
|---|---|---|
| `switch` | Eden (AppImage) | `<config>/eden/qt-config.ini` y el perfil `emudeck` |
| `gc`, `wii` | Dolphin | `GCPadNew.ini`, `WiimoteNew.ini`, `Dolphin.ini` y `Hotkeys.ini` |
| `wiiu` | Cemu | `controllerProfiles/controller0.xml` |

- **ES-DE** con *Custom Event Scripts* activado. El plugin espera ES-DE en
  `~/ES-DE` (la ruta de EmuDeck); si está en otro sitio, el hook no se instala
  solo.
- **El emulador cerrado** antes de aplicar. Los drivers se niegan a escribir si
  Eden, Dolphin o Cemu están en marcha.
- Si Cemu está en una carpeta rara, fija `CEMU_DIR` en
  `~/eden-autoconfig/eden-autoconfig.conf`.
- Opcional: permiso de escritura en `/dev/hidraw*` para la vibración. Si no lo
  hay, el panel lo diagnostica y el resto sigue funcionando.

## Instalación

1. Descarga **[neca-decky.zip](https://github.com/CeDiqqu/decky-neca/releases/latest/download/neca-decky.zip)**.
2. En la consola: **Decky → Developer → Install Plugin from ZIP**. Se instala en
   `~/homebrew/plugins/NecaAutoconfig/`.

> [!WARNING]
> **¿Vienes de E.C.A?** Desinstala antes el plugin anterior (Decky → ajustes →
> plugins → E.C.A → desinstalar). Tus datos no se tocan: `~/eden-autoconfig`,
> las plantillas, los backups y el hook se quedan como están. Si instalas sin
> desinstalar, verás dos paneles.

3. Abre el panel en el menú rápido. La primera vez pulsa **Instalar scripts**.
   Copia los scripts a `~/eden-autoconfig`, deja el hook en
   `~/ES-DE/scripts/game-start/` si existe esa carpeta y comprueba que SDL
   responde. Si ya tenías los scripts y están viejos o incompletos, se reparan
   solos al cargar.
4. En ES-DE: **Other settings → Enable custom event scripts**.

Comprueba que los chips muestran **v2.0.0** y **hook OK**. También puedes
comprobarlo por terminal:

```bash
~/eden-autoconfig/eden-autoconfig.sh --status
~/eden-autoconfig/eden-autoconfig.sh --sistema gc --status
~/eden-autoconfig/eden-autoconfig.sh --sistema wiiu --status
```

El comando debe encontrar el emulador y terminar con `Eden en ejecucion: no` o
el estado equivalente de Dolphin/Cemu.

Para actualizar N.E.C.A, instala el zip nuevo; no hace falta desinstalar. Si
vienes de E.C.A, desinstala primero el plugin viejo.

## Uso rápido

1. Conecta los mandos y abre el panel. Si cambia el número de mandos, se
   refresca solo con un sondeo cada 5 s.
2. Arriba tienes chips con la máquina, el número de mandos, la versión y el
   estado del hook.
3. El botón **Mandos** con cuatro huecos cicla el tope de jugadores (1 a 4).
4. La tarjeta **Integrado** cicla **Jugador 1 → Último jugador → Desactivado**.
   Sin elección manual, el integrado es Player 1 si no hay externos, va al final
   si hay alguno y se desactiva si no queda hueco.
5. Para fijar un mando concreto como Player 1, **dos toques seguidos** (menos de
   1,5 s) sobre su tarjeta. La **★** marca el Player 1 actual.
6. El icono de **Asignación** en la cabecera de **Mandos** abre el último plan de
   Cemu y Dolphin. **Comprobar ahora** lo recalcula sin escribir nada.
7. En **Ajustes** están **Aplicar** (escribe Eden), **Aplicar todo** (Eden,
   Dolphin y Cemu), **Restaurar** (los tres) y **Ver log** (con scroll).
   Dolphin y Cemu se aplican también al lanzar el juego, o a mano con
   `--sistema gc` y `--sistema wiiu`.

Cada tarjeta muestra el **icono** de la familia (PlayStation, Xbox, Switch, Steam
o integrado), la **conexión** (Bluetooth, USB, Interno o Virtual) y la **MAC**
corta siempre que el mando la informe. Los mandos desconocidos muestran además
su nombre.

Los avisos cortos se pintan dentro del panel y desaparecen a los 5 s. Los errores
largos, como el diagnóstico de `hidraw`, se abren en una ventana para poder
leerlos o copiarlos.

## Reconocer un mando por vibración

- **Un toque** sobre una tarjeta DualSense: el mando vibra 300 ms y la tarjeta
  destella en cian.
- **Dos toques seguidos** (menos de 1,5 s): ese mando pasa a ser el principal.
- **Solo DualSense**: el integrado no vibra y los mandos de otras familias no
  están soportados por este protocolo.
- Para localizarlo se usa su MAC (`uniq` o `HID_UNIQ` del `uevent`). Si el
  sistema no la da, se usa el único DualSense conectado o el orden de puerto. Si
  falla, el panel muestra un diagnóstico de `/sys/class/hidraw`.
- Sin permisos sobre `/dev/hidraw*`, la vibración no funciona; el resto del
  plugin sí.

## Qué escribe (y cómo volver atrás)

Una vez instalados los scripts, el panel solo escribe dos cosas:

1. Un **bloque gestionado** al final de `~/eden-autoconfig/eden-autoconfig.conf`.
2. Su estado privado en `~/.config/eden-autoconfig-decky/`.

Los drivers, al aplicar o al lanzar, escriben solo la configuración de cada
emulador:

| Emulador | Fichero | Qué cambia |
|---|---|---|
| Eden | `qt-config.ini` | controles y applet de mandos |
| Dolphin | `GCPadNew.ini`, `WiimoteNew.ini`, `Dolphin.ini`, `Hotkeys.ini` | dispositivo, puertos GC, `Source` y atajos |
| Cemu | `controllerProfiles/controllerN.xml` | solo el dispositivo |

El bloque se sustituye entero; el resto del `.conf` no se toca. Ejemplo:

```ini
# >>> eden-autoconfig-decky >>>
P1_SERIE="4c:b9:9b:e9:bc:26"
JUGADORES_MAX=2
ORDEN_INTEGRADO="ultimo"
INTEGRADO_MANUAL="si"
ORDEN_DUALSENSE="mac"
RETENCION_BACKUPS=10
# <<< eden-autoconfig-decky <<<
```

- El hook de ES-DE lee ese mismo `.conf`, así que lo que eliges en el panel es lo
  que se aplica al lanzar el juego.
- Si el `.conf` ya existía, se guarda una copia del anterior en
  `~/.config/eden-autoconfig-decky/` antes de reemplazar el bloque.
- Si borras el bloque, el `.conf` vuelve a tus valores anteriores. El
  `qt-config.ini` no se toca por borrar el bloque.
- Los backups van a `~/eden-autoconfig/backups/`: `qt-config.ini.*` para Eden,
  `dolphin/GCPadNew.ini.*`, `dolphin/WiimoteNew.ini.*`, `dolphin/Dolphin.ini.*`
  y `dolphin/Hotkeys.ini.*` para Dolphin, y `cemu/controllerN.xml.*` para Cemu.
  Se conservan las 10 copias más recientes por fichero. El original de cada
  emulador vive aparte, en `stock/` (Eden en `~/eden-autoconfig/stock/`, Dolphin
  y Cemu dentro de su carpeta de backups).

**Restaurar** en **Ajustes** devuelve Eden, Dolphin y Cemu al estado anterior a
N.E.C.A:

1. Restaura el `qt-config.ini` original de Eden (`stock/`).
2. Restaura `GCPadNew.ini`, `WiimoteNew.ini`, `Dolphin.ini` y `Hotkeys.ini` de
   Dolphin desde `backups/dolphin/stock/`.
3. Restaura los `controllerN.xml` de Cemu desde `backups/cemu/stock/`.
4. Quita el bloque de preferencias del `.conf`.
5. Desactiva el hook de ES-DE (lo mueve fuera de
   `~/ES-DE/scripts/game-start/`).

Antes de tocar nada se guarda una copia del estado actual en `backups/`. Después,
el panel muestra **Reactivar hook** para volver a copiarlo.

Si un emulador no tiene copia fija (nunca se aplicó con N.E.C.A), se usa su
backup más antiguo y, si tampoco hay, se avisa sin tocar nada. Los comandos
siguen disponibles para casos concretos:

```bash
~/eden-autoconfig/eden-autoconfig.sh --sistema gc --restore latest
~/eden-autoconfig/eden-autoconfig.sh --sistema wiiu --restore stock
```

`latest` deshace solo el último aplicar; `stock` vuelve al estado anterior a
N.E.C.A.

### Desinstalar

1. **Ajustes → Restaurar** para devolver Eden, Dolphin y Cemu y quitar el hook.
2. Quita el plugin desde Decky.

Si desinstalas sin restaurar, el hook seguirá en
`~/ES-DE/scripts/game-start/` y seguirá aplicando el `.conf` aunque el plugin ya
no esté. `~/eden-autoconfig` no se borra al desinstalar: ahí están tus plantillas,
backups y el `.conf`.

### Log y diagnóstico

- **Ver log** abre `log.txt` en una ventana con scroll. Cada aplicar deja la
  versión y el hash de los scripts, los `Device` escritos, `SIDevice`, `Source`
  y los avisos.
- Si Dolphin o Cemu están abiertos, no se escribe y queda en el log
  (`en ejecucion, no aplico`). Ciérralos del todo y vuelve a lanzar.
- Tras instalar o actualizar scripts, el panel avisa; cierra el juego y vuelve
  a abrirlo, o pulsa **Aplicar todo**.

## Límites conocidos

- **Aplicar** escribe solo Eden; **Aplicar todo** escribe Eden, Dolphin y Cemu.
  Dolphin y Cemu también se aplican al lanzar el juego desde ES-DE o con
  `--sistema gc|wiiu`.
- **Restaurar desde el panel afecta a los tres emuladores.** Para deshacer solo
  el último aplicar de Dolphin o Cemu, usa `--restore latest`.
- Solo se puede fijar **un mando concreto como Player 1** (`P1_SERIE`). El resto
  sigue el orden elegido (conexión o MAC).
- Si un mando no informa de su serie (pasa con algunos pads virtuales), no se
  puede fijar; el panel te lo dice.
- El **mando integrado** no se fija por serie. Se controla con la tarjeta
  **Integrado** y con `INTEGRADO_MANUAL`.
- **`JUGADORES_MAX` es el total de jugadores (1 a 4)**, integrado incluido. Si
  fuerzas el integrado como Player 1 con cuatro DualSense, uno de los DualSense
  queda fuera.
- El ajuste automático del integrado se recalcula al **abrir el panel** o al
  **Aplicar**. El hook usa el `.conf` guardado.
- Con **Steam Input activado** para ES-DE, Eden ve pads virtuales de Valve. La
  asignación exacta Player N = DualSense N solo es fiable con Steam Input
  desactivado para ES-DE.
- **Dolphin y Cemu no crean bindings**: Dolphin cambia el dispositivo y activa
  los puertos (`SIDevice`/`Source`); Cemu cambia el dispositivo. Si EmuDeck no
  dejó los bindings, no hay nada que asignar.
- En **Dolphin**, si un puerto usa el **adaptador GC real** (`SIDeviceN = 12`),
  N.E.C.A no lo toca y lo avisa: en ese puerto manda el adaptador.
- Probado en **ROG Xbox Ally X**. En otras handhelds, `INTEGRADO_PATRON` puede
  necesitar ajuste en el `.conf`.

## Desarrollo

```bash
npx tsc --noEmit          # tipado
python3 test_backend.py   # pruebas del backend
bash build.sh             # sincroniza scripts/ + compila + genera el zip
```

`build.sh` necesita Node 20+ y Python 3. El zip lleva una carpeta raíz
`NecaAutoconfig/` y el bundle de scripts se marca como **2.0.0**.

- `scripts/` es una **copia generada** desde `eden_controller/` (la fuente de
  verdad). No se edita ahí; los cambios van a `eden_controller/` y se copian con
  `build.sh`.
- `scripts/VERSION` guarda versión y hash, sin fecha; el panel compara el hash
  con lo instalado y avisa si está desactualizado.
- El backend (`main.py`) no reimplementa nada: ejecuta los scripts instalados,
  autoinstala si faltan ficheros y lee los planes de Cemu/Dolphin. Se puede
  probar sin consola con un `HOME` falso y `EDEN_FAKE_SDL`.
- Detalles de SDL, CRC del GUID, plantillas y diagnóstico:
  [README de `eden_controller`](https://github.com/CeDiqqu/decky-neca/blob/main/eden_controller/README.md).

---

BSD-3-Clause. Ver [LICENSE](https://github.com/CeDiqqu/decky-neca/blob/main/LICENSE).
Si algo no cuadra, abre un [issue](https://github.com/CeDiqqu/decky-neca/issues)
con el log de `~/eden-autoconfig/log.txt`.
