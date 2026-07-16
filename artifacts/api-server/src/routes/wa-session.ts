/**
 * wa-session.ts — Manajemen sesi WhatsApp per-user
 *
 * Semua route butuh JWT (dipasang di app.ts sebelum router ini).
 * userId diambil dari req.user yang di-inject oleh requireAuth middleware.
 *
 * GET  /api/wa-session/status        → status sesi user saat ini
 * POST /api/wa-session/start         → mulai sesi / tampilkan QR baru
 * POST /api/wa-session/pairing-code  → minta kode pairing
 * POST /api/wa-session/logout        → putus sesi
 */

import { Router, type IRouter } from "express";
import * as WaBaileys from "../services/wa-baileys.js";

const router: IRouter = Router();

// ── GET /wa-session/status ────────────────────────────────────
router.get("/wa-session/status", (req, res) => {
  const userId = req.user!.userId;
  // Init dari saved session jika belum
  void WaBaileys.initFromSavedSession(userId);

  return res.json({
    status: WaBaileys.getStatus(userId),
    qr: WaBaileys.getQR(userId),
    number: WaBaileys.getNumber(userId),
    waLibAvailable: true,
  });
});

// ── POST /wa-session/start ────────────────────────────────────
router.post("/wa-session/start", async (req, res) => {
  const userId = req.user!.userId;

  if (WaBaileys.getStatus(userId) === "connected") {
    return res.json({
      success: true,
      message: "Sesi sudah aktif",
      status: WaBaileys.getFullState(userId),
    });
  }

  void WaBaileys.startNewSession(userId).catch((e) => {
    req.log.error({ err: e, userId }, "[wa-session] startNewSession error");
  });

  return res.json({
    success: true,
    message: "Memulai sesi WhatsApp, refresh status untuk QR code",
  });
});

// ── POST /wa-session/pairing-code ────────────────────────────
router.post("/wa-session/pairing-code", async (req, res) => {
  const userId = req.user!.userId;
  const body = req.body as Record<string, unknown>;
  const rawNumber = typeof body.number === "string" ? body.number : "";
  const number = rawNumber.replace(/\D/g, "");

  if (!number || number.length < 8) {
    return res.status(400).json({
      error: "Nomor tidak valid. Masukkan nomor lengkap dengan kode negara (contoh: 628123456789)",
    });
  }

  req.log.info({ userId, number: `${number.slice(0, 4)}***` }, "[wa-session] Minta pairing code");

  try {
    const code = await WaBaileys.requestPairingCode(userId, number);
    req.log.info({ userId, codeLength: code.length }, "[wa-session] Pairing code berhasil");
    return res.json({ code, number: `+${number}` });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    req.log.error({ err, userId }, "[wa-session] Pairing code gagal");
    return res.status(500).json({ error: msg });
  }
});

// ── POST /wa-session/logout ───────────────────────────────────
router.post("/wa-session/logout", async (req, res) => {
  const userId = req.user!.userId;
  await WaBaileys.logout(userId);
  req.log.info({ userId }, "[wa-session] Logout berhasil");
  return res.json({ success: true, message: "Sesi diputus" });
});

export default router;
