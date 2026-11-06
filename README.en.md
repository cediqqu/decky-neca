# N.E.C.A: Nintendo-EmuDeck Controller Autoconf

A [Decky](https://decky.xyz/) plugin that autoconfigures the controllers of the
Nintendo emulators from the Steam Quick Access Menu (QAM): **[Eden](https://eden-emu.dev/)**
(Switch), **Dolphin** (GameCube/Wii) and **Cemu** (Wii U). It sets **Player 1**,
picks **how many controllers** to use and **what to do with the built-in
controller**, and applies it when a game launches from [ES-DE](https://es-de.org/).
No root.

[![Release](https://img.shields.io/github/v/release/CeDiqqu/decky-neca?label=release)](https://github.com/CeDiqqu/decky-neca/releases/latest)
[![License](https://img.shields.io/github/license/CeDiqqu/decky-neca)](https://github.com/CeDiqqu/decky-neca/blob/main/LICENSE)

[Español](https://github.com/CeDiqqu/decky-neca/blob/main/README.md) · **English**

> **Status:** v2.0.0 (Nov 6, 2026). First N.E.C.A release; it replaces E.C.A
> 1.0.0. Tested on **ROG Xbox Ally X** running SteamOS with a DualSense over
> Bluetooth. Maintained by [CeDiqqu](https://github.com/CeDiqqu), with no fixed
> release cadence.

Changes by version: [CHANGELOG.md](https://github.com/CeDiqqu/decky-neca/blob/main/CHANGELOG.md) (in Spanish).

Built for SteamOS handhelds with ES-DE (EmuDeck), not for Windows.

## Why N.E.C.A

- **Three emulators, one configuration.** Eden, Dolphin and Cemu get the right
  controller when a game launches.
- **Player 1 can be pinned by MAC**, not by port. Steam can renumber ports
  between sessions; N.E.C.A pins the exact controller.
- **Dolphin and Cemu do not rebuild the bindings.** They keep the mapping
  EmuDeck left in place; Dolphin also enables the ports (`SIDevice`/`Source`)
  and updates `Hotkeys.ini`.
- **In the `.conf`, it only writes one marked block** at the end of
  `eden-autoconfig.conf`. The rest of the file, your templates and your backups
  stay untouched.
- **It runs as `deck`, without root**, so the emulators can still write their
  files.
- **Automatic install and repair.** If the installed scripts are old or
  incomplete, the plugin restores them on load.
- **It disables Eden's controller applet** when applying, so Eden does not ask
  for confirmation when the game starts.

When **not** to use it: if you do not launch games from ES-DE (the hook lives
there), if your handheld is not an ASUS model (the built-in pattern may need
tuning), or if you need to pin more than one player by MAC.

## Requirements

- **Decky Loader** with `api_version: 1` (the plugin declares that value).
- **SteamOS** on a handheld. Windows is not supported.
- **EmuDeck** with the configuration of the emulators you use:

| ES-DE system | Emulator | Configuration N.E.C.A reads |
|---|---|---|
| `switch` | Eden (AppImage) | `<config>/eden/qt-config.ini` and the `emudeck` profile |
| `gc`, `wii` | Dolphin | `GCPadNew.ini`, `WiimoteNew.ini`, `Dolphin.ini` and `Hotkeys.ini` |
| `wiiu` | Cemu | `controllerProfiles/controller0.xml` |

- **ES-DE** with *Custom Event Scripts* enabled. The plugin expects ES-DE at
  `~/ES-DE` (EmuDeck's path); if it lives elsewhere, the hook is not installed
  automatically.
- **The emulator closed** before applying. The drivers refuse to write while
  Eden, Dolphin or Cemu are running.
- If Cemu lives in an unusual folder, set `CEMU_DIR` in
  `~/eden-autoconfig/eden-autoconfig.conf`.
- Optional: write access to `/dev/hidraw*` for vibration. If it is missing, the
  panel shows a diagnostic and everything else keeps working.

> [!NOTE]
> The panel UI is in Spanish. The steps below show its labels as they appear,
> with the English meaning in parentheses.

## Installation

1. Download **[neca-decky.zip](https://github.com/CeDiqqu/decky-neca/releases/latest/download/neca-decky.zip)**.
2. On the handheld: **Decky → Developer → Install Plugin from ZIP**. It installs
   to `~/homebrew/plugins/NecaAutoconfig/`.

> [!WARNING]
> **Coming from E.C.A?** Uninstall the previous plugin first (Decky → settings →
> plugins → E.C.A → uninstall). Your data is untouched: `~/eden-autoconfig`,
> templates, backups and the hook stay as they are. Installing without
> uninstalling leaves two panels.

3. Open the panel in the Quick Access Menu. The first time, press **Instalar
   scripts** (Install scripts). It copies the scripts to `~/eden-autoconfig`,
   installs the hook in `~/ES-DE/scripts/game-start/` if that folder exists and
   checks that SDL responds. If the scripts are already installed and old or
   incomplete, they are repaired on load.
4. In ES-DE: **Other settings → Enable custom event scripts**.

Check that the chips show **v2.0.0** and **hook OK**. You can also check from a
terminal:

```bash
~/eden-autoconfig/eden-autoconfig.sh --status
~/eden-autoconfig/eden-autoconfig.sh --sistema gc --status
~/eden-autoconfig/eden-autoconfig.sh --sistema wiiu --status
```

The command should find the emulator and end with `Eden en ejecucion: no` or the
equivalent Dolphin/Cemu state.

To update N.E.C.A, install the new zip; there is no need to uninstall. If you
come from E.C.A, uninstall the old plugin first.

## Quick start

1. Connect the controllers and open the panel. When the controller count
   changes, it refreshes on its own with a 5 s poll.
2. The chips at the top show the machine, the number of controllers, the version
   and the hook state.
3. The **Mandos** (Controllers) button with four slots cycles the player limit
   (1 to 4).
4. The **Integrado** (Built-in) card cycles **Player 1 → Last player → Off**.
   Without a manual choice, the built-in controller is Player 1 when there are no
   external controllers, goes last when there is at least one, and is disabled
   when there is no room.
5. To pin a specific controller as Player 1, **double-tap** its card (less than
   1.5 s apart). The **★** marks the current Player 1.
6. The **Asignación** (Assignment) icon in the **Mandos** header shows the last
   Cemu and Dolphin plan. **Comprobar ahora** (Check now) recalculates it without
   writing anything.
7. **Ajustes** (Settings) contains **Aplicar** (Apply, writes Eden),
   **Restaurar** (Restore, Eden, Dolphin and Cemu) and **Ver log** (View log).
   Dolphin and Cemu are applied when the game launches, or manually with
   `--sistema gc` and `--sistema wiiu`.

Each card shows the family **icon** (PlayStation, Xbox, Switch, Steam or
built-in), the **connection** (Bluetooth, USB, Internal or Virtual) and the short
**MAC** whenever the controller reports it. Unknown controllers also show their
name.

Short notices are drawn inside the panel and disappear after 5 s. Long errors,
such as the `hidraw` diagnostic, open in a window so you can read or copy them.

## Identifying a controller by vibration

- **One tap** on a DualSense card: the controller vibrates for 300 ms and the
  card flashes cyan.
- **Two taps in a row** (less than 1.5 s apart): that controller becomes the
  primary one.
- **DualSense only**: the built-in controller does not vibrate and other
  controller families are not supported by this protocol.
- The controller is located by its MAC (`uniq` or the `uevent`'s `HID_UNIQ`). If
  the system does not expose it, the only connected DualSense or the port order
  is used. If that fails, the panel shows a diagnostic of
  `/sys/class/hidraw`.
- Without permission on `/dev/hidraw*`, vibration does not work; the rest of the
  plugin still does.

## What it writes (and how to undo it)

Once the scripts are installed, the panel only writes two things:

1. A **managed block** at the end of `~/eden-autoconfig/eden-autoconfig.conf`.
2. Its private state in `~/.config/eden-autoconfig-decky/`.

The drivers, when applying or launching, write only each emulator's
configuration:

| Emulator | File | What it changes |
|---|---|---|
| Eden | `qt-config.ini` | controls and controller applet |
| Dolphin | `GCPadNew.ini`, `WiimoteNew.ini`, `Dolphin.ini`, `Hotkeys.ini` | device, GC ports, `Source` and hotkeys |
| Cemu | `controllerProfiles/controllerN.xml` | only the device |

The block is replaced as a whole; the rest of the `.conf` is untouched. Example:

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

- The ES-DE hook reads that same `.conf`, so what you choose in the panel is what
  gets applied when the game launches.
- If the `.conf` already existed, a copy of the previous version is saved in
  `~/.config/eden-autoconfig-decky/` before the block is replaced.
- If you delete the block, the `.conf` goes back to your previous values.
  Deleting the block does not touch `qt-config.ini`.
- Backups go to `~/eden-autoconfig/backups/`: `qt-config.ini.*` for Eden,
  `dolphin/GCPadNew.ini.*`, `dolphin/WiimoteNew.ini.*`, `dolphin/Dolphin.ini.*`
  and `dolphin/Hotkeys.ini.*` for Dolphin, and `cemu/controllerN.xml.*` for
  Cemu. The 10 most recent copies are kept per file. Each emulator's original
  lives separately in `stock/` (Eden in `~/eden-autoconfig/stock/`, Dolphin and
  Cemu inside their backup folders).

**Restaurar** (Restore) under **Ajustes** returns Eden, Dolphin and Cemu to
their pre-N.E.C.A state:

1. It restores Eden's original `qt-config.ini` from `stock/`.
2. It restores Dolphin's `GCPadNew.ini`, `WiimoteNew.ini`, `Dolphin.ini` and
   `Hotkeys.ini` from `backups/dolphin/stock/`.
3. It restores Cemu's `controllerN.xml` from `backups/cemu/stock/`.
4. It removes the preferences block from the `.conf`.
5. It disables the ES-DE hook (moves it out of
   `~/ES-DE/scripts/game-start/`).

Before changing anything, it saves a copy of the current state in `backups/`.
After that, the panel shows **Reactivar hook** (Reactivate hook) to install the
hook again.

If an emulator has no fixed copy (it was never applied by N.E.C.A), its oldest
backup is used; if there is none, it warns and leaves it alone. The per-system
commands are still available:

```bash
~/eden-autoconfig/eden-autoconfig.sh --sistema gc --restore latest
~/eden-autoconfig/eden-autoconfig.sh --sistema wiiu --restore stock
```

`latest` undoes only the last apply; `stock` returns to the pre-N.E.C.A state.

### Uninstall

1. **Ajustes → Restaurar** (Settings → Restore) to put Eden, Dolphin and Cemu
   back and remove the hook.
2. Remove the plugin from Decky.

If you uninstall without restoring, the hook remains in
`~/ES-DE/scripts/game-start/` and keeps applying the `.conf` even though the
plugin is gone. Uninstalling does not delete `~/eden-autoconfig`: your
templates, backups and `.conf` live there.

## Known limits

- **Apply from the panel only writes Eden.** Dolphin and Cemu are applied when
  the game launches from ES-DE or with `--sistema gc|wiiu`.
- **Restore from the panel affects all three emulators.** To undo only the
  last Dolphin or Cemu apply, use `--restore latest`.
- Only **one specific controller can be pinned as Player 1** (`P1_SERIE`). The
  rest follow the chosen order (connection or MAC).
- If a controller does not report a serial (some virtual pads), it cannot be
  pinned; the panel tells you.
- The **built-in controller** is not pinned by serial. It is controlled by the
  **Integrado** card and by `INTEGRADO_MANUAL`.
- **`JUGADORES_MAX` is the total number of players (1 to 4)**, including the
  built-in controller. If you force the built-in controller as Player 1 with four
  DualSense controllers, one DualSense is left out.
- The automatic built-in adjustment is recalculated when the **panel opens** or
  when you **Apply**. The hook uses the saved `.conf`.
- With **Steam Input enabled** for ES-DE, Eden sees Valve's virtual pads. The
  exact Player N = DualSense N mapping is only reliable with Steam Input
  disabled for ES-DE.
- **Dolphin and Cemu do not create bindings**: they only change the device. If
  EmuDeck did not leave a controller configuration, there is nothing to assign.
- Tested on **ROG Xbox Ally X**. On other handhelds, `INTEGRADO_PATRON` may need
  adjustment in the `.conf`.

## Development

```bash
npx tsc --noEmit          # type check
python3 test_backend.py   # backend tests
bash build.sh             # sync scripts/ + build + package the zip
```

`build.sh` requires Node 20+ and Python 3. The zip contains a single root folder,
`NecaAutoconfig/`, and the script bundle is versioned **2.0.0**.

- `scripts/` is a **generated copy** of `eden_controller/` (the source of truth).
  Do not edit it there; change `eden_controller/` and copy with `build.sh`.
- `scripts/VERSION` stores the version and hash, without a date; the panel
  compares the hash with the installed copy and warns when it is out of date.
- The backend (`main.py`) does not reimplement anything: it runs the installed
  scripts, auto-installs when files are missing and reads the Cemu/Dolphin plans.
  It can be tested without a console using a fake `HOME` and `EDEN_FAKE_SDL`.
- SDL, GUID CRC, templates and diagnostics:
  [`eden_controller` README](https://github.com/CeDiqqu/decky-neca/blob/main/eden_controller/README.md)
  (in Spanish).

---

BSD-3-Clause. See [LICENSE](https://github.com/CeDiqqu/decky-neca/blob/main/LICENSE).
If something does not add up, open an
[issue](https://github.com/CeDiqqu/decky-neca/issues) with the log from
`~/eden-autoconfig/log.txt`.
