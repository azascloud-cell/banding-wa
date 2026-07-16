import { Router, type IRouter } from "express";
import healthRouter from "./health";
import appealRouter from "./appeal";
import tempmailRouter from "./tempmail";
import cekBioRouter from "./cek-bio";
import waSessionRouter from "./wa-session";

const router: IRouter = Router();

router.use(healthRouter);
router.use(appealRouter);
router.use(tempmailRouter);
router.use(cekBioRouter);
router.use(waSessionRouter);

export default router;
