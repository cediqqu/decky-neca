import type { CSSProperties, ReactNode } from "react";
import {
  Focusable,
  ConfirmModal,
  DialogBody,
  DialogBodyText,
  DialogButton,
  DialogButtonPrimary,
  DialogFooter,
  GamepadButton,
  type GamepadEvent,
  ModalRoot,
  PanelSection,
  PanelSectionRow,
  showModal,
  staticClasses,
} from "@decky/ui";
import { call, definePlugin } from "@decky/api";
import { SiAsus, SiLenovo, SiMsi, SiSteamdeck } from "react-icons/si";
import { useEffect, useRef, useState } from "react";
import {
  FaBan,
  FaBluetoothB,
  FaCheck,
  FaChevronDown,
  FaChevronRight,
  FaDownload,
  FaExclamationTriangle,
  FaFileAlt,
  FaGamepad,
  FaInfoCircle,
  FaMicrochip,
  FaMinus,
  FaPlaystation,
  FaSlidersH,
  FaStar,
  FaSteam,
  FaSyncAlt,
  FaUndo,
  FaUsb,
  FaQuestion,
  FaXbox,
} from "react-icons/fa";

// ---------------------------------------------------------------------------
//  Tipos que devuelve main.py
// ---------------------------------------------------------------------------
type Mando = {
  nombre: string;
  sdl: string;
  clase: string;
  familia: string;
  conexion: string;
  guid: string;
  puerto: string;
  serie: string;
  virtual: boolean;
  gamepad: boolean;
  principal: boolean;
  es_principal: boolean;
  jugador: number | null;
};

type Prefs = {
  P1_SERIE: string;
  JUGADORES_MAX: string;
  ORDEN_INTEGRADO: string;
};

type Maquina = { vendor: string; producto: string; placa: string };

type PlanMando = { n: string; nombre: string; clase: string };

type Plan = {
  sistema: string;
  fecha: string;
  modo: string;
  max: string;
  sdl: string;
  lib: string;
  detectados: string;
  mandos: PlanMando[];
  fuera: string[];
  aviso: string[];
};

type Estado = {
  ok: boolean;
  instalado: boolean;
  ruta: string;
  base: string;
  conf: string;
  prefs: Prefs;
  mandos: Mando[];
  escenario: string;
  ds_conectados: number;
  otros_conectados: number;
  hook: boolean;
  esde: boolean | null;
  version: string;
  hash_instalado: string;
  scripts_nuevos: boolean;
  desactualizado: boolean;
  reparar: boolean;
  faltan: string[];
  planes: Record<string, Plan | null>;
  maquina: Maquina;
  aviso: string;
};

type Salida = { exit: number; salida: string; mensaje?: string };

// ---------------------------------------------------------------------------
//  Paleta (Joy-Con) y utilidades
// ---------------------------------------------------------------------------
const C = {
  azul: "#0AB9E6",
  rojo: "#FF3C28",
  verde: "#3DDC84",
  violeta: "#B47BFF",
  naranja: "#FF8A3D",
  rosa: "#FF5C8A",
  turquesa: "#2EE6C8",
  ambar: "#FFB454",
  dorado: "#F5C518",
  carbon1: "#262628",
  carbon2: "#141416",
  texto: "#EDEFF2",
  texto2: "#B8BCC2",
  gris: "#8A8F98",
};

// color de cada jugador en el boton "Mandos"
const COLOR_JUGADOR = [
  "#0AB9E6", // 1 azul
  "#3DDC84", // 2 verde
  "#B47BFF", // 3 violeta
  "#FF8A3D", // 4 naranja
];

function hexA(hex: string, alfa: number): string {
  const h = hex.replace("#", "");
  const completo =
    h.length === 3
      ? h
          .split("")
          .map((c) => c + c)
          .join("")
      : h;
  const n = parseInt(completo, 16);
  const r = (n >> 16) & 255;
  const g = (n >> 8) & 255;
  const b = n & 255;
  return `rgba(${r}, ${g}, ${b}, ${alfa})`;
}

function colorDe(m: Mando): string {
  switch (m.familia) {
    case "playstation":
      return C.azul;
    case "xbox":
      return C.verde;
    case "switch":
      return C.rojo;
    case "steam":
      return C.violeta;
    default:
      return C.gris;
  }
}

function IconoFamilia(props: { familia: string; size: number }) {
  switch (props.familia) {
    case "playstation":
      return <FaPlaystation size={props.size} />;
    case "xbox":
      return <FaXbox size={props.size} />;
    case "steam":
      return <FaSteam size={props.size} />;
    case "switch":
    case "integrado":
      return <FaGamepad size={props.size} />;
    default:
      return <FaQuestion size={props.size} />;
  }
}

function colorConexion(conexion: string): string {
  if (conexion.startsWith("Bluetooth")) return C.azul;
  if (conexion === "USB") return C.verde;
  if (conexion.startsWith("Virtual")) return C.violeta;
  return C.gris;
}

function macCorta(serie: string): string {
  const partes = (serie || "").split(":");
  if (partes.length >= 2) {
    return `…${partes[partes.length - 2]}:${partes[partes.length - 1]}`;
  }
  return serie;
}

