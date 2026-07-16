/**
 * db.ts — SQLite database setup via better-sqlite3
 * Tabel: users
 */

import Database from "better-sqlite3";
import { join } from "node:path";
import { mkdirSync } from "node:fs";
import { logger } from "./logger.js";

const DB_DIR = process.env.DB_DIR ?? "/tmp/banding-wa-data";
mkdirSync(DB_DIR, { recursive: true });

const DB_PATH = join(DB_DIR, "app.db");

export const db = new Database(DB_PATH);

// WAL mode — baca lebih cepat, aman concurrent
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

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

export const stmt = {
  insertUser: db.prepare<{ username: string; password_hash: string }>(
    "INSERT INTO users (username, password_hash) VALUES (@username, @password_hash)",
  ),
  findByUsername: db.prepare<{ username: string }>(
    "SELECT * FROM users WHERE username = @username LIMIT 1",
  ),
  findById: db.prepare<{ id: number }>(
    "SELECT * FROM users WHERE id = @id LIMIT 1",
  ),
} as const;
