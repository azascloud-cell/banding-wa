---
name: Multi-user auth architecture
description: How user auth, JWT, and per-user WA sessions are structured across backend and Flutter
---

## Backend

- **Storage**: SQLite via `better-sqlite3` at `/tmp/banding-wa-data/app.db`, table `users(id, username, password_hash, created_at)`
- **JWT**: `jsonwebtoken` with payload `{ userId: number, username: string }`, 30-day expiry, secret from `SESSION_SECRET` env var
- **Middleware**: `src/middleware/auth.ts` → `requireAuth` reads `Authorization: Bearer <token>`, attaches `req.user`
- **Public routes**: `/api/auth/register`, `/api/auth/login`, `/api/health` (no JWT needed)
- **Protected routes**: everything else — `requireAuth` is applied via `router.use(requireAuth)` in `routes/index.ts` after the public routes

## Per-user WA sessions

- `wa-baileys.ts` holds `sessions: Map<userId, UserSession>` — each user gets their own socket, state, session path
- Session path per user: `/tmp/wa-sessions/<userId>/`
- All exported functions (`getStatus`, `startNewSession`, `requestPairingCode`, `checkOnWhatsApp`, `logout`) take `userId: number` as first param
- `cek-bio.ts` passes `userId` from `req.user.userId` through `startScanJob(numbers, userId)` → `runJob(job, userId)` → `checkOnWhatsApp(userId, e164List)`

## Flutter

- `AuthService` (static singleton): stores JWT in SharedPreferences keys `auth_jwt_token` + `auth_user_json`
- `AuthService.headers` returns `{'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}` — used by ALL services (appeal, tempmail, cek_bio)
- `AuthProvider` (ChangeNotifier): states = `loading | unauthenticated | authenticated`; `init()` called at app start
- Router: `GoRouter` with `refreshListenable: authProvider` + `redirect: _authGuard` — auto-redirects to `/login` if not logged in
- Auth screens live in `lib/screens/auth/login_screen.dart` (both `LoginScreen` and `RegisterScreen` in one file)

**Why JWT over session cookies:** Stateless — no server-side session store needed; works naturally with mobile clients that don't share cookie jars. 30-day expiry means users stay logged in through normal app use.