const ESTILOS = `
@keyframes ede-latido {
  0%, 100% { opacity: .88; transform: scale(1); }
  50% { opacity: 1; transform: scale(1.15); }
}
@keyframes ede-aparecer {
  from { opacity: 0; transform: translateY(-2px); }
  to   { opacity: 1; transform: none; }
}
.ede-estrella { animation: ede-latido 2.6s ease-in-out infinite; }
/* el boton no pinta nada: solo se ve la tarjeta de dentro */
.ede-boton, .ede-cab {
  padding: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  border-radius: 16px !important;
  width: 100%;
}
/* foco: solo el borde (sin fondo blanco de Steam) */
.ede-foco-cab {
  border-radius: 10px !important;
  box-shadow: 0 0 0 1px var(--ede-acento, #0AB9E6),
              0 0 10px var(--ede-acento-halo, rgba(10,185,230,0.45)) !important;
}
/* --- tarjetas: foco y micro-animaciones (estilo PdC) --- */
.ede-tarjeta { transition: box-shadow 140ms ease, transform 140ms ease, border-color 140ms ease; }
.ede-foco .ede-tarjeta,
.ede-panel .gpfocus .ede-tarjeta,
.ede-celda:hover .ede-tarjeta {
  border-color: var(--ede-acento, #0AB9E6) !important;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.22),
              0 0 0 2px var(--ede-acento, #0AB9E6),
              0 0 14px var(--ede-acento-halo, rgba(10,185,230,0.45)) !important;
  transform: scale(1.02);
}
.ede-icono-tile { display: inline-flex; transition: transform 160ms ease, filter 160ms ease; }
.ede-foco .ede-icono-tile,
.ede-panel .gpfocus .ede-icono-tile { transform: scale(1.08); filter: brightness(1.12); }
.ede-icono-caja { display: inline-flex; align-items: center; justify-content: center; transition: box-shadow 160ms ease; }
.ede-foco .ede-icono-caja,
.ede-panel .gpfocus .ede-icono-caja { box-shadow: 0 0 12px var(--ede-glow, rgba(10,185,230,0.55)); }
.ede-foco .ede-anim-pop,
.ede-panel .gpfocus .ede-anim-pop { animation: ede-icono-pop 420ms cubic-bezier(.2,.8,.2,1) both; }
.ede-foco .ede-anim-giro,
.ede-panel .gpfocus .ede-anim-giro { animation: ede-icono-giro 480ms ease-out both; }
.ede-foco .ede-anim-latido,
.ede-panel .gpfocus .ede-anim-latido { animation: ede-icono-latido 460ms ease-out both; }
.ede-foco .ede-anim-barrido,
.ede-panel .gpfocus .ede-anim-barrido { animation: ede-icono-barrido 380ms ease-out both; }
@keyframes ede-icono-pop { 0% { transform: scale(.82); } 60% { transform: scale(1.14); } 100% { transform: scale(1); } }
@keyframes ede-icono-giro { 0% { transform: rotate(-30deg); } 70% { transform: rotate(5deg); } 100% { transform: rotate(0); } }
@keyframes ede-icono-latido { 0% { transform: scale(.9); opacity: .7; } 55% { transform: scale(1.12); opacity: 1; } 100% { transform: scale(1); } }
@keyframes ede-icono-barrido { 0% { transform: translateY(3px); opacity: .5; } 100% { transform: translateY(0); opacity: 1; } }
/* boton pequeno de accion en la cabecera */
.ede-icono-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: rgba(255,255,255,0.06);
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.10);
  color: rgba(255,255,255,0.72);
  transition: box-shadow 140ms ease, color 140ms ease;
}
.ede-icono-btn-foco {
  color: #ffffff;
  box-shadow: inset 0 0 0 1px var(--ede-acento, #0AB9E6),
              0 0 9px var(--ede-acento-halo, rgba(10,185,230,0.45));
}
/* iconos de jugador del boton "Mandos" */
.ede-slot { display: inline-flex; transition: color 180ms ease, opacity 180ms ease, filter 180ms ease; }
.ede-slot.off { color: rgba(255,255,255,0.20); }
.ede-slot.on { filter: drop-shadow(0 0 5px currentColor); }
.ede-slot.pulso { animation: ede-slot-vibra 480ms ease-in-out; }
@keyframes ede-slot-vibra {
  0%, 100% { transform: translateX(0) rotate(0); }
  15% { transform: translateX(-2px) rotate(-8deg); }
  30% { transform: translateX(2px) rotate(8deg); }
  45% { transform: translateX(-2px) rotate(-6deg); }
  60% { transform: translateX(2px) rotate(6deg); }
  75% { transform: translateX(-1px) rotate(-3deg); }
}
@media (prefers-reduced-motion: reduce) {
  .ede-slot.pulso { animation: none; }
  .ede-tarjeta, .ede-icono-tile, .ede-icono-caja { transition: none; }
  .ede-foco .ede-tarjeta,
  .ede-panel .gpfocus .ede-tarjeta { transform: none; }
  .ede-foco .ede-icono-tile,
  .ede-foco .ede-anim-pop,
  .ede-foco .ede-anim-giro,
  .ede-foco .ede-anim-latido,
  .ede-foco .ede-anim-barrido,
  .ede-panel .gpfocus .ede-icono-tile,
  .ede-panel .gpfocus .ede-anim-pop,
  .ede-panel .gpfocus .ede-anim-giro,
  .ede-panel .gpfocus .ede-anim-latido,
  .ede-panel .gpfocus .ede-anim-barrido { animation: none; transform: none; }
}
.ede-aparecer { animation: ede-aparecer 150ms ease-out; }
@media (prefers-reduced-motion: reduce) {
  .ede-estrella, .ede-aparecer { animation: none; }
}
`;

// ---------------------------------------------------------------------------
//  Piezas visuales
// ---------------------------------------------------------------------------
/** Icono dentro de un circulo (estilo ajustes de Switch). */
function CirculoIcono(props: {
  children: ReactNode;
  color: string;
  lado?: number;
}) {
  const lado = props.lado ?? 26;
  return (
    <span
      style={{
        width: `${lado}px`,
        height: `${lado}px`,
        borderRadius: "50%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flex: "0 0 auto",
        background: hexA(props.color, 0.18),
        border: `1px solid ${hexA(props.color, 0.45)}`,
        color: props.color,
      }}
    >
      {props.children}
    </span>
  );
}

/** Tarjeta de aviso (icono a la izquierda), como las notificaciones de Switch. */
function Aviso(props: {
  children: ReactNode;
  tono?: "info" | "atencion";
  onClick?: () => void;
}) {
  const color = props.tono === "atencion" ? C.rojo : C.azul;
  return (
    <div
      onClick={props.onClick}
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: "10px",
        padding: "9px 12px",
        borderRadius: "14px",
        border: "1px solid rgba(128,128,128,0.22)",
        background:
          "linear-gradient(120deg, rgba(22,22,24,0.92), rgba(30,30,33,0.78))",
        color: C.texto,
        fontSize: "0.78em",
        lineHeight: 1.4,
        whiteSpace: "pre-wrap",
      }}
    >
      <CirculoIcono color={color} lado={26}>
        {props.tono === "atencion" ? (
          <FaExclamationTriangle size={11} />
        ) : (
          <FaInfoCircle size={11} />
        )}
      </CirculoIcono>
      <div style={{ minWidth: 0 }}>{props.children}</div>
    </div>
  );
}

/** Glifo circular tipo prompt de Switch. */
function GlifoA() {
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        width: "15px",
        height: "15px",
        borderRadius: "50%",
        background: "#fff",
        color: "#1a1a1a",
        fontSize: "0.62em",
        fontWeight: 800,
        lineHeight: 1,
        flex: "0 0 auto",
      }}
    >
      A
    </span>
  );
}


function IconoConexion(props: { conexion: string; size?: number }) {
  const s = props.size ?? 9;
  if (props.conexion.startsWith("Bluetooth")) return <FaBluetoothB size={s} />;
  if (props.conexion === "USB") return <FaUsb size={s} />;
  if (props.conexion.startsWith("Virtual")) return <FaSteam size={s} />;
  return <FaMicrochip size={s} />;
}

