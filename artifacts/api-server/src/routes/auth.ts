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
    return res.status(400).json({
      error: "Username harus 3–30 karakter, hanya huruf/angka/underscore",
    });
  }
  if (typeof password !== "string" || password.length < 6) {
    return res.status(400).json({ error: "Password minimal 6 karakter" });
  }

  const existing = stmt.findByUsername.get({ username }) as UserRow | undefined;
  if (existing) {
    return res.status(409).json({ error: "Username sudah digunakan" });
  }

  const password_hash = await bcrypt.hash(password, 12);
  const info = stmt.insertUser.run({ username, password_hash });
  const userId = Number(info.lastInsertRowid);

  const token = signToken({ userId, username });
  req.log.info({ userId, username }, "[auth] User baru terdaftar");

  return res.status(201).json({
    token,
    user: { id: userId, username },
  });
});

// ── POST /auth/login ──────────────────────────────────────────
router.post("/auth/login", async (req, res) => {
  const { username, password } = req.body as Record<string, unknown>;

  if (typeof username !== "string" || typeof password !== "string") {
    return res.status(400).json({ error: "Username dan password wajib diisi" });
  }

  const row = stmt.findByUsername.get({ username }) as UserRow | undefined;
  if (!row) {
    return res.status(401).json({ error: "Username atau password salah" });
  }

  const valid = await bcrypt.compare(password, row.password_hash);
  if (!valid) {
    return res.status(401).json({ error: "Username atau password salah" });
  }

  const token = signToken({ userId: row.id, username: row.username });
  req.log.info({ userId: row.id, username: row.username }, "[auth] Login berhasil");

  return res.json({
    token,
    user: { id: row.id, username: row.username },
  });
});

// ── GET /auth/me ──────────────────────────────────────────────
router.get("/auth/me", requireAuth, (req, res) => {
  return res.json({ user: req.user });
});

export default router;
