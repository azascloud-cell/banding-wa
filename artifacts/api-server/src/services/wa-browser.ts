/**
 * wa-browser.ts — Puppeteer headless untuk submit banding WhatsApp
 * https://www.whatsapp.com/contact/noclient  (multi-step form)
 *
 * Env:
 *   CHROMIUM_PATH  – path ke Chrome binary
 *                    Default: Nix store Replit
 *                    Pterodactyl: /usr/bin/google-chrome atau sejenisnya
 */

import puppeteer, { type Browser, type Page, type HTTPRequest, type HTTPResponse } from "puppeteer-core";
import { writeFile } from "node:fs/promises";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";

/** Cari Chrome executable — coba urutan: env var → Pterodactyl → sistem → Nix */
function findChromePath(): string {
  // 1. Env var eksplisit
  if (process.env.CHROMIUM_PATH && existsSync(process.env.CHROMIUM_PATH)) {
    return process.env.CHROMIUM_PATH;
  }

  // 2. Kandidat umum (Pterodactyl, Ubuntu, dsb)
  const candidates = [
    "/home/container/chromium-bin",
    "/home/container/.local/bin/chromium",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/google-chrome",
    "/snap/bin/chromium",
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }

  // 3. which chromium
  try {
    const found = execSync("which chromium 2>/dev/null || which chromium-browser 2>/dev/null || which google-chrome 2>/dev/null", {
      encoding: "utf8", timeout: 2000,
    }).trim();
    if (found) return found;
  } catch { /* tidak ketemu */ }

  // 4. Nix/Replit fallback
  const nixPath =
    "/nix/store/0n9rl5l9syy808xi9bk4f6dhnfrvhkww-playwright-browsers-chromium" +
    "/chromium-1080/chrome-linux/chrome";
  if (existsSync(nixPath)) return nixPath;

  // 5. Fallback env var meskipun file tidak ada (biar error jelas)
  return process.env.CHROMIUM_PATH ?? "/usr/bin/chromium";
}

const CHROMIUM_PATH = findChromePath();

const MOBILE_UA =
  "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/120.0.6099.210 Mobile Safari/537.36";

const WA_FORM_URL = "https://www.whatsapp.com/contact/noclient";
const DEV = process.env.NODE_ENV !== "production";

// ── Types ─────────────────────────────────────────────────────
export interface BrowserSubmitParams {
  cc: string;
  number: string;
  email: string;
  description: string;
}

export interface BrowserSubmitResult {
  success: boolean;
  method: "browser";
  statusCode?: number;
  whatsappResponse?: unknown;
  capturedPayload?: unknown;
  screenshotBefore?: string;
  screenshotAfter?: string;
  stepLog?: string[];
  error?: string;
  captchaDetected?: boolean;
}

// ── Browser singleton + idle auto-close ──────────────────────
let sharedBrowser: Browser | null = null;
let idleTimer: ReturnType<typeof setTimeout> | null = null;

/** Tutup browser setelah 30 detik idle — bebaskan CPU/RAM Pterodactyl */
function scheduleIdleClose() {
  if (idleTimer) clearTimeout(idleTimer);
  idleTimer = setTimeout(async () => {
    idleTimer = null;
    await closeBrowser();
  }, 30_000);
}

// Hapus --single-process: flag ini paksa semua proses Chrome jadi satu
// sehingga V8 + renderer + GPU handler saling rebut CPU → 70%+ usage.
// Tanpa flag ini Chrome tetap headless tapi tiap proses punya budget sendiri.
const CHROME_ARGS = [
  "--no-sandbox",
  "--disable-setuid-sandbox",
  "--disable-dev-shm-usage",
  "--disable-gpu",
  "--disable-gpu-compositing",
  "--no-first-run",
  "--no-zygote",
  "--disable-extensions",
  // REMOVED: "--single-process",  ← ini penyebab CPU 70%
  "--disable-software-rasterizer",
  "--disable-features=VizDisplayCompositor,AudioServiceOutOfProcess",
  "--disable-background-networking",
  "--disable-default-apps",
  "--disable-sync",
  "--metrics-recording-only",
  "--mute-audio",
  "--no-default-browser-check",
  "--hide-scrollbars",
  "--disable-breakpad",
  "--disable-renderer-backgrounding",
  "--disable-backgrounding-occluded-windows",
  "--blink-settings=imagesEnabled=false",
];

