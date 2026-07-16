import { Router, type IRouter } from "express";
import { submitViaBrowser } from "../services/wa-browser.js";
import { addAppealHistory, getAppealHistory } from "../lib/appeal-history.js";

const router: IRouter = Router();

// ── Validasi input ─────────────────────────────────────────────
function validateAppeal(
  body: unknown,
): { phone: string; email: string; description: string } | null {
  if (!body || typeof body !== "object") return null;
  const b = body as Record<string, unknown>;
  if (typeof b.phone !== "string" || b.phone.length < 8) return null;
  if (typeof b.email !== "string" || !b.email.includes("@")) return null;
  if (typeof b.description !== "string" || b.description.length < 10) return null;
  return { phone: b.phone, email: b.email, description: b.description };
}

// ── Parsing nomor telepon ──────────────────────────────────────
function parsePhone(phone: string): { cc: string; number: string } {
  const digits = phone.replace(/\D/g, "");
  const cc3 = ["967","966","971","974","973","968","880","212","234","254","380"];
  const cc2 = ["62","60","65","66","84","63","92","91","86","81","82","44","27","55","52","54","57","33","49","90","98"];
  const cc1 = ["1","7"];
  for (const cc of cc3) if (digits.startsWith(cc)) return { cc, number: digits.slice(cc.length) };
  for (const cc of cc2) if (digits.startsWith(cc)) return { cc, number: digits.slice(cc.length) };
  for (const cc of cc1) if (digits.startsWith(cc)) return { cc, number: digits.slice(cc.length) };
  return { cc: digits.slice(0, 2), number: digits.slice(2) };
}

// ── Endpoint ──────────────────────────────────────────────────
router.post("/appeal/submit", async (req, res) => {
  const validated = validateAppeal(req.body);
  if (!validated) {
    return res.status(400).json({
      success: false,
      error: "Validasi gagal: phone (min 8 digit), email valid, description (min 10 karakter) wajib.",
    });
  }

  const { phone, email, description } = validated;
  const { cc, number } = parsePhone(phone.replace(/^\+/, ""));

  req.log.info({ cc, number: `${number.slice(0, 3)}***`, email }, "Appeal submit via browser");

  const result = await submitViaBrowser({ cc, number, email, description });

  req.log.info(
    {
      success: result.success,
      statusCode: result.statusCode,
      captchaDetected: result.captchaDetected,
      hasCapturedPayload: !!result.capturedPayload,
    },
    "Browser result",
  );

  // Hapus screenshot dari response produksi (terlalu besar) kecuali mode debug
  const isDebug = req.query["debug"] === "1" || process.env.NODE_ENV !== "production";

  // Parse WA response — Facebook prefixes JSONP dengan "for (;;);"
  let parsedWaResponse: unknown = result.whatsappResponse;
  if (
    typeof parsedWaResponse === "object" &&
    parsedWaResponse !== null &&
    "rawText" in (parsedWaResponse as object)
  ) {
    const raw = (parsedWaResponse as { rawText: string }).rawText;
    try {
      const cleaned = raw.replace(/^for\s*\(;;\);/, "").trim();
      parsedWaResponse = JSON.parse(cleaned);
    } catch {
      parsedWaResponse = { rawText: raw.slice(0, 500) };
    }
  }

  // Tentukan diagnosis dari respons WA
  let diagnosis = "unknown";
  if (result.captchaDetected) {
    diagnosis = "captcha_blocked";
  } else if (result.success && result.statusCode === 200) {
    diagnosis = "submitted_ok";
  } else if (result.statusCode === 400) {
    diagnosis = "wa_rejected_400";
  } else if (result.statusCode === 403) {
    diagnosis = "wa_rejected_403";
  } else if (!result.capturedPayload) {
    diagnosis = "form_not_submitted";
  } else {
    diagnosis = `http_${result.statusCode ?? "unknown"}`;
  }

  // ── Simpan ke riwayat server-side ──────────────────────────
  const maskedPhone = `+${cc}${"*".repeat(Math.max(0, number.length - 4))}${number.slice(-4)}`;
  addAppealHistory({
    phone: maskedPhone,
    email,
    timestamp: new Date().toISOString(),
    success: result.success,
    statusCode: result.statusCode,
    diagnosis,
  });

  return res.json({
    success: result.success,
    method: result.method,
    statusCode: result.statusCode,
    error: result.error,
    diagnosis,
    captchaDetected: result.captchaDetected,
    whatsappResponse: parsedWaResponse,
    requestDebug: {
      phone: `+${cc}${number}`,
      cc,
      number,
      email,
      stepLog: result.stepLog,
      ...(isDebug && { capturedPayload: result.capturedPayload }),
    },
    ...(isDebug && {
      screenshotBefore: result.screenshotBefore,
      screenshotAfter: result.screenshotAfter,
    }),
  });
});

// ── GET /appeal/history ─────────────────────────────────────
router.get("/appeal/history", (_req, res) => {
  return res.json({ history: getAppealHistory() });
});

export default router;
