/**
 * db.ts — SQLite database setup via Node.js built-in (node:sqlite, Node 24+)
 * Tidak butuh native addon — zero build step.
 * Tabel: users
 */

// Node 24 built-in — tidak perlu install apapun
import { DatabaseSync } from "node:sqlite";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { logger } from "./logger.js";

const DB_DIR = process.env.DB_DIR ?? "/tmp/banding-wa-data";
mkdirSync(DB_DIR, { recursive: true });

const DB_PATH = join(DB_DIR, "app.db");

export const db = new DatabaseSync(DB_PATH);

// WAL mode — baca lebih cepat, aman concurrent
db.exec("PRAGMA journal_mode = WAL");
db.exec("PRAGMA foreign_keys = ON");

// ── Schema ────────────────────────────────────────────────────
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    username     TEXT    NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT   NOT NULL,
    created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
  );
`);

logger.info({ path: DB_PATH }, "[db] SQLite siap");

// ── Typed helpers ─────────────────────────────────────────────
export interface UserRow {
  id: number;
  username: string;
  password_hash: string;
  created_at: string;
}

const _insertUser = db.prepare(
  "INSERT INTO users (username, password_hash) VALUES (?, ?)",
);
const _findByUsername = db.prepare(
  "SELECT * FROM users WHERE username = ? LIMIT 1",
);
const _findById = db.prepare(
  "SELECT * FROM users WHERE id = ? LIMIT 1",
);

export const stmt = {
  insertUser: {
    run: (params: { username: string; password_hash: string }) =>
      _insertUser.run(params.username, params.password_hash),
  },
  findByUsername: {
    get: (params: { username: string }) =>
      _findByUsername.get(params.username) as UserRow | undefined,
  },
  findById: {
    get: (params: { id: number }) =>
      _findById.get(params.id) as UserRow | undefined,
  },
} as const;