function IconoTile(props: { m: Mando; lado: number }) {
  const color = colorDe(props.m);
  return (
    <div
      style={{
        width: `${props.lado}px`,
        height: `${props.lado}px`,
        borderRadius: "9px",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flex: "0 0 auto",
        background: `linear-gradient(145deg, ${hexA(color, 0.35)}, ${hexA(color, 0.06)})`,
        border: `1px solid ${hexA(color, 0.5)}`,
        boxShadow: `inset 0 0 10px ${hexA(color, 0.15)}`,
        color,
      }}
    >
      <IconoFamilia familia={props.m.familia} size={props.lado * 0.55} />
    </div>
  );
}

function estiloBadge(color: string): CSSProperties {
  return {
    position: "absolute",
    top: "5px",
    right: "5px",
    minWidth: "18px",
    height: "18px",
    padding: "0 4px",
    borderRadius: "999px",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: "0.64em",
    fontWeight: 800,
    lineHeight: 1,
    color,
    background: "rgba(0,0,0,0.55)",
    border: `1px solid ${hexA(color, 0.7)}`,
    boxShadow: `0 0 7px ${hexA(color, 0.35)}`,
    boxSizing: "border-box",
  };
}

/** Arriba a la derecha: estrella si es el principal; si no, su jugador. */
function Badge(props: { m: Mando }) {
  const { m } = props;

  if (m.es_principal) {
    return (
      <FaStar
        className="ede-estrella"
        style={{
          position: "absolute",
          top: "4px",
          right: "6px",
          color: C.dorado,
          fontSize: "0.88em",
          filter: `drop-shadow(0 0 4px ${hexA(C.dorado, 0.9)})`,
        }}
      />
    );
  }

  if (m.jugador) {
    return <div style={estiloBadge(C.azul)}>{m.jugador}</div>;
  }

  return (
    <div style={{ ...estiloBadge(C.gris), width: "18px", padding: 0 }}>
      {m.clase === "Integrado" ? <FaBan size={8} /> : <FaMinus size={8} />}
    </div>
  );
}

function estiloTarjeta(color: string): CSSProperties {
  return {
    position: "relative",
    borderRadius: "16px",
    boxSizing: "border-box",
    overflow: "hidden",
    color: C.texto,
    border: "1px solid rgba(255,255,255,0.10)",
    background:
      `radial-gradient(130% 100% at 100% 0%, ${hexA(color, 0.14)}, transparent 62%), ` +
      `linear-gradient(155deg, ${C.carbon1}, ${C.carbon2})`,
    boxShadow: "0 1px 3px rgba(0,0,0,0.45)",
    transition: "border-color 180ms ease, box-shadow 180ms ease",
  };
}

// --- tarjeta cuadrada (2 o mas mandos) -------------------------------------
function MandoCuadrado(props: {
  m: Mando;
  mostrarMac: boolean;
  destello: boolean;
  onClick: () => void;
}) {
  const { m, mostrarMac, destello, onClick } = props;
  const color = colorDe(m);
  return (
    <BotonTarjeta onClick={onClick}>
      <div
        className="ede-tarjeta"
        style={{
          ...estiloTarjeta(color),
          ...(destello
            ? {
                border: `1px solid ${C.azul}`,
                boxShadow: `0 0 16px ${hexA(C.azul, 0.6)}`,
              }
            : null),
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          minHeight: "96px",
          width: "100%",
          padding: 0,
          textAlign: "center",
        }}
      >
        <Badge m={m} />
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            gap: "3px",
            flex: 1,
            padding: "10px 5px 5px",
          }}
        >
          <IconoTile m={m} lado={34} />
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "3px",
              fontSize: "0.6em",
              color: colorConexion(m.conexion),
            }}
          >
            <IconoConexion conexion={m.conexion} size={8} />
            {m.conexion}
          </div>
          {!m.jugador ? (
            <div
              style={{
                fontSize: "0.55em",
                color: C.gris,
                opacity: 0.85,
                lineHeight: 1,
              }}
            >
              Desactivado
            </div>
          ) : null}
          {mostrarMac && m.serie ? (
            <div
              style={{
                fontSize: "0.53em",
                color: C.texto2,
                opacity: 0.5,
                lineHeight: 1,
              }}
            >
              {macCorta(m.serie)}
            </div>
          ) : null}
        </div>
        {m.familia === "desconocido" ? (
          <div
            style={{
              padding: "3px 5px",
              background: "rgba(0,0,0,0.38)",
              borderTop: `1px solid ${hexA(color, 0.3)}`,
              fontSize: "0.64em",
              fontWeight: 700,
              lineHeight: 1.2,
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {m.sdl || m.nombre || m.clase}
          </div>
        ) : null}
      </div>
    </BotonTarjeta>
  );
}

// Envoltorio comun: un Focusable sin nada de Steam (sin fondo ni anillo) y
// dentro la tarjeta. Asi todos los botones se ven igual y el foco es el borde.
function BotonTarjeta(props: { onClick: () => void; children: ReactNode }) {
  return (
    <Focusable
      className="ede-boton"
      focusClassName="ede-foco"
      noFocusRing
      onActivate={props.onClick}
      onClick={props.onClick}
      style={{ width: "100%", padding: 0, background: "transparent" }}
    >
      {props.children}
    </Focusable>
  );
}

function TarjetaBase(props: {
  icono: ReactNode;
  titulo: string;
  detalle?: string;
  color?: string;
  anim?: AnimIcono;
  flecha?: boolean;
  onClick: () => void;
}) {
  const color = props.color ?? C.azul;
  return (
    <BotonTarjeta onClick={props.onClick}>
      <div
        className="ede-tarjeta"
        style={{
          ...estiloTarjeta(color),
          display: "flex",
          alignItems: "center",
          gap: "11px",
          width: "100%",
          padding: "11px 12px",
          textAlign: "left",
        }}
      >
        <IconoTarjeta icono={props.icono} color={color} anim={props.anim} />
        <div style={{ minWidth: 0, flex: 1 }}>
          <div style={{ fontSize: "0.8em", fontWeight: 700, lineHeight: 1.2 }}>
            {props.titulo}
          </div>
          {props.detalle ? (
            <div style={{ fontSize: "0.68em", opacity: 0.7, lineHeight: 1.2 }}>
              {props.detalle}
            </div>
          ) : null}
        </div>
        {props.flecha ? (
          <span style={{ opacity: 0.45, display: "flex", flex: "0 0 auto" }}>
            <FaChevronRight size={11} />
          </span>
        ) : null}
      </div>
    </BotonTarjeta>
  );
}

