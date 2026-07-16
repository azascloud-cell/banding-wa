import { Router, type IRouter } from "express";
import healthRouter from "./health";
import githubRouter from "./github";
import pterodactylRouter from "./pterodactyl";

const router: IRouter = Router();

router.use(healthRouter);
router.use(githubRouter);
router.use(pterodactylRouter);

export default router;
