/**
 * wa-baileys.ts — WhatsApp session via @whiskeysockets/baileys
 *
 * TIDAK membutuhkan Chrome/Puppeteer sama sekali — pure WebSocket.
 * Digunakan untuk:
 *   • QR pairing / pairing code
 *   • Cek nomor terdaftar di WA (onWhatsApp)
 */

import { existsSync, rmSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { logger } from "../lib/logger.js";

// ── Types ─────────────────────────────────────────────────────
// Lazy import — kita tidak tahu tipe persisnya, pakai any
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type WASocket = any;

export type SessionStatus = "disconnected" | "connecting" | "connected";

interface SessionState {
  status: SessionStatus;
  qr?: string;      // raw QR string untuk Flutter
  number?: string;  // nomor yang terhubung (+628...)
}

// ── State ─────────────────────────────────────────────────────
const SESSION_PATH = "/tmp/wa-session-baileys";

let sock: WASocket | null = null;
let sessionState: SessionState = { status: "disconnected" };
let autoReconnect = true;
let initPromise: Promise<void> | null = null;

// ── Getters ──────────────────────────────────────────────────
export function getStatus(): SessionStatus { return sessionState.status; }
export function getQR(): string | undefined { return sessionState.qr; }
export function getNumber(): string | undefined { return sessionState.number; }
export function getSocket(): WASocket | null { return sock; }
export function getFullState(): SessionState { return { ...sessionState }; }

// ── Core: buat / restart socket ──────────────────────────────
async function startSocket(clearSession = false): Promise<void> {
  // Tutup socket lama
  if (sock) {
    try { sock.end(undefined); } catch { /* ignore */ }
    sock = null;
  }

  if (clearSession && existsSync(SESSION_PATH)) {
    rmSync(SESSION_PATH, { recursive: true, force: true });
  }

  await mkdir(SESSION_PATH, { recursive: true });
  sessionState = { status: "connecting" };

  const baileys = await import("@whiskeysockets/baileys");
  const makeWASocket = baileys.default ?? baileys.makeWASocket ?? baileys;
  const { useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } = baileys;

  const { default: pino } = await import("pino");
  const { state: authState, saveCreds } = await useMultiFileAuthState(SESSION_PATH);

  let version: [number, number, number] = [2, 3000, 1015901307];
  try {
    const fetched = await fetchLatestBaileysVersion();
    version = fetched.version;
  } catch { /* pakai default version jika network error */ }

  sock = makeWASocket({
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

  sock.ev.on("creds.update", saveCreds);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  sock.ev.on("connection.update", async (update: any) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      sessionState = { status: "connecting", qr };
      logger.info("[wa-baileys] QR code siap");
    }

    if (connection === "connecting") {
      sessionState = { ...sessionState, status: "connecting" };
    }

    if (connection === "open") {
      const info = sock?.user;
      // id bisa berupa "628xxx@s.whatsapp.net" atau sudah plain
      const rawId: string = info?.id ?? "";
      const number = rawId.includes("@") ? rawId.split("@")[0] : rawId;
      sessionState = { status: "connected", number: `+${number}` };
      logger.info({ number: sessionState.number }, "[wa-baileys] Terhubung");
    }

    if (connection === "close") {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const code = (lastDisconnect?.error as any)?.output?.statusCode;
      const shouldReconnect =
        code !== DisconnectReason.loggedOut && autoReconnect;
      logger.warn({ code, shouldReconnect }, "[wa-baileys] Koneksi terputus");

      sessionState = { status: "disconnected" };
      sock = null;

      if (shouldReconnect) {
        setTimeout(() => {
          startSocket(false).catch((e) =>
            logger.error({ err: e }, "[wa-baileys] Reconnect error"),
          );
        }, 3_000);
      }
    }
  });
}

// ── Public: init dari saved session saat server start ────────
export async function initFromSavedSession(): Promise<void> {
  if (!existsSync(SESSION_PATH)) return;
  if (initPromise) return initPromise;
  initPromise = startSocket(false).catch((e) => {
    logger.warn({ err: e }, "[wa-baileys] Init dari session gagal");
  });
  return initPromise;
}

// ── Public: mulai sesi baru (QR mode) ────────────────────────
export async function startNewSession(): Promise<void> {
  autoReconnect = true;
  await startSocket(true);
}

// ── Public: minta pairing code ───────────────────────────────
export async function requestPairingCode(phoneNumber: string): Promise<string> {
  autoReconnect = true;

  // Mulai socket baru + hapus session lama (sesuai Bailey script)
  await startSocket(true);

  // Tunggu socket siap — sama seperti Bailey script (3 detik)
  await new Promise<void>((r) => setTimeout(r, 3_000));

  if (!sock) throw new Error("Socket tidak berhasil dibuat, coba lagi");

  const cleanNumber = phoneNumber.replace(/\D/g, "");
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const code: string = await (sock as any).requestPairingCode(cleanNumber);

  // Format XXXX-XXXX
  return code?.match(/.{1,4}/g)?.join("-") ?? code;
}

// ── Public: cek nomor terdaftar di WA ────────────────────────
/**
 * Cek apakah nomor-nomor terdaftar di WhatsApp menggunakan
 * socket Baileys yang sedang aktif.
 *
 * @param e164Numbers - nomor tanpa +, misal ["628123456789"]
 * @returns Map<nomor, terdaftar> — kosong jika session tidak aktif
 */
export async function checkOnWhatsApp(
  e164Numbers: string[],
): Promise<Map<string, boolean>> {
  const result = new Map<string, boolean>();
  if (!sock || sessionState.status !== "connected" || e164Numbers.length === 0) {
    return result; // caller pakai fallback
  }

  try {
    const jids = e164Numbers.map((n) => `${n}@s.whatsapp.net`);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const res: any[] = await (sock as any).onWhatsApp(...jids) ?? [];
    for (const item of res) {
      const num = item.jid.split("@")[0];
      result.set(num, Boolean(item.exists));
    }
    // Nomor tidak muncul di result = tidak terdaftar
    for (const n of e164Numbers) {
      if (!result.has(n)) result.set(n, false);
    }
  } catch (e) {
    logger.warn({ err: e }, "[wa-baileys] onWhatsApp error");
  }

  return result;
}

// ── Public: logout ────────────────────────────────────────────
export async function logout(): Promise<void> {
  autoReconnect = false;
  sessionState = { status: "disconnected" };

  if (sock) {
    try { await sock.logout(); } catch { /* ignore */ }
    try { sock.end(undefined); } catch { /* ignore */ }
    sock = null;
  }

  if (existsSync(SESSION_PATH)) {
    rmSync(SESSION_PATH, { recursive: true, force: true });
  }
  initPromise = null;
}