function BotonAccion(props: {
  icono: ReactNode;
  texto: string;
  color?: string;
  onClick: () => void;
}) {
  return (
    <TarjetaBase
      icono={props.icono}
      titulo={props.texto}
      color={props.color}
      anim="pop"
      onClick={props.onClick}
    />
  );
}

// --- icono de la maquina integrada -----------------------------------------
function IconoPortatil(props: { size?: number }) {
  const lado = props.size ?? 17;
  return (
    <svg
      width={lado}
      height={lado}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M7 3h10a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4h-1.5a2 2 0 0 1-1.7-.9l-.8-1.2a1.2 1.2 0 0 0-2 0l-.8 1.2a2 2 0 0 1-1.7.9H7a4 4 0 0 1-4-4V7a4 4 0 0 1 4-4Zm0 1.8A2.2 2.2 0 0 0 4.8 7v10A2.2 2.2 0 0 0 7 19.2h.8l.8-1.2a3 3 0 0 1 4.8 0l.8 1.2H17a2.2 2.2 0 0 0 2.2-2.2V7A2.2 2.2 0 0 0 17 4.8H7Z" />
      <rect x="6.6" y="6.4" width="10.8" height="6.8" rx="1.2" />
      <circle cx="8.1" cy="16.3" r="1.05" />
      <circle cx="15.9" cy="16.3" r="1.05" />
    </svg>
  );
}

function textoMaquina(m: Maquina | null | undefined, nombre: string): string {
  return `${m?.vendor ?? ""} ${m?.producto ?? ""} ${m?.placa ?? ""} ${nombre}`.toLowerCase();
}

// "ROG Ally RC71L_RC71L" -> "ROG Ally"; "ROG Ally X RC72LA_RC72LA" -> "ROG Ally X"
function limpiarModelo(producto: string): string {
  return (producto || "")
    .replace(/\s+[A-Z0-9][A-Z0-9_-]{4,}$/, "")
    .trim();
}

function nombreMaquina(m: Maquina | null | undefined): string {
  if (!m) return "";
  const t = textoMaquina(m, "");
  if (
    t.includes("valve") ||
    t.includes("jupiter") ||
    t.includes("galileo") ||
    t.includes("steam deck")
  ) {
    return "Steam Deck";
  }
  if (t.includes("asustek") || t.includes("asus")) {
    return limpiarModelo(m.producto) || limpiarModelo(m.placa) || "ROG Ally";
  }
  if (t.includes("micro-star") || t.includes("msi")) {
    return limpiarModelo(m.producto) || limpiarModelo(m.placa) || "MSI Claw";
  }
  if (t.includes("lenovo") || t.includes("legion")) {
    // Lenovo suele traer un codigo en product_name ("83E1"): mejor la placa.
    return limpiarModelo(m.placa) || limpiarModelo(m.producto) || "Legion Go";
  }
  return limpiarModelo(m.producto) || limpiarModelo(m.placa);
}

function IconoMaquina(props: {
  maquina?: Maquina | null;
  nombre: string;
  size?: number;
}) {
  const t = textoMaquina(props.maquina, props.nombre);
  const lado = props.size ?? 17;
  if (
    t.includes("valve") ||
    t.includes("jupiter") ||
    t.includes("galileo") ||
    t.includes("steam deck") ||
    t.includes("deck controller")
  ) {
    return <SiSteamdeck size={lado} />;
  }
  if (
    t.includes("asustek") ||
    t.includes("asus") ||
    t.includes("rog") ||
    t.includes("ally")
  ) {
    return <SiAsus size={lado} />;
  }
  if (t.includes("micro-star") || t.includes("msi") || t.includes("claw")) {
    return <SiMsi size={lado} />;
  }
  if (t.includes("lenovo") || t.includes("legion")) {
    return <SiLenovo size={lado} />;
  }
  if (t.includes("xbox")) return <FaXbox size={lado} />;
  return <IconoPortatil size={lado} />;
}

// --- boton de icono pequeno (acciones de cabecera) -------------------------
function BotonIcono(props: {
  icono: ReactNode;
  titulo: string;
  onClick: () => void;
}) {
  return (
    <Focusable
      className="ede-icono-btn"
      focusClassName="ede-icono-btn-foco"
      noFocusRing
      onActivate={props.onClick}
      onClick={props.onClick}
      aria-label={props.titulo}
    >
      {props.icono}
    </Focusable>
  );
}

// --- chip de estado (mismo diseno que el del dispositivo) ------------------
function ChipEstado(props: { icono: ReactNode; texto: string; color: string }) {
  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "6px",
        minHeight: "24px",
        maxWidth: "100%",
        padding: "3px 9px",
        borderRadius: "999px",
        background: "rgba(255,255,255,0.04)",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.10)",
        boxSizing: "border-box",
      }}
    >
      <span style={{ display: "flex", flex: "0 0 auto", color: props.color }}>
        {props.icono}
      </span>
      <span
        style={{
          fontSize: "0.72em",
          fontWeight: 650,
          whiteSpace: "nowrap",
          overflow: "hidden",
          textOverflow: "ellipsis",
        }}
      >
        {props.texto}
      </span>
    </div>
  );
}

// --- tarjeta del mando integrado -------------------------------------------
function TarjetaIntegrado(props: {
  icono: ReactNode;
  jugador: number | null;
  modo: string;
  detectado: boolean;
  onClick: () => void;
}) {
  const detalle =
    props.modo === "ignorar" || (props.detectado && !props.jugador)
      ? "Desactivado"
      : props.modo === "primero"
        ? "Jugador 1"
        : "Último jugador";
  return (
    <TarjetaAccion
      color={C.naranja}
      icono={props.icono}
      anim="pop"
      titulo="Integrado"
      detalle={detalle}
      onClick={props.onClick}
    />
  );
}

// --- tarjeta de accion (cuadrada, como las de los mandos) ------------------
type AnimIcono = "pop" | "giro" | "latido" | "barrido";

function IconoTarjeta(props: {
  icono: ReactNode;
  color: string;
  anim?: AnimIcono;
}) {
  return (
    <span className="ede-icono-tile">
      <span className={`ede-anim-${props.anim ?? "pop"}`}>
        <span
          className="ede-icono-caja"
          style={
            {
              width: "36px",
              height: "36px",
              borderRadius: "11px",
              background: props.color,
              color: "#ffffff",
              flex: "0 0 auto",
              "--ede-glow": hexA(props.color, 0.6),
            } as CSSProperties
          }
        >
          {props.icono}
        </span>
      </span>
    </span>
  );
}

