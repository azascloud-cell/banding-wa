/**
 * wa-baileys.ts — WhatsApp session via @whiskeysockets/baileys (multi-user)
 *
 * Setiap user punya sesi sendiri, disimpan di /tmp/wa-sessions/<userId>/
 * Gunakan getSession(userId) untuk mengakses atau membuat sesi user.
 */

import { existsSync, rmSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { logger } from "../lib/logger.js";

// ── Types ─────────────────────────────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type WASocket = any;

export type SessionStatus = "disconnected" | "connecting" | "connected";

interface SessionState {
  status: SessionStatus;
  qr?: string;
  number?: string;
}

interface UserSession {
  sock: WASocket | null;
  state: SessionState;
  autoReconnect: boolean;
  initPromise: Promise<void> | null;
  sessionPath: string;
}

// ── Per-user session map ──────────────────────────────────────
const sessions = new Map<number, UserSession>();

const SESSIONS_ROOT = "/tmp/wa-sessions";

function makeSession(userId: number): UserSession {
  return {
    sock: null,
    state: { status: "disconnected" },
    autoReconnect: true,
    initPromise: null,
    sessionPath: `${SESSIONS_ROOT}/${userId}`,
  };
}

function getOrCreate(userId: number): UserSession {
  if (!sessions.has(userId)) sessions.set(userId, makeSession(userId));
  return sessions.get(userId)!;
}

// ── Core: buat / restart socket per user ─────────────────────
async function startSocket(userId: number, clearSession = false): Promise<void> {
  const s = getOrCreate(userId);

  if (s.sock) {
    try { s.sock.end(undefined); } catch { /* ignore */ }
    s.sock = null;
  }

  if (clearSession && existsSync(s.sessionPath)) {
    rmSync(s.sessionPath, { recursive: true, force: true });
  }

  await mkdir(s.sessionPath, { recursive: true });
  s.state = { status: "connecting" };

  const baileys = await import("@whiskeysockets/baileys");
  const makeWASocket = baileys.default ?? baileys.makeWASocket ?? baileys;
  const { useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } = baileys;

  const { default: pino } = await import("pino");
  const { state: authState, saveCreds } = await useMultiFileAuthState(s.sessionPath);

  let version: [number, number, number] = [2, 3000, 1015901307];
  try {
    const fetched = await fetchLatestBaileysVersion();
    version = fetched.version;
  } catch { /* pakai default version */ }

  s.sock = makeWASocket({
    version,
    logger: pino({ level: "silent" }),
    auth: authState,
    printQRInTerminal: false,
    browser: ["Ubuntu", "Chrome", "20.0.04"],
    connectTimeoutMs: 60_000,
    defaultQueryTimeoutMs: 30_000,
    keepAliveIntervalMs: 25_000,
    retryRequestDelayMs: 2_000,
    generateHighQualityLinkPreview: false,
  });

  s.sock.ev.on("creds.update", saveCreds);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  s.sock.ev.on("connection.update", async (update: any) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      s.state = { status: "connecting", qr };
      logger.info({ userId }, "[wa-baileys] QR code siap");
    }

    if (connection === "connecting") {
      s.state = { ...s.state, status: "connecting" };
    }

    if (connection === "open") {
      const info = s.sock?.user;
      const rawId: string = info?.id ?? "";
      const number = rawId.includes("@") ? rawId.split("@")[0] : rawId;
      s.state = { status: "connected", number: `+${number}` };
      logger.info({ userId, number: s.state.number }, "[wa-baileys] Terhubung");
    }

    if (connection === "close") {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const code = (lastDisconnect?.error as any)?.output?.statusCode;
      const shouldReconnect = code !== DisconnectReason.loggedOut && s.autoReconnect;
      logger.warn({ userId, code, shouldReconnect }, "[wa-baileys] Koneksi terputus");

      s.state = { status: "disconnected" };
      s.sock = null;

      if (shouldReconnect) {
        setTimeout(() => {
          startSocket(userId, false).catch((e) =>
            logger.error({ err: e, userId }, "[wa-baileys] Reconnect error"),
          );
        }, 3_000);
      }
    }
  });
}

// ── Public: getters ───────────────────────────────────────────
export function getStatus(userId: number): SessionStatus {
  return getOrCreate(userId).state.status;
}
export function getQR(userId: number): string | undefined {
  return getOrCreate(userId).state.qr;
}
export function getNumber(userId: number): string | undefined {
  return getOrCreate(userId).state.number;
}
export function getSocket(userId: number): WASocket | null {
  return getOrCreate(userId).sock;
}
export function getFullState(userId: number): SessionState {
  return { ...getOrCreate(userId).state };
}

// ── Public: init dari saved session saat server start ────────
export async function initFromSavedSession(userId: number): Promise<void> {
  const s = getOrCreate(userId);
  if (!existsSync(s.sessionPath)) return;
  if (s.initPromise) return s.initPromise;
  s.initPromise = startSocket(userId, false).catch((e) => {
    logger.warn({ err: e, userId }, "[wa-baileys] Init dari session gagal");
  });
  return s.initPromise;
}

// ── Public: mulai sesi baru (QR mode) ────────────────────────
export async function startNewSession(userId: number): Promise<void> {
  const s = getOrCreate(userId);
  s.autoReconnect = true;
  await startSocket(userId, true);
}

// ── Public: minta pairing code ───────────────────────────────
export async function requestPairingCode(userId: number, phoneNumber: string): Promise<string> {
  const s = getOrCreate(userId);
  s.autoReconnect = true;

  await startSocket(userId, true);
  await new Promise<void>((r) => setTimeout(r, 3_000));

  if (!s.sock) throw new Error("Socket tidak berhasil dibuat, coba lagi");

  const cleanNumber = phoneNumber.replace(/\D/g, "");
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const code: string = await (s.sock as any).requestPairingCode(cleanNumber);

  return code?.match(/.{1,4}/g)?.join("-") ?? code;
}

// ── Public: cek nomor terdaftar di WA ────────────────────────
export async function checkOnWhatsApp(
  userId: number,
  e164Numbers: string[],
): Promise<Map<string, boolean>> {
  const result = new Map<string, boolean>();
  const s = getOrCreate(userId);

  if (!s.sock || s.state.status !== "connected" || e164Numbers.length === 0) {
    return result;
  }

  try {
    const jids = e164Numbers.map((n) => `${n}@s.whatsapp.net`);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const res: any[] = await (s.sock as any).onWhatsApp(...jids) ?? [];
    for (const item of res) {
      const num = item.jid.split("@")[0];
      result.set(num, Boolean(item.exists));
    }
    for (const n of e164Numbers) {
      if (!result.has(n)) result.set(n, false);
    }
  } catch (e) {
    logger.warn({ err: e, userId }, "[wa-baileys] onWhatsApp error");
  }

  return result;
}

// ── Public: logout ────────────────────────────────────────────
export async function logout(userId: number): Promise<void> {
  const s = getOrCreate(userId);
  s.autoReconnect = false;
  s.state = { status: "disconnected" };

  if (s.sock) {
    try { await s.sock.logout(); } catch { /* ignore */ }
    try { s.sock.end(undefined); } catch { /* ignore */ }
    s.sock = null;
  }

  if (existsSync(s.sessionPath)) {
    rmSync(s.sessionPath, { recursive: true, force: true });
  }

  s.initPromise = null;
  sessions.delete(userId);
}
