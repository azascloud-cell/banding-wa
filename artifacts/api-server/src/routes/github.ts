import { Router, type IRouter } from "express";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);
const router: IRouter = Router();

function getGitConfig() {
  const pat = process.env.GITHUB_PAT;
  const repoUrl = process.env.GITHUB_REPO_URL;
  if (!pat || !repoUrl) {
    throw new Error("GITHUB_PAT dan GITHUB_REPO_URL belum dikonfigurasi");
  }
  // Inject PAT into URL: https://PAT@github.com/owner/repo.git
  const authedUrl = repoUrl.replace(/^https?:\/\//, `https://${pat}@`);
  return { pat, repoUrl, authedUrl };
}

/** GET /api/github/status — info repo dan branch aktif */
router.get("/github/status", async (req, res) => {
  try {
    const { repoUrl } = getGitConfig();
    const [branchRes, logRes, statusRes] = await Promise.all([
      execAsync("git branch --show-current", { cwd: process.cwd() }).catch(() => ({ stdout: "unknown" })),
      execAsync("git log -5 --oneline", { cwd: process.cwd() }).catch(() => ({ stdout: "" })),
      execAsync("git status --short", { cwd: process.cwd() }).catch(() => ({ stdout: "" })),
    ]);
    res.json({
      repoUrl,
      branch: (branchRes.stdout as string).trim(),
      recentCommits: (logRes.stdout as string).trim().split("\n").filter(Boolean),
      uncommittedChanges: (statusRes.stdout as string).trim().split("\n").filter(Boolean),
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "github/status error");
    res.status(500).json({ error: message });
  }
});

/** POST /api/github/pull — tarik perubahan terbaru dari remote */
router.post("/github/pull", async (req, res) => {
  try {
    const { authedUrl } = getGitConfig();
    const branch = (req.body as { branch?: string }).branch ?? "main";
    await execAsync(`git remote set-url origin ${authedUrl}`, { cwd: process.cwd() });
    const { stdout, stderr } = await execAsync(`git pull origin ${branch}`, { cwd: process.cwd() });
    res.json({ success: true, output: stdout + stderr });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "github/pull error");
    res.status(500).json({ error: message });
  }
});

/** POST /api/github/push — commit semua perubahan dan push ke remote */
router.post("/github/push", async (req, res) => {
  try {
    const { authedUrl } = getGitConfig();
    const body = req.body as { message?: string; branch?: string };
    const message = body.message ?? "auto: update project";
    const branch = body.branch ?? "main";

    await execAsync(`git remote set-url origin ${authedUrl}`, { cwd: process.cwd() });
    await execAsync("git add -A", { cwd: process.cwd() });
    // If nothing to commit, skip commit step
    const statusRes = await execAsync("git status --porcelain", { cwd: process.cwd() });
    let commitOutput = "Tidak ada perubahan untuk di-commit";
    if ((statusRes.stdout as string).trim()) {
      const { stdout } = await execAsync(`git commit -m "${message.replace(/"/g, '\\"')}"`, { cwd: process.cwd() });
      commitOutput = stdout;
    }
    const { stdout: pushOut, stderr: pushErr } = await execAsync(`git push origin ${branch}`, { cwd: process.cwd() });
    res.json({ success: true, commit: commitOutput, push: pushOut + pushErr });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "github/push error");
    res.status(500).json({ error: message });
  }
});

/** POST /api/github/sync — pull lalu push (sinkronisasi dua arah) */
router.post("/github/sync", async (req, res) => {
  try {
    const { authedUrl } = getGitConfig();
    const body = req.body as { message?: string; branch?: string };
    const message = body.message ?? "auto: sync project";
    const branch = body.branch ?? "main";

    await execAsync(`git remote set-url origin ${authedUrl}`, { cwd: process.cwd() });
    const pullRes = await execAsync(`git pull origin ${branch} --rebase`, { cwd: process.cwd() });
    await execAsync("git add -A", { cwd: process.cwd() });
    const statusRes = await execAsync("git status --porcelain", { cwd: process.cwd() });
    let commitOutput = "Tidak ada perubahan baru";
    if ((statusRes.stdout as string).trim()) {
      const { stdout } = await execAsync(`git commit -m "${message.replace(/"/g, '\\"')}"`, { cwd: process.cwd() });
      commitOutput = stdout;
    }
    const pushRes = await execAsync(`git push origin ${branch}`, { cwd: process.cwd() });
    res.json({
      success: true,
      pull: (pullRes.stdout as string) + pullRes.stderr,
      commit: commitOutput,
      push: (pushRes.stdout as string) + pushRes.stderr,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    req.log.error({ err }, "github/sync error");
    res.status(500).json({ error: message });
  }
});

export default router;
