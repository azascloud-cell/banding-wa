/**
 * auth.ts — Register & Login routes
 *
 * POST /api/auth/register  → daftarkan user baru
 * POST /api/auth/login     → login, dapat JWT
 * GET  /api/auth/me        → info user saat ini (butuh JWT)
 */

import { Router, type IRouter } from "express";
import bcrypt from "bcryptjs";
import { stmt, type UserRow } from "../lib/db.js";
import { signToken } from "../lib/jwt.js";
import { requireAuth } from "../middleware/auth.js";

const router: IRouter = Router();

const USERNAME_RE = /^[a-zA-Z0-9_]{3,30}$/;

// ── POST /auth/register ───────────────────────────────────────
router.post("/auth/register", async (req, res) => {
  const { username, password } = req.body as Record<string, unknown>;

  if (typeof username !== "string" || !USERNAME_RE.test(username)) {
    res.status(400).json({
      error: "Username harus 3–30 karakter, hanya huruf/angka/underscore",
    });
    return;
  }
  if (typeof password !== "string" || password.length < 6) {
    res.status(400).json({ error: "Password minimal 6 karakter" });
    return;
  }

  const existing = stmt.findByUsername.get({ username }) as UserRow | undefined;
  if (existing) {
    res.status(409).json({ error: "Username sudah digunakan" });
    return;
  }

  const password_hash = await bcrypt.hash(password, 12);
  const info = stmt.insertUser.run({ username, password_hash }) as {
    lastInsertRowid: number | bigint;
    changes: number;
  };

  // Konversi BigInt → number, pastikan valid
  const rawId = info.lastInsertRowid;
  const userId = typeof rawId === "bigint" ? Number(rawId) : rawId;

  if (!userId || !Number.isFinite(userId)) {
    req.log.error({ info }, "[auth] lastInsertRowid tidak valid");
    res.status(500).json({ error: "Registrasi gagal, coba lagi" });
    return;
  }

  const token = signToken({ userId, username });
  req.log.info({ userId, username }, "[auth] User baru terdaftar");

  res.status(201).json({
    token,
    user: { id: userId, username },
  });
});

// ── POST /auth/login ──────────────────────────────────────────
router.post("/auth/login", async (req, res) => {
  const { username, password } = req.body as Record<string, unknown>;

  if (typeof username !== "string" || typeof password !== "string") {
    res.status(400).json({ error: "Username dan password wajib diisi" });
    return;
  }

  const row = stmt.findByUsername.get({ username }) as UserRow | undefined;
  if (!row) {
    res.status(401).json({ error: "Username atau password salah" });
    return;
  }

  const valid = await bcrypt.compare(password, row.password_hash);
  if (!valid) {
    res.status(401).json({ error: "Username atau password salah" });
    return;
  }

  // Pastikan id selalu number, bukan BigInt
  const userId = typeof row.id === "bigint" ? Number(row.id) : Number(row.id);

  const token = signToken({ userId, username: row.username });
  req.log.info({ userId, username: row.username }, "[auth] Login berhasil");

  res.json({
    token,
    user: { id: userId, username: row.username },
  });
});

// ── GET /auth/me ──────────────────────────────────────────────
router.get("/auth/me", requireAuth, (req, res) => {
  res.json({ user: req.user });
});

export default router;