function TarjetaAccion(props: {
  icono: ReactNode;
  titulo: string;
  detalle?: string;
  color?: string;
  anim?: AnimIcono;
  onClick: () => void;
}) {
  const color = props.color ?? C.azul;
  return (
    <BotonTarjeta onClick={props.onClick}>
      <div
        className="ede-tarjeta"
        style={{
          ...estiloTarjeta(color),
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          minHeight: "96px",
          width: "100%",
          padding: 0,
          textAlign: "center",
        }}
      >
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            gap: "6px",
            padding: "10px 6px",
            width: "100%",
          }}
        >
          <IconoTarjeta icono={props.icono} color={color} anim={props.anim} />
          <div style={{ fontSize: "0.7em", fontWeight: 700, lineHeight: 1.15 }}>
            {props.titulo}
          </div>
          {props.detalle ? (
            <div style={{ fontSize: "0.62em", opacity: 0.7, lineHeight: 1.15 }}>
              {props.detalle}
            </div>
          ) : null}
        </div>
      </div>
    </BotonTarjeta>
  );
}

// --- rejilla de 2 columnas -------------------------------------------------
function Rejilla(props: { children: ReactNode }) {
  return (
    <PanelSectionRow>
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
          gap: "6px",
          width: "100%",
        }}
      >
        {props.children}
      </div>
    </PanelSectionRow>
  );
}

// --- seccion colapsable ----------------------------------------------------
function Seccion(props: {
  titulo: string;
  icono: ReactNode;
  color?: string;
  resumen?: string;
  accion?: ReactNode;
  abierta: boolean;
  onToggle?: () => void;
  children: ReactNode;
}) {
  const cabecera = (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: "9px",
        width: "100%",
      }}
    >
      <CirculoIcono color={props.color ?? C.azul} lado={26}>
        {props.icono}
      </CirculoIcono>
      <span style={{ fontWeight: 700 }}>{props.titulo}</span>
      {props.resumen ? (
        <span
          style={{
            marginLeft: "auto",
            fontSize: "0.7em",
            opacity: 0.55,
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {props.resumen}
        </span>
      ) : null}
      {props.accion ? (
        <span
          style={{
            marginLeft: props.resumen ? "6px" : "auto",
            display: "flex",
            flex: "0 0 auto",
          }}
        >
          {props.accion}
        </span>
      ) : null}
      {props.onToggle ? (
        <span
          style={{
            marginLeft: props.resumen || props.accion ? "6px" : "auto",
            opacity: 0.6,
            display: "flex",
            flex: "0 0 auto",
          }}
        >
          {props.abierta ? <FaChevronDown size={10} /> : <FaChevronRight size={10} />}
        </span>
      ) : null}
    </div>
  );

  return (
    <PanelSection>
      <PanelSectionRow>
        {props.onToggle ? (
          <Focusable
            className="ede-cab"
            focusClassName="ede-foco-cab"
            noFocusRing
            onActivate={props.onToggle}
            onClick={props.onToggle}
            style={{ width: "100%", padding: 0, background: "transparent" }}
          >
            {cabecera}
          </Focusable>
        ) : (
          cabecera
        )}
      </PanelSectionRow>
      <div
        style={{
          height: "1px",
          background: "rgba(128,128,128,0.16)",
          margin: "0 6px 6px",
        }}
      />
      {props.abierta ? (
        <div className="ede-aparecer">{props.children}</div>
      ) : null}
    </PanelSection>
  );
}

// ---------------------------------------------------------------------------
//  Ventana emergente de texto (con scroll: D-pad, stick o dedo)
// ---------------------------------------------------------------------------
function VentanaTexto(props: {
  titulo: string;
  texto: string;
  onCerrar: () => void;
}) {
  const texto = (props.texto || "").replace(/\s+$/, "");
  const ref = useRef<HTMLDivElement>(null);

  // Scroll con D-pad/stick. El texto no tiene hijos enfocables, asi que
  // ScrollPanel no se movia; movemos scrollTop a mano.
  const mover = (evt: GamepadEvent) => {
    const boton = evt.detail?.button;
    const el = ref.current;
    if (!el) return;
    const paso = Math.max(40, Math.floor(el.clientHeight * 0.8));
    if (boton === GamepadButton.DIR_UP) {
      if (el.scrollTop > 0) {
        el.scrollTop -= paso;
        evt.stopPropagation();
      }
    } else if (boton === GamepadButton.DIR_DOWN) {
      if (el.scrollTop + el.clientHeight < el.scrollHeight - 1) {
        el.scrollTop += paso;
        evt.stopPropagation();
      }
    }
  };

  return (
    <ModalRoot strTitle={props.titulo} bAllowFullSize onCancel={props.onCerrar}>
      <DialogBody
        style={{
          height: "58vh",
          maxHeight: "58vh",
          padding: 0,
          overflow: "hidden",
          display: "flex",
          flexDirection: "column",
        }}
      >
        <Focusable
          preferredFocus
          onGamepadDirection={mover}
          style={{ flex: 1, minHeight: 0, display: "flex", flexDirection: "column" }}
        >
          <div
            ref={ref}
            style={{
              flex: 1,
              minHeight: 0,
              overflowY: "auto",
              padding: "12px 16px 16px",
              fontFamily: "monospace",
              fontSize: "0.85em",
              lineHeight: 1.35,
              whiteSpace: "pre-wrap",
              wordBreak: "break-word",
            }}
          >
            {texto || "(vacio)"}
          </div>
        </Focusable>
      </DialogBody>
      <DialogFooter>
        <DialogButtonPrimary onClick={props.onCerrar}>Cerrar</DialogButtonPrimary>
      </DialogFooter>
    </ModalRoot>
  );
}

function abrirVentana(titulo: string, texto: string) {
  const cierre = { f: () => {} };
  const res = showModal(
    <VentanaTexto titulo={titulo} texto={texto} onCerrar={() => cierre.f()} />
  );
  cierre.f = res.Close;
}

