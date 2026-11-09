# Changelog

Todos los cambios relevantes de N.E.C.A se documentan aquí. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones usan
[SemVer](https://semver.org/lang/es/).

## [Unreleased]

<!-- Al publicar: renombrar a [2.1.0] - 2026-11-09. Si la retirada de Dolphin se
     considera incompatible, usar [3.0.0]. -->

### Cambios incompatibles

- **Dolphin (GameCube/Wii) se retira temporalmente.** N.E.C.A configura solo Eden
  (Switch) y Cemu (Wii U). Si usabas Dolphin, quédate en 2.0.0 o configura sus
  mandos a mano. Los datos de `~/eden-autoconfig` (plantillas, backups y
  configuraciones) no se borran; simplemente dejan de aplicarse.

### Añadido

- **Botón Integrado de ancho completo.** El mando integrado deja de ser una
  tarjeta cuadrada: ocupa todo el ancho, muestra un icono de estado a la
  izquierda (estrella para P1, flecha para Último y prohibido para Desactivado)
  y los mandos extra se colocan debajo. Los mandos desactivados se ven en gris.
- **Cupos con el integrado.** El botón **Mandos** muestra `activos/cupo` y
  colorea los huecos hasta el último jugador activo, integrado incluido.
- **Filtros del log por emulador.** **Ver log** permite ver Todo, Eden o Cemu.
  El de Eden muestra su último bloque y el de Cemu acepta las líneas `wiiu`.
  Los bloques de `--who` del refresco se ocultan.
- **Icono ASUS + Xbox.** La ROG Xbox Ally X usa el logo ASUS junto al de Xbox en
  la tarjeta y el chip de la máquina; el resto de equipos ASUS mantienen ASUS.
- **Un solo «Aplicar».** Escribe Eden y Cemu de una vez; se elimina el botón
  suelto de Eden.
- **Log con versión, hash y avisos.** Cada aplicar registra `version=`, `hash=`,
  los `Device`/`uuid` escritos y los avisos. Si Eden o Cemu están abiertos, deja
  `en ejecucion, no aplico`.
- **Aviso de scripts recién instalados.** El panel pide cerrar el juego y
  relanzarlo, o pulsar **Aplicar**, para usar la versión nueva.

### Cambiado

- **Eden y Cemu vuelven a la lógica de 2.0.0.** Se retira la renumeración de
  puertos de los DualSense virtuales y los experimentos de Steam Input. Ambos
  emuladores aplican como en la última versión estable.
- **El integrado se puede fijar como P1 con mandos extra.** Al elegir Jugador 1,
  los DualSense corren un puesto y los que sobran quedan desactivados según el
  cupo. Sin elección manual, con 0 DualSense es P1; con DualSense pasa a Último
  o Desactivado.
- **Steam Input de ES-DE.** Para que varios DualSense mantengan el orden,
  desactívalo en ES-DE. El mando integrado sigue usando Steam Input y solo
  aparece dentro de ES-DE; el panel muestra su puesto esperado y el hook aplica
  la detección real.
- **La MAC se muestra completa.** Las tarjetas ya no recortan la MAC; si no
  cabe en una línea, salta a la siguiente.
- **Interfaz más limpia.** Se quita el aviso «Se configuran A de B mandos», los
  subtítulos de las tarjetas de Ajustes y el chip de mandos detectados. El botón
  **Mandos** ya muestra `activos/cupo`.
- **Iconos de Switch en el botón Mandos.** Los cuatro huecos usan el icono de
  Nintendo Switch.
- **Restaurar Cemu usa el último backup.** El panel deshace el último aplicar de
  Cemu con `--restore latest`; Eden vuelve a su `stock/`.

### Corregido

- **Cemu con Steam Input desactivado.** SDL3 marca el bus Bluetooth como `05` y
  Cemu (SDL2/HIDAPI) lo guarda como `03`. El `uuid` no coincidía y Cemu no
  conectaba ningún mando. El driver traduce solo ese byte y conserva el CRC
  real.
- **Sin integrado fantasma.** Si SDL no expone el mando de la consola, el plan
  ya no añade `INTEGRADO [] (port )` ni roba el P1; los DualSense empiezan en P1.
- **La estrella del P1 sigue al jugador real.** Si el integrado es Player 1,
  ningún DualSense conserva la estrella; la tarjeta del integrado la muestra.
- **El integrado virtual de Steam se reconoce.** Cuando el mando de la consola
  llega como un único `Steam Virtual Gamepad` sin número de serie, el panel lo
  promueve a Integrado igual que el driver. Si el nombre no encaja, usa el
  jugador de la línea `INTEGRADO [...]` de `--who`.
- **El integrado Último reserva su hueco.** Con cuatro DualSense y cupo 4 ocupa
  P4 y el cuarto DualSense queda desactivado; con menos mandos, ocupa el
  siguiente puesto.
- **El DualSense que queda fuera muestra «Desactivado».** No aparece como un
  jugador más.
- **La tarjeta del integrado muestra el puesto real.** Icono de estado y badge
  `P1`/`P3`/`P4`; ya no confunde el modo con el puesto asignado.
- **Las tarjetas desactivadas se ven en gris.** Fondo, icono, conexión y texto
  atenuados.
- **Animación de resaltado en los DualSense.** El icono de las tarjetas de mando
  tiene el mismo pop, brillo y escala que el del integrado al enfocar.

### Limitaciones conocidas

- **Eden asigna DualSense y el mando integrado.** Otros mandos se muestran en las
  tarjetas, pero no reciben jugador en Eden; Cemu puede usarlos si no hay
  DualSense.
- **El mando integrado de la ROG Ally X usa Steam Input.** Fuera de ES-DE no
  aparece en SDL; el panel muestra el plan esperado y el hook usa la detección
  real. Si Steam Input no lo expone al lanzar, el log muestra el plan real.
- **La asignación exacta de varios DualSense requiere Steam Input desactivado
  para ES-DE.**

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
