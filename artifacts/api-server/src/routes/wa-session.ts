/**
 * wa-session.ts — Routes manajemen sesi WhatsApp
 *
 * Menggunakan @whiskeysockets/baileys via wa-baileys.ts service.
 * TIDAK membutuhkan Chrome/Puppeteer — pure WebSocket.
 *
 * Routes:
 *   GET  /api/wa-session/status        → status sesi
 *   POST /api/wa-session/start         → mulai sesi / tampilkan QR baru
 *   POST /api/wa-session/pairing-code  → minta kode pairing (no Chrome needed)
 *   POST /api/wa-session/logout        → putus sesi
 */

import { Router, type IRouter } from "express";
import * as WaBaileys from "../services/wa-baileys.js";

const router: IRouter = Router();

// Init dari saved session saat module dimuat (background, tidak blocking)
void WaBaileys.initFromSavedSession();

// ── GET /wa-session/status ────────────────────────────────────
router.get("/wa-session/status", (_req, res) => {
  return res.json({
    status: WaBaileys.getStatus(),
    qr: WaBaileys.getQR(),
    number: WaBaileys.getNumber(),
    waLibAvailable: true, // Baileys selalu tersedia
  });
});

// ── POST /wa-session/start ────────────────────────────────────
router.post("/wa-session/start", async (req, res) => {
  if (WaBaileys.getStatus() === "connected") {
    return res.json({
      success: true,
      message: "Sesi sudah aktif",
      status: WaBaileys.getFullState(),
    });
  }

  // Jalankan di background — tidak block response
  void WaBaileys.startNewSession().catch((e) => {
    req.log.error({ err: e }, "[wa-session] startNewSession error");
  });

  return res.json({
    success: true,
    message: "Memulai sesi WhatsApp, refresh status untuk QR code",
  });
});

// ── POST /wa-session/pairing-code ────────────────────────────
router.post("/wa-session/pairing-code", async (req, res) => {
  const body = req.body as Record<string, unknown>;
  const rawNumber = typeof body.number === "string" ? body.number : "";
  const number = rawNumber.replace(/\D/g, "");

  if (!number || number.length < 8) {
    return res.status(400).json({
      error: "Nomor tidak valid. Masukkan nomor lengkap dengan kode negara (contoh: 628123456789)",
    });
  }

  req.log.info({ number: `${number.slice(0, 4)}***` }, "[wa-session] Minta pairing code");

  try {
    const code = await WaBaileys.requestPairingCode(number);
    req.log.info({ codeLength: code.length }, "[wa-session] Pairing code berhasil");
    return res.json({ code, number: `+${number}` });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    req.log.error({ err, number: `${number.slice(0, 4)}***` }, "[wa-session] Pairing code gagal");
    return res.status(500).json({ error: msg });
  }
});

// ── POST /wa-session/logout ───────────────────────────────────
router.post("/wa-session/logout", async (req, res) => {
  await WaBaileys.logout();
  req.log.info("[wa-session] Logout berhasil");
  return res.json({ success: true, message: "Sesi diputus" });
});

export default router;
