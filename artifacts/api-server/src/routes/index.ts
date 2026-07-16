import { Router, type IRouter } from "express";
import { requireAuth } from "../middleware/auth.js";
import authRouter from "./auth";
import healthRouter from "./health";
import githubRouter from "./github";
import pterodactylRouter from "./pterodactyl";

const router: IRouter = Router();

// ── Routes publik (tanpa auth) ────────────────────────────────
router.use(authRouter);       // POST /auth/register, /auth/login, GET /auth/me
router.use(healthRouter);     // GET /healthz

// ── Routes internal butuh JWT ─────────────────────────────────
router.use(requireAuth);
router.use(githubRouter);       // /github/*
router.use(pterodactylRouter);  // /pterodactyl/*

export default router;
