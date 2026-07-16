import { Router, type IRouter } from "express";

const router: IRouter = Router();

function getPteroConfig() {
  const apiKey = process.env.PTERODACTYL_API_KEY;
  const panelUrl = process.env.PTERODACTYL_PANEL_URL?.replace(/\/$/, "");
  if (!apiKey || !panelUrl) {
    throw new Error("PTERODACTYL_API_KEY dan PTERODACTYL_PANEL_URL belum dikonfigurasi");
  }
  return { apiKey, panelUrl };
}

async function pteroFetch(path: string, options: RequestInit = {}) {
  const { apiKey, panelUrl } = getPteroConfig();
  const res = await fetch(`${panelUrl}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      Accept: "application/json",
      "Content-Type": "application/json",
      ...(options.headers ?? {}),
    },
  });
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(`Pterodactyl API error ${res.status}: ${text}`);
  }
  // 204 No Content
  if (res.status === 204) return null;
  return res.json();
}

/** GET /api/pterodactyl/servers — daftar semua server */
router.get("/pterodactyl/servers", async (req, res) => {
  try {
    const data = await pteroFetch("/api/client");
    res.json(data);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "pterodactyl/servers error");
    res.status(500).json({ error: message });
  }
});

/** GET /api/pterodactyl/servers/:id — detail server tertentu */
router.get("/pterodactyl/servers/:id", async (req, res) => {
  try {
    const data = await pteroFetch(`/api/client/servers/${req.params.id}`);
    res.json(data);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "pterodactyl/server-detail error");
    res.status(500).json({ error: message });
  }
});

/** GET /api/pterodactyl/servers/:id/resources — resource usage (CPU, RAM, dll) */
router.get("/pterodactyl/servers/:id/resources", async (req, res) => {
  try {
    const data = await pteroFetch(`/api/client/servers/${req.params.id}/resources`);
    res.json(data);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "pterodactyl/resources error");
    res.status(500).json({ error: message });
  }
});

/** POST /api/pterodactyl/servers/:id/power — aksi power (start/stop/restart/kill) */
router.post("/pterodactyl/servers/:id/power", async (req, res) => {
  try {
    const body = req.body as { signal?: string };
    const signal = body.signal ?? "restart";
    if (!["start", "stop", "restart", "kill"].includes(signal)) {
      res.status(400).json({ error: "signal harus salah satu dari: start, stop, restart, kill" });
      return;
    }
    await pteroFetch(`/api/client/servers/${req.params.id}/power`, {
      method: "POST",
      body: JSON.stringify({ signal }),
    });
    res.json({ success: true, server: req.params.id, signal });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "pterodactyl/power error");
    res.status(500).json({ error: message });
  }
});

/** POST /api/pterodactyl/servers/:id/command — kirim perintah ke konsol server */
router.post("/pterodactyl/servers/:id/command", async (req, res) => {
  try {
    const body = req.body as { command?: string };
    if (!body.command) {
      res.status(400).json({ error: "field 'command' wajib diisi" });
      return;
    }
    await pteroFetch(`/api/client/servers/${req.params.id}/command`, {
      method: "POST",
      body: JSON.stringify({ command: body.command }),
    });
    res.json({ success: true, server: req.params.id, command: body.command });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "pterodactyl/command error");
    res.status(500).json({ error: message });
  }
});

/** GET /api/pterodactyl/servers/:id/files — daftar file di direktori tertentu */
router.get("/pterodactyl/servers/:id/files", async (req, res) => {
  try {
    const dir = (req.query as Record<string, string>).directory ?? "/";
    const data = await pteroFetch(
      `/api/client/servers/${req.params.id}/files/list?directory=${encodeURIComponent(dir)}`
    );
    res.json(data);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "pterodactyl/files error");
    res.status(500).json({ error: message });
  }
});

export default router;
