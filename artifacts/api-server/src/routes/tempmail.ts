import { Router, type IRouter } from "express";

const router: IRouter = Router();

const MAILTM = "https://api.mail.tm";

interface MailTmDomainList {
  "hydra:member": Array<{ domain: string; isActive: boolean }>;
}
interface MailTmToken {
  token: string;
  id: string;
}
interface MailTmMessage {
  from: { address: string; name?: string };
  subject: string;
  intro: string;
  createdAt: string;
}
interface MailTmMessageList {
  "hydra:member": MailTmMessage[];
  "hydra:totalItems": number;
}

router.get("/tempmail/create", async (req, res) => {
  try {
    // 1. Ambil domain aktif
    const domRes = await fetch(`${MAILTM}/domains?page=1`, {
      signal: AbortSignal.timeout(15_000),
    });
    if (!domRes.ok) {
      const body = await domRes.text();
      return res.status(502).json({
        error: `mail.tm /domains error HTTP ${domRes.status}`,
        rawBody: body,
      });
    }
    const domData = (await domRes.json()) as MailTmDomainList;
    const activeDomain = domData["hydra:member"].find((d) => d.isActive);
    if (!activeDomain) {
      return res.status(502).json({ error: "Tidak ada domain mail.tm aktif" });
    }

    // 2. Generate kredensial acak
    const rand = Math.random().toString(36).slice(2, 10);
    const address = `${rand}@${activeDomain.domain}`;
    const password = Math.random().toString(36).slice(2, 14);

    // 3. Buat akun
    const accRes = await fetch(`${MAILTM}/accounts`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ address, password }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!accRes.ok) {
      const body = await accRes.text();
      return res.status(502).json({
        error: `mail.tm /accounts error HTTP ${accRes.status}`,
        rawBody: body,
      });
    }

    // 4. Login & ambil token
    const tokRes = await fetch(`${MAILTM}/token`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ address, password }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!tokRes.ok) {
      const body = await tokRes.text();
      return res.status(502).json({
        error: `mail.tm /token error HTTP ${tokRes.status}`,
        rawBody: body,
      });
    }
    const tokData = (await tokRes.json()) as MailTmToken;

    req.log.info({ address }, "Temp email created");

    return res.json({
      email: address,
      provider: "Mail.tm",
      sidToken: tokData.token,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "tempmail/create error");
    return res.status(500).json({ error: message });
  }
});

router.get("/tempmail/inbox", async (req, res) => {
  const { sidToken } = req.query;
  if (!sidToken || typeof sidToken !== "string") {
    return res.status(400).json({ error: "sidToken wajib diisi", messages: [] });
  }

  try {
    const msgRes = await fetch(`${MAILTM}/messages?page=1`, {
      headers: { Authorization: `Bearer ${sidToken}` },
      signal: AbortSignal.timeout(15_000),
    });

    if (!msgRes.ok) {
      const body = await msgRes.text();
      req.log.warn({ status: msgRes.status, body }, "tempmail/inbox error");
      return res.json({ messages: [], error: `mail.tm HTTP ${msgRes.status}`, rawBody: body });
    }

    const data = (await msgRes.json()) as MailTmMessageList;

    /** Parse nomor tiket dari subject "WhatsApp Support XXXX" */
    function parseTicketNumber(subject: string): string | null {
      // Format: "WhatsApp Support 4524970751159007" atau "Re: WhatsApp Support 1234567890"
      const match = subject.match(/WhatsApp\s+Support\s+(\d{6,20})/i);
      return match ? match[1] : null;
    }

    const messages = (data["hydra:member"] ?? []).map((m) => {
      const subject = m.subject ?? "(Tanpa Subjek)";
      return {
        from: m.from?.address ?? "Unknown",
        subject,
        preview: m.intro ?? "",
        createdAt: m.createdAt,
        ticketNumber: parseTicketNumber(subject),
      };
    });

    return res.json({ messages, total: data["hydra:totalItems"] ?? 0 });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "tempmail/inbox error");
    return res.status(500).json({ error: message, messages: [] });
  }
});

export default router;
