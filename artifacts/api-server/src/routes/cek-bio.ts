import { Router, type IRouter } from "express";
import { startScanJob, getJob, jobToCsv } from "../services/cek-bio.js";

const router: IRouter = Router();

/**
 * POST /cek-bio/scan
 * Body: { "numbers": ["+967737450117", "62812xxx", ...] }
 * → 202 { jobId }
 */
router.post("/cek-bio/scan", (req, res) => {
  const body = req.body as Record<string, unknown>;
  const numbers = body?.numbers;

  if (!Array.isArray(numbers) || numbers.length === 0) {
    return res.status(400).json({
      error: "Field 'numbers' harus berupa array string yang tidak kosong",
    });
  }

  const clean = numbers.filter((n) => typeof n === "string" && n.trim().length > 0);
  if (clean.length === 0) {
    return res.status(400).json({ error: "Tidak ada nomor valid di dalam array" });
  }

  const job = startScanJob(clean, req.user!.userId);
  req.log.info({ jobId: job.jobId, total: job.total, userId: req.user!.userId }, "Scan job started");

  return res.status(202).json({ jobId: job.jobId });
});

/**
 * GET /cek-bio/scan/:jobId
 * → 200 CekBioScanJob (polling)
 */
router.get("/cek-bio/scan/:jobId", (req, res) => {
  const job = getJob(req.params.jobId);
  if (!job) {
    return res.status(404).json({ error: "Job tidak ditemukan atau sudah kedaluwarsa" });
  }

  return res.json({
    jobId: job.jobId,
    status: job.status,
    progress: job.progress,
    total: job.total,
    processed: job.processed,
    statistics: job.statistics,
    result: job.result,
    errorMessage: job.errorMessage,
  });
});

/**
 * GET /cek-bio/scan/:jobId/download
 * → CSV file
 */
router.get("/cek-bio/scan/:jobId/download", (req, res) => {
  const job = getJob(req.params.jobId);
  if (!job) {
    return res.status(404).json({ error: "Job tidak ditemukan" });
  }
  if (job.status !== "done") {
    return res.status(409).json({ error: "Job belum selesai" });
  }

  const csv = jobToCsv(job);
  res.setHeader("Content-Type", "text/csv; charset=utf-8");
  res.setHeader("Content-Disposition", `attachment; filename="cekbio_${job.jobId.slice(0, 8)}.csv"`);
  return res.send(csv);
});

export default router;