async function getBrowser(): Promise<Browser> {
  if (sharedBrowser && sharedBrowser.connected) return sharedBrowser;
  sharedBrowser = await puppeteer.launch({
    executablePath: CHROMIUM_PATH,
    headless: true,
    args: CHROME_ARGS,
    timeout: 45_000,
    protocolTimeout: 45_000,
  });
  sharedBrowser.on("disconnected", () => { sharedBrowser = null; });
  return sharedBrowser;
}

export async function closeBrowser(): Promise<void> {
  if (idleTimer) { clearTimeout(idleTimer); idleTimer = null; }
  if (sharedBrowser) { await sharedBrowser.close().catch(() => {}); sharedBrowser = null; }
}

// ── Helpers ───────────────────────────────────────────────────
async function snap(page: Page, tag: string): Promise<string> {
  const buf = await page.screenshot({ type: "jpeg", quality: 55, encoding: "binary" });
  if (DEV) await writeFile(`/tmp/wa_${tag}_${Date.now()}.jpg`, buf).catch(() => {});
  return Buffer.from(buf).toString("base64");
}

const wait = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/** Ketik ke React controlled input — simulasi keystroke nyata */
async function typeInto(page: Page, selector: string, value: string): Promise<boolean> {
  try {
    const el = await page.$(selector);
    if (!el) return false;
    await el.click({ count: 3 });
    await wait(80);
    await page.type(selector, value, { delay: 18 });
    await page.keyboard.press("Tab");
    await wait(180);
    return true;
  } catch { return false; }
}

/**
 * Pilih country code dari picker.
 *
 * Strategi — tanpa mengandalkan tag HTML tertentu:
 *  1. Klik picker button
 *  2. Tunggu overlay muncul (lebih banyak children di body)
 *  3. Cari elemen yang textnya mengandung "+{cc}" dengan TreeWalker
 *  4. Scroll overlay ke bawah jika belum ketemu (list panjang, Y di bawah)
 *  5. Klik via dispatchEvent (tidak trigger link navigation)
 *  6. Verifikasi picker sekarang menunjuk "+{cc}"
 */
