import { Router, type IRouter } from "express";
import { requireAuth } from "../middleware/auth.js";
import authRouter from "./auth";
import healthRouter from "./health";
import appealRouter from "./appeal";
import tempmailRouter from "./tempmail";
import cekBioRouter from "./cek-bio";
import waSessionRouter from "./wa-session";

const router: IRouter = Router();

// ── Routes tanpa auth ─────────────────────────────────────────
router.use(authRouter);       // /auth/register, /auth/login, /auth/me
router.use(healthRouter);     // /health

// ── Routes butuh JWT ──────────────────────────────────────────
router.use(requireAuth);
router.use(appealRouter);
router.use(tempmailRouter);
router.use(cekBioRouter);
router.use(waSessionRouter);

export default router;
