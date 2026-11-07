# Changelog

Todos los cambios relevantes de N.E.C.A se documentan aquí. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones usan
[SemVer](https://semver.org/lang/es/).

## [Unreleased]

<!-- Añade aquí los cambios sin versión. Al publicar, crea ## [x.y.z] - YYYY-MM-DD. -->

### Corregido

- **Dolphin: los jugadores 2–4 ahora funcionan.** EmuDeck deja activo solo el
  puerto 1 de GameCube (`SIDevice1..3 = 0`) y los Wiimotes 2–4 en `Source = 0`;
  el driver ahora escribe `SIDevice0..3` en `Dolphin.ini` e **inserta**
  `Source = 1` en los Wiimotes del plan (EmuDeck no trae esa línea). También
  apunta `Hotkeys.ini` al jugador 1. Respeta el adaptador GC real
  (`SIDeviceN = 12`) y los Wiimotes reales (`Source = 2`).
- **Dolphin: el Player 2 con otro mando ya funciona.** Dolphin asigna el id de
  `SDL/<id>/<nombre>` por nombre de dispositivo, no por el índice global de SDL
  (con un DualSense y el integrado, ambos son `id 0` de su nombre). El driver
  ahora usa el n-ésimo con ese mismo nombre; antes escribía `SDL/1/Asus…` y
  Dolphin esperaba `SDL/0/Asus…`.
- **El log muestra los `Device` escritos.** Cada aplicar deja en `log.txt` el
  `GCPadN Device`, `SIDevice0..3`, `Source` y `Hotkeys` resultantes, para poder
  verlo desde **Ver log** sin abrir una consola.
- **Restaurar vuelve al estado anterior a N.E.C.A en Dolphin y Cemu.** Cada
  driver guarda una copia fija en `backups/<emu>/stock/` la primera vez que
  aplica; **Restaurar** usa esa copia (`--restore stock`), no el último backup.
  `--restore latest` sigue disponible para deshacer solo el último aplicar.

### Añadido

- **Dolphin usa `Dolphin.ini` y `Hotkeys.ini`.** Además de `GCPadNew.ini` y
  `WiimoteNew.ini`, el driver activa los puertos de GameCube y ajusta los
  atajos del jugador 1, con backup, escritura atómica y validación.
- **«Aplicar todo» en el panel.** Escribe Eden, Dolphin y Cemu de una vez, sin
  depender del hook ni de lanzar un juego.
- **Log con scroll.** **Ver log** abre una ventana desplazable (D-pad, stick o
  dedo) en lugar de la paginación por botones. Devuelve hasta 800 líneas.
- **Aviso de scripts recién instalados.** Si el plugin acaba de actualizar los
  scripts, el panel avisa de que hay que cerrar el juego y relanzarlo (o pulsar
  **Aplicar todo**). El aviso se limpia al aplicar.
- **Versión y hash en el log.** Cada aplicar registra `version=`, `hash=`, los
  `Device` escritos, `SIDevice`, `Source` y `Hotkeys`.
- **Aviso de emulador abierto en el log.** Si Dolphin o Cemu están en ejecución,
  el log deja `en ejecucion, no aplico` en vez de fallar en silencio.

## [2.0.0] - 2026-11-06

### Cambios incompatibles

- **N.E.C.A sustituye a E.C.A, cambia la carpeta del plugin a `NecaAutoconfig/`
  y el zip pasa a `neca-decky.zip`.** Desinstala E.C.A desde Decky antes de
  instalar este zip. Los datos no se tocan: `~/eden-autoconfig`, plantillas,
  backups y hook siguen en su sitio. Si no desinstalas, quedan dos paneles.

### Añadido

- **Soporte para Dolphin (GameCube/Wii) y Cemu (Wii U).** El despachador elige
  el driver con `--sistema switch|gc|wii|wiiu`; el hook de ES-DE hace lo mismo
  al lanzar el juego.
- **Vista de Asignación para Cemu y Dolphin.** Muestra el último plan de cada
  emulador y permite recalcularlo con **Comprobar ahora** sin escribir nada.
- **Auto-instalación y reparación.** Si los scripts instalados están viejos o
  incompletos, el plugin ejecuta `instalar.sh` al cargar; el panel ofrece
  **Reparar instalación** cuando faltan ficheros.
- **Gestión automática del mando integrado.** Es Player 1 cuando no hay externos,
  va al final cuando hay alguno y se desactiva cuando no queda hueco. La tarjeta
  **Integrado** permite fijar una elección manual.
- **Applet de mandos de Eden desactivado.** Al aplicar, N.E.C.A escribe
  `controller_applet_mode=2` y su `\default=false` para que Eden no pida
  confirmación al iniciar el juego.
- **Panel renovado.** Chips de máquina, número de mandos, versión y hook; botón
  **Mandos** con cuatro huecos; tarjeta del integrado; iconos de máquina;
  animaciones de foco; refresco automático cada 5 s.
- **Planes y registro por emulador.** `log.txt`, `plan-wiiu.txt` y
  `plan-dolphin.txt`; el panel lee los planes.
- **Backups por emulador.** Eden, Dolphin y Cemu guardan sus copias en
  `~/eden-autoconfig/backups/` con retención independiente.
- **Nuevas variables y comandos.** `INTEGRADO_MANUAL`, `CEMU_DIR`, `--sistema`,
  `--dry-run`, `--status`, `--diagnostico` para Cemu y `--restore` por sistema.

### Cambiado

- **`JUGADORES_MAX` limita el total de jugadores (1 a 4).** Ahora cuenta el
  integrado y los externos, no solo los DualSense. El botón **Mandos** muestra
  los cuatro huecos.
- **El Player 1 se calcula con el plan.** La estrella marca el jugador 1 actual;
  ya no se fija automáticamente la MAC de un único DualSense. `P1_SERIE` se usa
  cuando eliges un mando concreto con dos toques.
- **La interfaz ya no tiene `Estado` ni `Avanzado`.** El estado va en chips; las
  acciones **Aplicar**, **Restaurar** y **Ver log** viven en **Ajustes**.
- **Recargar y Asignación pasan a la cabecera de Mandos.** Ya no hay un botón de
  recargar debajo de las tarjetas.
- **El panel muestra siempre la MAC corta** de los mandos externos que la
  informan, no solo cuando hay varios del mismo tipo.
- **README bilingüe actualizado.** Los dos README explican los tres emuladores,
  la migración desde E.C.A y los límites del panel.

### Corregido

- **El integrado no ocupa un hueco inexistente.** Con el tope de jugadores lleno
  se desactiva, y el pad virtual de Steam se reconoce como integrado.
- **La applet de Eden no vuelve a pedir confirmación.** Se escribe el valor y su
  flag `\default=false`.
- **El panel detecta cambios de mandos** con un sondeo cada 5 s y refresca las
  tarjetas.
- **Cemu y Dolphin respetan `ORDEN_INTEGRADO` y `P1_SERIE`.** El integrado entra
  según el plan compartido.

### Eliminado

- **`estado.json` deja de usarse.** La preferencia manual del integrado vive en
  `INTEGRADO_MANUAL`, dentro del bloque gestionado del `.conf`.

### Seguridad

- **Sin root y con escritura acotada.** El backend corre como `deck`; el panel
  solo escribe el bloque gestionado y su estado. Los drivers escriben solo los
  ficheros de configuración de cada emulador, con backup y validación previa. El
  hook termina siempre con `exit 0`.

### Limitaciones conocidas

- **Aplicar desde el panel solo escribe Eden.** Dolphin y Cemu se aplican al
  lanzar el juego desde ES-DE o con `--sistema gc|wiiu`.
- **Restaurar desde el panel solo afecta a Eden.** Dolphin y Cemu se restauran
  con `--sistema gc --restore latest` y `--sistema wiiu --restore latest`.

## [1.0.0] - 2026-11-02

### Añadido

- **Panel de mandos en el menú rápido de Steam.** Muestra los mandos que ve Eden,
  su conexión y la MAC cuando hay varios del mismo tipo, y permite fijar el
  Player 1 sin abrir una terminal.
- **Detección por SDL.** El panel y el hook consultan la misma SDL que usa Eden,
  así que usan el guid y el puerto reales de cada mando.
- **Player 1 por MAC.** Un DualSense concreto sigue siendo el principal aunque
  Steam renumere los puertos entre sesiones.
- **Selección de DualSense y mando integrado.** Permite elegir cuántos DualSense
  usar (1 a 4) y si el integrado es Player 1, va al final o no se usa.
- **Identificación por vibración.** Un toque vibra un DualSense; dos toques
  seguidos lo fijan como principal.
- **Restaurar todo.** Devuelve el `qt-config.ini` original, quita el bloque
  gestionado y desactiva el hook de ES-DE.
- **Copias de seguridad con retención.** Conserva las 10 copias más recientes de
  `qt-config.ini` y mantiene el original aparte en `stock/`.
- **Escenario de Steam Input.** El panel muestra cuándo Eden ve pads virtuales de
  Valve.
- **Documentación en español e inglés.** README principal en español y versión
  en inglés en `README.en.md`.

### Cambiado

- **README reescrito.** Corrige requisitos y límites, enlaza el zip directo y
  añade una comprobación de instalación.

### Seguridad

- **Ejecución sin root.** El backend corre como `deck`. Una vez instalados los
  scripts, el panel solo escribe el bloque gestionado del `.conf` y su estado en
  `~/.config/eden-autoconfig-decky/`.

[Unreleased]: https://github.com/CeDiqqu/decky-neca/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/CeDiqqu/decky-neca/releases/tag/v2.0.0
[1.0.0]: https://github.com/CeDiqqu/decky-neca/releases/tag/v1.0.0