async function selectCountryCode(page: Page, cc: string, countryName: string): Promise<boolean> {
  try {
    // Step 1 — buka picker
    const opened = await page.evaluate(() => {
      const btns = Array.from(document.querySelectorAll('[role="button"]')) as HTMLElement[];
      const picker = btns.find((b) => /[A-Z]{2,3}\+\d/.test((b.textContent ?? "").trim()));
      if (!picker) return false;
      picker.click();
      return true;
    });
    if (!opened) return false;
    await wait(900);
    await snap(page, "cc_01_opened");

    // Step 2 — helper: cari elemen di overlay yang punya "+cc"
    const findAndClick = async (): Promise<boolean> => {
      return page.evaluate(({ targetCc, targetName }: { targetCc: string; targetName: string }) => {
        // Cari elemen tipis (bukan container besar) yang mengandung "+cc"
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT);
        let node: Element | null;
        while ((node = walker.nextNode() as Element | null)) {
          if (!node) break;
          const el = node as HTMLElement;
          const txt = el.textContent?.trim() ?? "";
          // Elemen item: mengandung "+cc" DAN cukup pendek (bukan container keseluruhan)
          if (
            (txt.includes(`+${targetCc}`) || txt.toLowerCase().includes(targetName)) &&
            txt.length < 70 &&
            el.children.length <= 4 &&
            el.tagName !== "BODY" &&
            el.tagName !== "HTML"
          ) {
            // Scroll ke elemen supaya visible
            el.scrollIntoView({ block: "center", behavior: "instant" });
            // Dispatch click (tidak trigger href navigation)
            el.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
            return true;
          }
        }
        return false;
      }, { targetCc: cc, targetName: countryName.toLowerCase() });
    };

    // Step 3 — coba langsung (items yang sudah di DOM)
    if (await findAndClick()) {
      await wait(400);
      await snap(page, "cc_02_selected");
      // Verifikasi
      const cur = await page.evaluate(() => {
        const btns = Array.from(document.querySelectorAll('[role="button"]')) as HTMLElement[];
        return btns.find(b => /[A-Z]{2,3}\+\d/.test((b.textContent ?? "").trim()))?.textContent?.trim() ?? "";
      });
      if (cur.includes(`+${cc}`)) return true;
    }

    // Step 4 — scroll overlay ke bawah lalu coba lagi (Yemen = huruf Y, di bawah)
    await page.evaluate(() => {
      // Cari container scrollable yang muncul setelah picker dibuka
      const scrollable = Array.from(document.querySelectorAll("*")).find((el) => {
        const s = window.getComputedStyle(el);
        return (
          (s.overflow === "auto" || s.overflowY === "auto" ||
           s.overflow === "scroll" || s.overflowY === "scroll") &&
          (el as HTMLElement).scrollHeight > (el as HTMLElement).clientHeight + 50 &&
          (el as HTMLElement).clientHeight > 100
        );
      }) as HTMLElement | undefined;
      if (scrollable) {
        scrollable.scrollTop = 999999; // scroll ke paling bawah
      }
    });
    await wait(600);
    await snap(page, "cc_03_scrolled");

    // Coba klik lagi setelah scroll
    if (await findAndClick()) {
      await wait(400);
      const cur = await page.evaluate(() => {
        const btns = Array.from(document.querySelectorAll('[role="button"]')) as HTMLElement[];
        return btns.find(b => /[A-Z]{2,3}\+\d/.test((b.textContent ?? "").trim()))?.textContent?.trim() ?? "";
      });
      if (cur.includes(`+${cc}`)) { await snap(page, "cc_04_verified"); return true; }
    }

    // Step 5 — tutup picker, lanjut dengan full number
    await page.keyboard.press("Escape");
    await wait(300);
    return false;
  } catch (e) { return false; }
}

/** Klik button primary (Next Step / Submit) — skip link navigation */
async function clickFormPrimary(page: Page): Promise<string | null> {
  return page.evaluate(() => {
    const SKIP = [
      "download", "log in", "help", "features", "blog", "apps", "about",
      "careers", "brand", "privacy", "sitemap", "twitter", "youtube",
      "instagram", "facebook", "learn more", "get whatsapp", "contact us",
      "web", "android", "iphone", "mac", "link", "logo", "channels",
      "status", "messaging", "groups", "calling", "home", "meta ai",
      "terms", "security",
    ];
    const OK = ["next", "submit", "send", "done", "continue", "kirim", "lanjut", "send question"];

    const cands = Array.from(document.querySelectorAll('button, [role="button"]')) as HTMLElement[];
    for (const el of cands) {
      if (el.tagName === "A") continue; // skip anchor links
      const txt = (el.textContent ?? "").trim().toLowerCase();
      if (
        OK.some((k) => txt.includes(k)) &&
        !SKIP.some((s) => txt.includes(s)) &&
        !(el as HTMLButtonElement).disabled &&
        el.getAttribute("aria-disabled") !== "true"
      ) {
        el.click();
        return txt;
      }
    }
    return null;
  });
}

/** Deteksi step saat ini */
async function detectStep(page: Page): Promise<string> {
  return page.evaluate(() => {
    if (document.querySelector('input[aria-label="Input phone number"]')) return "phone";
    if (document.querySelector('input[aria-label="Input email address"]')) return "email";
    if (document.querySelector('input[type="radio"][name="platform"]')) return "platform";
    if (document.querySelector("textarea")) return "description";
    const txt = document.body.innerText.toLowerCase();
    if (txt.includes("thank") || txt.includes("received") || txt.includes("success")) return "success";
    return "unknown";
  });
}

// Country code → country name (untuk search picker)
const CC_NAMES: Record<string, string> = {
  "967": "yemen", "966": "saudi arabia", "971": "emirates",
  "974": "qatar", "973": "bahrain", "968": "oman",
  "962": "jordan", "961": "lebanon", "20": "egypt",
  "62": "indonesia", "60": "malaysia", "65": "singapore",
  "91": "india", "1": "united states", "44": "united kingdom",
  "86": "china", "81": "japan", "82": "korea",
};