// ---------------------------------------------------------------------------
//  Ventana de asignacion (Cemu / Dolphin)
// ---------------------------------------------------------------------------
function VentanaAsignacion(props: {
  planes: Record<string, Plan | null>;
  onCerrar: () => void;
  onNuevo: (e: Estado) => void;
}) {
  const [planes, setPlanes] = useState(props.planes);
  const [ocupado, setOcupado] = useState(false);
  const [nota, setNota] = useState("");

  const comprobar = async () => {
    if (ocupado) return;
    setOcupado(true);
    setNota("Comprobando…");
    try {
      const nuevo = await call<[], Estado>("comprobar");
      setPlanes(nuevo.planes);
      props.onNuevo(nuevo);
      setNota(nuevo.aviso || "Plan recalculado");
    } catch (err) {
      setNota(String(err));
    } finally {
      setOcupado(false);
    }
  };

  const bloque = (clave: "wiiu" | "dolphin", etiqueta: string) => {
    const pl = planes?.[clave];
    return (
      <div key={clave} style={{ marginBottom: "12px" }}>
        <div style={{ fontWeight: 700 }}>{etiqueta}</div>
        {pl ? (
          <>
            <div style={{ opacity: 0.6, fontSize: "0.85em" }}>
              {pl.modo} · {pl.fecha} · máximo {pl.max} ·{" "}
              {pl.sdl === "ok" ? "SDL ok" : "SDL error"}
            </div>
            {pl.mandos.length === 0 ? (
              <div style={{ color: C.dorado }}>Ningún mando asignado.</div>
            ) : (
              pl.mandos.map((m) => (
                <div key={m.n}>
                  <span style={{ color: C.azul, fontWeight: 700 }}>M{m.n}</span>{" "}
                  {m.nombre}{" "}
                  <span style={{ opacity: 0.5 }}>[{m.clase}]</span>
                </div>
              ))
            )}
            {pl.fuera.map((f) => (
              <div key={f} style={{ color: C.gris, fontSize: "0.92em" }}>
                fuera: {f.replace("|", ": ")}
              </div>
            ))}
            {pl.aviso.map((a) => (
              <div key={a} style={{ color: C.dorado, fontSize: "0.92em" }}>
                {a}
              </div>
            ))}
          </>
        ) : (
          <div style={{ opacity: 0.6 }}>
            Sin datos todavía. Pulsa «Comprobar ahora».
          </div>
        )}
      </div>
    );
  };

  return (
    <ModalRoot strTitle="Asignación" bAllowFullSize onCancel={props.onCerrar}>
      <DialogBody>
        <DialogBodyText>
          <div
            style={{
              maxHeight: "45vh",
              overflowY: "auto",
              fontSize: "0.9em",
              lineHeight: 1.4,
            }}
          >
            {bloque("wiiu", "Cemu (Wii U)")}
            {bloque("dolphin", "Dolphin (GC/Wii)")}
            {nota ? (
              <div style={{ marginTop: "6px", opacity: 0.75, fontSize: "0.9em" }}>
                {nota}
              </div>
            ) : null}
          </div>
        </DialogBodyText>
      </DialogBody>
      <DialogFooter>
        <DialogButton disabled={ocupado} onClick={() => void comprobar()}>
          {ocupado ? "Comprobando…" : "Comprobar ahora"}
        </DialogButton>
        <DialogButtonPrimary onClick={props.onCerrar}>Cerrar</DialogButtonPrimary>
      </DialogFooter>
    </ModalRoot>
  );
}

function abrirAsignacion(
  planes: Record<string, Plan | null>,
  onNuevo: (e: Estado) => void
) {
  const cierre = { f: () => {} };
  const res = showModal(
    <VentanaAsignacion
      planes={planes}
      onCerrar={() => cierre.f()}
      onNuevo={onNuevo}
    />
  );
  cierre.f = res.Close;
}

