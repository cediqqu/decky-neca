# AGENTS.md — N.E.C.A (Nintendo-EmuDeck Controller Autoconf)

Plugin de Decky para autoconfigurar los mandos de Eden (Switch) y Cemu (Wii U)
desde el menú rápido de Steam. El proyecto de scripts vive ahora **dentro** de
esta carpeta.

**Dolphin (GameCube/Wii) se retiró temporalmente** en esta versión: no está
soportado y no debe reintroducirse sin una petición explícita.

## Estructura

```
decky-neca/               plugin (plugin.json, main.py, src/, dist/, build.sh…)
├── neca-decky.zip         zip instalable en Decky
├── scripts/              COPIA GENERADA desde eden_controller/ (no editar aquí)
└── eden_controller/      proyecto de scripts (fuente de verdad) + su AGENTS.md
```

- **`eden_controller/` funciona y no se toca** salvo petición explícita. Sus
  reglas (contrato de seguridad, hechos del dominio, verificación) están en
  `eden_controller/AGENTS.md` y siguen vigentes para esa carpeta.
- `eden_controller/test.txt` es un borrador del usuario: no borrar.

## Reglas del plugin

- **Sin flag `root`**: el backend corre como `deck`. Si corriera como root, Eden
  no podría escribir su `qt-config.ini`.
- Lo único que escribe en casa del usuario:
  1. el **bloque gestionado** al final de `~/eden-autoconfig/eden-autoconfig.conf`
     (`# >>> eden-autoconfig-decky >>>` … `# <<< eden-autoconfig-decky >>>`),
     sustituyéndolo entero y conservando el resto del fichero;
  2. su estado privado en `~/.config/eden-autoconfig-decky/`.
  Nunca toca plantillas, backups ni el `qt-config.ini` por su cuenta: eso lo
  hace el script (`aplicar`/`restaurar`).
- Los marcadores del bloque y la carpeta de estado **no se renombran** (romperían
  configuraciones ya existentes).
- **Nada de notificaciones del QAM**: los avisos se pintan dentro del panel y se
  borran solos.
- Al cargar, si los scripts instalados estan viejos o incompletos, el plugin
  ejecuta `instalar.sh` solo (no hace falta pulsar el boton).
- El zip lleva **una carpeta raíz `NecaAutoconfig/`** (Decky extrae directamente
  en `~/homebrew/plugins`). Ojo: al venir de E.C.A hay que **desinstalar el
  plugin viejo** (`EdenAutoconfig/`) para no tener dos paneles; sus datos
  (`~/eden-autoconfig`, backups y hook) no se tocan.

## Verificación antes de entregar

```bash
npx tsc --noEmit          # tipado
python3 test_backend.py   # pruebas del backend (sin Decky ni consola)
bash build.sh             # sincroniza scripts/ + compila + genera el zip
```

`python3 -m py_compile main.py` para un chequeo rápido de sintaxis.
