---
name: Chrome CPU fix
description: Why --single-process causes 70%+ CPU on Pterodactyl and how the fix works
---

## Rule
Never use `--single-process` in Puppeteer Chrome args when running on Pterodactyl (or any resource-constrained container).

**Why:** `--single-process` forces Chromium's renderer, V8, GPU handler, and network stack into one OS process. Under load they compete for the same CPU time slice, saturating the single core that Pterodactyl allocates. Without the flag, each subprocess has its own budget and the kernel can schedule them fairly.

**How to apply:** Remove the flag from CHROME_ARGS in `artifacts/api-server/src/services/wa-browser.ts` and `cek-bio.ts`. Instead, use:
- `--disable-renderer-backgrounding`
- `--disable-backgrounding-occluded-windows`
- `--blink-settings=imagesEnabled=false`

Also add an idle auto-close timer (30s) via `scheduleIdleClose()` so the browser process exits between requests instead of holding CPU while idle.