// ---------------------------------------------------------------------------
//  Panel
// ---------------------------------------------------------------------------
function Content() {
  const [est, setEst] = useState<Estado | null>(null);
  const [ocupado, setOcupado] = useState(false);
  const [abiertas, setAbiertas] = useState<Record<string, boolean>>({});
  const [aviso, setAviso] = useState("");
  const temporizador = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [destello, setDestello] = useState<string | null>(null);
  const [pulsoMando, setPulsoMando] = useState(0);
  const ultimoN = useRef<number>(-1);
  const [ultimo, setUltimo] = useState<Record<string, number>>({});

  const toggle = (id: string) =>
    setAbiertas((prev) => ({ ...prev, [id]: !prev[id] }));

  // avisos pasajeros: se pintan dentro del panel y se borran solos
  const avisar = (mensaje: string) => {
    setAviso(mensaje);
    if (temporizador.current) clearTimeout(temporizador.current);
    temporizador.current = setTimeout(() => setAviso(""), 5000);
  };

  const limpiarAviso = () => {
    if (temporizador.current) clearTimeout(temporizador.current);
    setAviso("");
  };

  const refrescar = async () => {
    try {
      const nuevo = await call<[], Estado>("estado");
      setEst(nuevo);
      ultimoN.current = nuevo.mandos.length;
      if (nuevo.aviso) avisar(nuevo.aviso);
    } catch (e) {
      abrirVentana("Error", String(e));
    }
  };

  useEffect(() => {
    void refrescar();
  }, []);

  // cada pocos segundos miramos si han conectado/desconectado mandos
  useEffect(() => {
    const id = setInterval(() => {
      void (async () => {
        try {
          const n = await call<[], number>("contar");
          if (n < 0) return;
          if (ultimoN.current >= 0 && n !== ultimoN.current) {
            const nuevo = await call<[], Estado>("estado");
            setEst(nuevo);
            ultimoN.current = nuevo.mandos.length;
          } else {
            ultimoN.current = n;
          }
        } catch {
          /* silencio: es un sondeo */
        }
      })();
    }, 5000);
    return () => clearInterval(id);
  }, []);

  const conBloqueo = async (fn: () => Promise<void>) => {
    if (ocupado) return;
    setOcupado(true);
    try {
      await fn();
    } catch (e) {
      abrirVentana("Error", String(e));
    } finally {
      setOcupado(false);
    }
  };

  const TOCAR_MS = 1500;

  const vibrar = (m: Mando) => {
    void call<[string, string], { ok: boolean; salida: string }>(
      "vibrar",
      m.serie,
      m.puerto
    )
      .then((r) => {
        if (r.ok) return;
        if (r.salida.includes("\n")) abrirVentana("No se pudo vibrar", r.salida);
        else avisar(r.salida);
      })
      .catch(() => {});
    setDestello(m.serie);
    setTimeout(() => setDestello((d) => (d === m.serie ? null : d)), 420);
  };

  const tocarMando = (m: Mando) =>
    conBloqueo(async () => {
      if (m.clase === "Integrado") {
        avisar(
          "El mando integrado no vibra ni se fija por serie: se pone como Player 1 " +
            "con el ajuste «Mando integrado»."
        );
        return;
      }
      if (!m.serie) {
        avisar(
          `"${m.sdl || m.nombre}" no informa de su serie, asi que no puedo dirigirme a el.`
        );
        return;
      }

      vibrar(m);

      const ahora = Date.now();
      const anterior = ultimo[m.serie] ?? 0;
      const doble = ahora - anterior < TOCAR_MS;
      setUltimo((u) => ({ ...u, [m.serie]: ahora }));

      if (m.es_principal) {
        avisar("Este ya es el principal.");
        return;
      }
      if (est && est.ds_conectados <= 1) {
        avisar("Con un solo mando conectado, ya es el principal.");
        return;
      }
      if (!doble) {
        avisar("Pulsa otra vez para hacerlo principal.");
        return;
      }

      const nuevo = await call<[string], Estado>("alternar_principal", m.serie);
      setEst(nuevo);
      if (nuevo.aviso) {
        avisar(nuevo.aviso);
      } else {
        const p = nuevo.mandos.find((x) => x.serie === m.serie);
        setUltimo((u) => ({ ...u, [m.serie]: 0 }));
        avisar(`${p?.sdl || p?.nombre || "Mando"} es ahora el principal`);
      }
    });

  const cambiarJugadores = () =>
    conBloqueo(async () => {
      const nuevo = await call<[string], Estado>("ciclar", "max");
      setEst(nuevo);
      if (nuevo.aviso) avisar(nuevo.aviso);
      const n = Number(nuevo.prefs.JUGADORES_MAX);
      setPulsoMando(n);
      setTimeout(() => setPulsoMando(0), 520);
    });

  const elegirIntegrado = (modo: string) =>
    conBloqueo(async () => {
      const nuevo = await call<[string], Estado>("integrado_modo", modo);
      setEst(nuevo);
      if (nuevo.aviso) avisar(nuevo.aviso);
    });

  // la tarjeta cicla: Jugador 1 -> Ultimo jugador -> Apagado
  const siguienteIntegrado = () => {
    const orden = ["primero", "ultimo", "ignorar"];
    const i = orden.indexOf(p.ORDEN_INTEGRADO);
    return orden[(i + 1) % orden.length];
  };

  const aplicar = () =>
    conBloqueo(async () => {
      const r = await call<[], Salida>("aplicar");
      abrirVentana(`Aplicar: ${r.mensaje ?? "salida " + r.exit}`, r.salida);
      await refrescar();
    });

  const aplicarTodo = () =>
    conBloqueo(async () => {
      const r = await call<[], Salida & { ok: boolean }>("aplicar_todo");
      abrirVentana(
        r.ok ? "Aplicar todo: hecho" : "Aplicar todo: con problemas",
        r.salida
      );
      await refrescar();
    });

  const verLog = () =>
    conBloqueo(async () => {
      const r = await call<[], { salida: string }>("ver_log");
      abrirVentana("Log (log.txt)", r.salida);
    });

  const instalar = () =>
    conBloqueo(async () => {
      const r = await call<
        [],
        { ok: boolean; exit: number; salida: string }
      >("instalar_scripts");
      abrirVentana(
        r.ok ? "Scripts instalados" : `Error instalando (${r.exit})`,
        r.salida
      );
      await refrescar();
    });

  const restaurarTodo = () => {
    showModal(
      <ConfirmModal
        strTitle="Restaurar todo"
        strDescription={
          "Se restaurara la configuracion anterior de Eden, Dolphin y Cemu, " +
          "se quitaran las preferencias del plugin y se desactivara el hook " +
          "de ES-DE.\n\n" +
          "Los emuladores deben estar cerrados. Se guarda una copia del " +
          "estado actual.\n\n" +
          "Podras reactivar el hook con el boton de arriba."
        }
        strOKButtonText="Restaurar"
        strCancelButtonText="Cancelar"
        onOK={() => {
          void conBloqueo(async () => {
            const r = await call<[], { ok: boolean; salida: string }>(
              "restaurar_todo"
            );
            abrirVentana(r.ok ? "Restaurado" : "Restaurado con problemas", r.salida);
            await refrescar();
          });
        }}
        onCancel={() => {}}
      />
    );
  };

  if (!est) {
    return (
      <PanelSection title="N.E.C.A">
        <PanelSectionRow>
          <div style={{ opacity: 0.8 }}>Leyendo mandos...</div>
        </PanelSectionRow>
      </PanelSection>
    );
  }

  const p = est.prefs;
  const integrado =
    est.mandos.find((m) => m.clase === "Integrado") ?? null;
  const externos = est.mandos.filter((m) => m.clase !== "Integrado");
  const integradoNombre = integrado?.nombre ?? "";
  const maquinaNombre = nombreMaquina(est.maquina);
  const mostrarIntegrado = Boolean(integrado) || Boolean(maquinaNombre);
  const acento = C.azul;

  return (
    <div
      className="ede-panel"
      style={
        {
          "--ede-acento": acento,
          "--ede-acento-halo": hexA(acento, 0.45),
        } as CSSProperties
      }
    >
      <style>{ESTILOS}</style>

      {!est.instalado || est.desactualizado || !est.hook ? (
        <PanelSection
          title={
            !est.instalado
              ? "Primer uso"
              : !est.hook
                ? "Hook desactivado"
                : est.reparar
                  ? "Reparar"
                  : "Actualizar"
          }
        >
          <PanelSectionRow>
            <BotonAccion
              color={C.verde}
              icono={<FaDownload size={16} />}
              texto={
                !est.instalado
                  ? "Instalar scripts"
                  : !est.hook
                    ? "Reactivar hook"
                    : est.reparar
                      ? "Reparar instalación"
                      : "Actualizar scripts"
              }
              onClick={instalar}
            />
          </PanelSectionRow>
        </PanelSection>
      ) : null}

      {est.scripts_nuevos ? (
        <PanelSection>
          <PanelSectionRow>
            <Aviso tono="info">
              Scripts recién instalados. Cierra el juego y vuelve a abrirlo (o
              pulsa «Aplicar todo») para que se aplique la versión nueva.
            </Aviso>
          </PanelSectionRow>
        </PanelSection>
      ) : null}

      {est.esde === false ? (
        <PanelSection>
          <PanelSectionRow>
            <Aviso tono="atencion">
              ES-DE: activa «Other settings → Enable custom event scripts». Sin
              eso no se aplica al lanzar el juego.
            </Aviso>
          </PanelSectionRow>
        </PanelSection>
      ) : null}

      <PanelSection>
        <PanelSectionRow>
          <div
            style={{
              display: "flex",
              flexWrap: "wrap",
              gap: "6px",
              width: "100%",
            }}
          >
            {maquinaNombre ? (
              <ChipEstado
                color={acento}
                icono={
                  <IconoMaquina
                    maquina={est.maquina}
                    nombre={integradoNombre}
                    size={12}
                  />
                }
                texto={maquinaNombre}
              />
            ) : null}
            <ChipEstado
              color={C.azul}
              icono={<FaGamepad size={11} />}
              texto={`${est.mandos.length} ${
                est.mandos.length === 1 ? "mando" : "mandos"
              }`}
            />
            <ChipEstado
              color={C.violeta}
              icono={<FaFileAlt size={11} />}
              texto={`v${est.version}`}
            />
            <ChipEstado
              color={est.hook ? C.verde : C.rojo}
              icono={
                est.hook ? <FaCheck size={11} /> : <FaBan size={11} />
              }
              texto={est.hook ? "hook OK" : "sin hook"}
            />
          </div>
        </PanelSectionRow>
      </PanelSection>

      <PanelSection>
        <PanelSectionRow>
          <BotonTarjeta onClick={cambiarJugadores}>
            <div
              className="ede-tarjeta"
              style={{
                ...estiloTarjeta(acento),
                display: "flex",
                alignItems: "center",
                gap: "10px",
                width: "100%",
                padding: "11px 12px",
              }}
            >
              <span style={{ fontWeight: 700, fontSize: "0.82em" }}>
                Mandos
              </span>
              <div
                style={{
                  marginLeft: "auto",
                  display: "flex",
                  alignItems: "center",
                  gap: "7px",
                }}
              >
                {[1, 2, 3, 4].map((n) => {
                  const on = n <= Number(p.JUGADORES_MAX);
                  return (
                    <span
                      key={n}
                      className={`ede-slot ${on ? "on" : "off"}${
                        pulsoMando === n ? " pulso" : ""
                      }`}
                      style={on ? { color: COLOR_JUGADOR[n - 1] } : undefined}
                    >
                      <FaGamepad size={15} />
                    </span>
                  );
                })}
              </div>
            </div>
          </BotonTarjeta>
        </PanelSectionRow>
      </PanelSection>

      <Seccion
        titulo="Mandos"
        color={acento}
        icono={<FaGamepad size={13} />}
        abierta={true}
        accion={
          <span style={{ display: "flex", alignItems: "center", gap: "6px" }}>
            <BotonIcono
              titulo="Asignación"
              icono={<FaFileAlt size={12} />}
              onClick={() => abrirAsignacion(est.planes, setEst)}
            />
            <BotonIcono
              titulo="Recargar mandos"
              icono={<FaSyncAlt size={12} />}
              onClick={() => conBloqueo(refrescar)}
            />
          </span>
        }
      >
        {!mostrarIntegrado && externos.length === 0 ? (
          <PanelSectionRow>
            <div style={{ opacity: 0.8 }}>
              No se detecta ningun mando. Enciende el mando y pulsa Recargar.
            </div>
          </PanelSectionRow>
        ) : (
          <PanelSectionRow>
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
                gap: "6px",
                width: "100%",
              }}
            >
              {mostrarIntegrado ? (
                <div
                  className="ede-celda"
                  style={{
                    minWidth: 0,
                    maxWidth: "100%",
                    borderRadius: "16px",
                  }}
                >
                  <TarjetaIntegrado
                    icono={
                      <IconoMaquina
                        maquina={est.maquina}
                        nombre={integradoNombre}
                      />
                    }
                    jugador={integrado?.jugador ?? null}
                    modo={p.ORDEN_INTEGRADO}
                    detectado={Boolean(integrado)}
                    onClick={() => elegirIntegrado(siguienteIntegrado())}
                  />
                </div>
              ) : null}
              {externos.map((m) => (
                <div
                  key={`${m.guid}-${m.puerto}`}
                  className="ede-celda"
                  style={{
                    minWidth: 0,
                    maxWidth: "100%",
                    borderRadius: "16px",
                  }}
                >
                  <MandoCuadrado
                    m={m}
                    mostrarMac={true}
                    destello={destello === m.serie}
                    onClick={() => tocarMando(m)}
                  />
                </div>
              ))}
            </div>
          </PanelSectionRow>
        )}
        {aviso ? (
          <PanelSectionRow>
            <Aviso tono="atencion" onClick={limpiarAviso}>
              {aviso}
            </Aviso>
          </PanelSectionRow>
        ) : null}
        {est.ds_conectados > Number(p.JUGADORES_MAX) ? (
          <PanelSectionRow>
            <div style={{ fontSize: "0.68em", color: C.dorado }}>
              Se configuran {p.JUGADORES_MAX} de {est.ds_conectados} mandos.
              Cambialo en Ajustes → Mandos a configurar.
            </div>
          </PanelSectionRow>
        ) : null}
        {est.mandos.length > 1 ? (
          <PanelSectionRow>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: "6px",
                fontSize: "0.68em",
                opacity: 0.6,
              }}
            >
              <GlifoA /> vibrar · dos toques seguidos = mando principal
            </div>
          </PanelSectionRow>
        ) : null}
      </Seccion>

      <Seccion
        titulo="Ajustes"
        color={C.violeta}
        icono={<FaSlidersH size={12} />}
        abierta={Boolean(abiertas.ajustes)}
        onToggle={() => toggle("ajustes")}
      >
        <Rejilla>
          <div className="ede-celda">
            <TarjetaAccion
              color={C.verde}
              icono={<FaCheck size={17} />}
              anim="pop"
              titulo="Aplicar"
              detalle="Eden"
              onClick={aplicar}
            />
          </div>
          <div className="ede-celda">
            <TarjetaAccion
              color={C.azul}
              icono={<FaSyncAlt size={16} />}
              anim="giro"
              titulo="Aplicar todo"
              detalle="Los 3"
              onClick={aplicarTodo}
            />
          </div>
          <div className="ede-celda">
            <TarjetaAccion
              color={C.rojo}
              icono={<FaUndo size={16} />}
              anim="giro"
              titulo="Restaurar"
              detalle="Todo"
              onClick={restaurarTodo}
            />
          </div>
          <div className="ede-celda">
            <TarjetaAccion
              color={C.turquesa}
              icono={<FaFileAlt size={16} />}
              anim="barrido"
              titulo="Ver log"
              detalle="log.txt"
              onClick={verLog}
            />
          </div>
        </Rejilla>
      </Seccion>
    </div>
  );
}

export default definePlugin(() => {
  return {
    name: "N.E.C.A",
    titleView: <div className={staticClasses.Title}>N.E.C.A</div>,
    content: <Content />,
    icon: <FaGamepad />,
    onDismount() {
      console.log("N.E.C.A descargado");
    },
  };
});