// ── MAIN EXPORT ───────────────────────────────────────────────
export async function submitViaBrowser(
  params: BrowserSubmitParams,
): Promise<BrowserSubmitResult> {
  let page: Page | null = null;
  let capturedPayload: unknown = null;
  const captured: { response: { status: number; body: string } | null } = { response: null };
  const stepLog: string[] = [];
  const log = (msg: string) => stepLog.push(msg);

  try {
    const browser = await getBrowser();
    page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844, isMobile: true, deviceScaleFactor: 2 });
    await page.setUserAgent(MOBILE_UA);
    await page.setExtraHTTPHeaders({ "Accept-Language": "en-US,en;q=0.9" });

    // Intercept XHR ke /contact/noclient
    await page.setRequestInterception(true);
    page.on("request", (req: HTTPRequest) => {
      if (req.url().includes("contact/noclient") && req.method() === "POST") {
        try { capturedPayload = { url: req.url(), headers: req.headers(), postData: req.postData() }; } catch {}
      }
      req.continue().catch(() => {});
    });
    page.on("response", async (resp: HTTPResponse) => {
      if (resp.url().includes("contact/noclient") && resp.request().method() === "POST") {
        captured.response = { status: resp.status(), body: await resp.text().catch(() => "") };
      }
    });

    // ── Navigate ─────────────────────────────────────────────
    log("Loading form...");
    await page.goto(WA_FORM_URL, { waitUntil: "networkidle2", timeout: 40_000 });
    await page.waitForSelector('input[aria-label="Input phone number"]', { timeout: 20_000 });
    await wait(800);
    const screenshotBefore = await snap(page, "01_form_loaded");
    log("Form ready");

    // ── Helper: isi semua field yang tersedia di halaman saat ini ──
    const fillCurrentPage = async (label: string) => {
      // Phone
      const phoneEl = await page!.$('input[aria-label="Input phone number"]');
      if (phoneEl) {
        const phoneVal = ccOk ? params.number : params.cc + params.number;
        if (!(await typeInto(page!, 'input[aria-label="Input phone number"]', phoneVal))) {
          log(`${label}: phone fill failed`);
        } else {
          log(`${label}: phone OK (${phoneVal.slice(0, 4)}***)`);
        }
      }
      // Email
      if (await page!.$('input[aria-label="Input email address"]')) {
        await typeInto(page!, 'input[aria-label="Input email address"]', params.email);
        await typeInto(page!, 'input[aria-label="Confirm email address"]', params.email);
        log(`${label}: email OK`);
      }
      // Platform radio — pilih Android
      const hasPlatform = !!(await page!.$('input[type="radio"][name="platform"]'));
      if (hasPlatform) {
        const chosen = await page!.evaluate(() => {
          const radios = Array.from(
            document.querySelectorAll('input[type="radio"][name="platform"]'),
          ) as HTMLInputElement[];
          const android = radios.find((r) =>
            (r.closest("label") ?? r.parentElement)?.textContent?.toLowerCase().includes("android"),
          );
          const target = android ?? radios[0];
          if (target) { target.click(); return target.value || "first"; }
          return null;
        });
        log(`${label}: platform = ${chosen}`);
      }
      // Textarea / description
      if (await page!.$("textarea")) {
        await typeInto(page!, "textarea", params.description);
        log(`${label}: description OK`);
      }
    };

    // ── STEP 1: CC picker + isi semua field di halaman pertama ──
    const countryName = CC_NAMES[params.cc] ?? "";
    const ccOk = await selectCountryCode(page, params.cc, countryName);
    log(`CC picker: ${ccOk ? `+${params.cc} OK` : "failed → full number"}`);

    await fillCurrentPage("page1");
    await snap(page, "02_filled");

    // ── Klik tombol utama ────────────────────────────────────
    const btn1 = await clickFormPrimary(page);
    log(`Btn1: "${btn1}"`);
    await wait(2000);
    await snap(page, "03_after_btn1");

    // ── Loop — untuk halaman berikutnya (jika multi-step) ─────
    let prevUrl = page.url();
    for (let i = 0; i < 6; i++) {
      if (captured.response) { log("XHR captured!"); break; }

      // Cek apakah halaman berubah (multi-step WA)
      const curUrl = page.url();
      const pageChanged = curUrl !== prevUrl;
      prevUrl = curUrl;

      // Deteksi konten halaman sekarang
      const pageState = await page.evaluate(() => {
        const body = document.body.innerText.toLowerCase();
        const hasPhone   = !!document.querySelector('input[aria-label="Input phone number"]');
        const hasEmail   = !!document.querySelector('input[aria-label="Input email address"]');
        const hasPlatform= !!document.querySelector('input[type="radio"][name="platform"]');
        const hasTextarea= !!document.querySelector("textarea");
        const isSuccess  = body.includes("thank") || body.includes("received") || body.includes("success");
        const hasError   = body.includes("please enter") || body.includes("required") || body.includes("invalid");
        return { hasPhone, hasEmail, hasPlatform, hasTextarea, isSuccess, hasError };
      });

      log(`[iter ${i}] url_changed=${pageChanged} state=${JSON.stringify(pageState)}`);
      await snap(page, `iter_${i}`);

      if (pageState.isSuccess) { log("Success page detected!"); break; }

      // Jika masih ada field yang perlu diisi, isi lagi
      const needsFill = pageState.hasPhone || pageState.hasEmail || pageState.hasPlatform || pageState.hasTextarea;
      if (needsFill) {
        await fillCurrentPage(`iter${i}`);
      } else {
        log(`iter ${i}: no fillable fields`);
      }

      const btn = await clickFormPrimary(page);
      log(`Btn: "${btn}"`);
      await wait(2200);

      if (!btn) {
        await page.evaluate(() =>
          (document.querySelector("form") as HTMLFormElement | null)?.requestSubmit(),
        );
        log("→ form.requestSubmit()");
        await wait(2000);
      }

      // Captcha
      const hasCaptcha = await page.evaluate(() =>
        !!document.querySelector("iframe[src*='recaptcha'], .g-recaptcha"),
      );
      if (hasCaptcha) { log("reCAPTCHA detected"); break; }

      // Jika tidak ada field dan tidak ada button → stuck
      if (!needsFill && !btn) { log("No fields + no button — stopping"); break; }
    }

    // Tunggu XHR sebentar
    if (!captured.response) {
      await new Promise<void>((resolve) => {
        const dl = setTimeout(resolve, 8_000);
        const t = setInterval(() => { if (captured.response) { clearTimeout(dl); clearInterval(t); resolve(); } }, 200);
      });
    }

    const capturedResponse = captured.response;
    const screenshotAfter = await snap(page, "final");
    log(capturedResponse ? `XHR HTTP ${capturedResponse.status}` : "XHR: none");

    let waResponse: unknown = null;
    let statusCode: number | undefined;
    if (capturedResponse) {
      statusCode = capturedResponse.status;
      // WA / Facebook prefixes response dengan "for (;;);" sebagai anti-hijacking
      const cleaned = capturedResponse.body.replace(/^for\s*\(;;\);/, "").trim();
      try { waResponse = JSON.parse(cleaned); }
      catch { waResponse = { rawText: capturedResponse.body.slice(0, 600) }; }
    }

    const captchaFinal = await page.evaluate(() =>
      !!document.querySelector("iframe[src*='recaptcha'], .g-recaptcha"),
    );

    return {
      success: !!capturedResponse && capturedResponse.status >= 200 && capturedResponse.status < 300,
      method: "browser",
      statusCode,
      whatsappResponse: waResponse,
      capturedPayload,
      screenshotBefore,
      screenshotAfter,
      stepLog,
      captchaDetected: captchaFinal,
    };
  } catch (err) {
    log(`Error: ${err instanceof Error ? err.message : String(err)}`);
    return {
      success: false,
      method: "browser",
      error: err instanceof Error ? err.message : String(err),
      capturedPayload,
      stepLog,
    };
  } finally {
    if (page) await page.close().catch(() => {});
    // Jadwalkan idle close — browser tutup otomatis 30 detik setelah request selesai
    scheduleIdleClose();
  }
}
