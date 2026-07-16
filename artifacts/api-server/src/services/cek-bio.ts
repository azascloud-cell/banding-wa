/**
 * cek-bio.ts — Job-based WhatsApp number scanning
 *
 * Flow:
 *  POST /cek-bio/scan      → buat job, return jobId (202)
 *  GET  /cek-bio/scan/:id  → polling status + hasil
 *  GET  /cek-bio/scan/:id/download → CSV download
 *
 * Setiap nomor dicek via:
 *  1. Parse format internasional → dapat cc + national
 *  2. Browser check (api.whatsapp.com/send) → detected registered/not
 *  3. Return CekBioNumberResult shape yang Flutter butuhkan
 *
 * Field bio/business/verified/catalog/aiAgent = null / false karena
 * butuh sesi WhatsApp aktif (whatsapp-web.js) — rencana future upgrade.
 */

import puppeteer, { type Browser, type Page } from "puppeteer-core";
import { writeFile } from "node:fs/promises";
import https from "node:https";
import { randomUUID } from "node:crypto";
import { checkOnWhatsApp } from "./wa-baileys.js";

// ── Chromium path ─────────────────────────────────────────────
const CHROMIUM_PATH =
  process.env.CHROMIUM_PATH ||
  "/nix/store/0n9rl5l9syy808xi9bk4f6dhnfrvhkww-playwright-browsers-chromium" +
    "/chromium-1080/chrome-linux/chrome";

const MOBILE_UA =
  "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/120.0.6099.210 Mobile Safari/537.36";

const DEV = process.env.NODE_ENV !== "production";

// ── Browser singleton + idle auto-close ──────────────────────
let sharedBrowser: Browser | null = null;
let idleTimer: ReturnType<typeof setTimeout> | null = null;

function scheduleIdleClose() {
  if (idleTimer) clearTimeout(idleTimer);
  idleTimer = setTimeout(async () => {
    idleTimer = null;
    await closeBrowser();
  }, 30_000);
}

async function getBrowser(): Promise<Browser> {
  if (sharedBrowser && sharedBrowser.connected) return sharedBrowser;
  sharedBrowser = await puppeteer.launch({
    executablePath: CHROMIUM_PATH,
    headless: true,
    args: [
      "--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage",
      "--disable-gpu", "--disable-gpu-compositing", "--no-first-run", "--no-zygote",
      "--disable-extensions",
      // REMOVED: "--single-process",  ← penyebab CPU 70%
      "--disable-software-rasterizer",
      "--disable-features=VizDisplayCompositor,AudioServiceOutOfProcess",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows",
      "--blink-settings=imagesEnabled=false",
    ],
    timeout: 30_000,
  });
  sharedBrowser.on("disconnected", () => { sharedBrowser = null; });
  return sharedBrowser;
}

export async function closeBrowser(): Promise<void> {
  if (idleTimer) { clearTimeout(idleTimer); idleTimer = null; }
  if (sharedBrowser) { await sharedBrowser.close().catch(() => {}); sharedBrowser = null; }
}

// ── Country data ──────────────────────────────────────────────
interface CountryInfo {
  code: string;   // ISO 2-letter, misal "YE"
  name: string;   // nama lokal
  dialCode: string;
  flag: string;
}

/** Buat emoji bendera dari kode ISO 2 huruf */
function flagOf(iso: string): string {
  return [...iso.toUpperCase()]
    .map((c) => String.fromCodePoint(0x1f1e6 + c.charCodeAt(0) - 65))
    .join("");
}

const COUNTRIES: Array<Omit<CountryInfo, "flag">> = [
  { dialCode: "93",  code: "AF", name: "Afghanistan" },
  { dialCode: "355", code: "AL", name: "Albania" },
  { dialCode: "213", code: "DZ", name: "Aljazair" },
  { dialCode: "376", code: "AD", name: "Andorra" },
  { dialCode: "244", code: "AO", name: "Angola" },
  { dialCode: "54",  code: "AR", name: "Argentina" },
  { dialCode: "374", code: "AM", name: "Armenia" },
  { dialCode: "61",  code: "AU", name: "Australia" },
  { dialCode: "43",  code: "AT", name: "Austria" },
  { dialCode: "994", code: "AZ", name: "Azerbaijan" },
  { dialCode: "973", code: "BH", name: "Bahrain" },
  { dialCode: "880", code: "BD", name: "Bangladesh" },
  { dialCode: "375", code: "BY", name: "Belarus" },
  { dialCode: "32",  code: "BE", name: "Belgia" },
  { dialCode: "501", code: "BZ", name: "Belize" },
  { dialCode: "229", code: "BJ", name: "Benin" },
  { dialCode: "975", code: "BT", name: "Bhutan" },
  { dialCode: "591", code: "BO", name: "Bolivia" },
  { dialCode: "387", code: "BA", name: "Bosnia & Herzegovina" },
  { dialCode: "267", code: "BW", name: "Botswana" },
  { dialCode: "55",  code: "BR", name: "Brasil" },
  { dialCode: "673", code: "BN", name: "Brunei" },
  { dialCode: "359", code: "BG", name: "Bulgaria" },
  { dialCode: "226", code: "BF", name: "Burkina Faso" },
  { dialCode: "257", code: "BI", name: "Burundi" },
  { dialCode: "855", code: "KH", name: "Kamboja" },
  { dialCode: "237", code: "CM", name: "Kamerun" },
  { dialCode: "1",   code: "CA", name: "Kanada" },
  { dialCode: "238", code: "CV", name: "Tanjung Verde" },
  { dialCode: "236", code: "CF", name: "Republik Afrika Tengah" },
  { dialCode: "235", code: "TD", name: "Chad" },
  { dialCode: "56",  code: "CL", name: "Chili" },
  { dialCode: "86",  code: "CN", name: "Tiongkok" },
  { dialCode: "57",  code: "CO", name: "Kolombia" },
  { dialCode: "269", code: "KM", name: "Komoro" },
  { dialCode: "242", code: "CG", name: "Kongo" },
  { dialCode: "243", code: "CD", name: "DR Kongo" },
  { dialCode: "506", code: "CR", name: "Kosta Rika" },
  { dialCode: "225", code: "CI", name: "Pantai Gading" },
  { dialCode: "385", code: "HR", name: "Kroasia" },
  { dialCode: "53",  code: "CU", name: "Kuba" },
  { dialCode: "357", code: "CY", name: "Siprus" },
  { dialCode: "420", code: "CZ", name: "Ceko" },
  { dialCode: "45",  code: "DK", name: "Denmark" },
  { dialCode: "253", code: "DJ", name: "Djibouti" },
  { dialCode: "1",   code: "DO", name: "Republik Dominika" },
  { dialCode: "593", code: "EC", name: "Ekuador" },
  { dialCode: "20",  code: "EG", name: "Mesir" },
  { dialCode: "503", code: "SV", name: "El Salvador" },
  { dialCode: "240", code: "GQ", name: "Guinea Khatulistiwa" },
  { dialCode: "291", code: "ER", name: "Eritrea" },
  { dialCode: "372", code: "EE", name: "Estonia" },
  { dialCode: "268", code: "SZ", name: "Eswatini" },
  { dialCode: "251", code: "ET", name: "Ethiopia" },
  { dialCode: "679", code: "FJ", name: "Fiji" },
  { dialCode: "358", code: "FI", name: "Finlandia" },
  { dialCode: "33",  code: "FR", name: "Prancis" },
  { dialCode: "241", code: "GA", name: "Gabon" },
  { dialCode: "220", code: "GM", name: "Gambia" },
  { dialCode: "995", code: "GE", name: "Georgia" },
  { dialCode: "49",  code: "DE", name: "Jerman" },
  { dialCode: "233", code: "GH", name: "Ghana" },
  { dialCode: "30",  code: "GR", name: "Yunani" },
  { dialCode: "502", code: "GT", name: "Guatemala" },
  { dialCode: "224", code: "GN", name: "Guinea" },
  { dialCode: "245", code: "GW", name: "Guinea-Bissau" },
  { dialCode: "592", code: "GY", name: "Guyana" },
  { dialCode: "509", code: "HT", name: "Haiti" },
  { dialCode: "504", code: "HN", name: "Honduras" },
  { dialCode: "852", code: "HK", name: "Hong Kong" },
  { dialCode: "36",  code: "HU", name: "Hungaria" },
  { dialCode: "354", code: "IS", name: "Islandia" },
  { dialCode: "91",  code: "IN", name: "India" },
  { dialCode: "62",  code: "ID", name: "Indonesia" },
  { dialCode: "98",  code: "IR", name: "Iran" },
  { dialCode: "964", code: "IQ", name: "Irak" },
  { dialCode: "353", code: "IE", name: "Irlandia" },
  { dialCode: "972", code: "IL", name: "Israel" },
  { dialCode: "39",  code: "IT", name: "Italia" },
  { dialCode: "1",   code: "JM", name: "Jamaika" },
  { dialCode: "81",  code: "JP", name: "Jepang" },
  { dialCode: "962", code: "JO", name: "Yordania" },
  { dialCode: "7",   code: "KZ", name: "Kazakhstan" },
  { dialCode: "254", code: "KE", name: "Kenya" },
  { dialCode: "686", code: "KI", name: "Kiribati" },
  { dialCode: "850", code: "KP", name: "Korea Utara" },
  { dialCode: "82",  code: "KR", name: "Korea Selatan" },
  { dialCode: "965", code: "KW", name: "Kuwait" },
  { dialCode: "996", code: "KG", name: "Kyrgyzstan" },
  { dialCode: "856", code: "LA", name: "Laos" },
  { dialCode: "371", code: "LV", name: "Latvia" },
  { dialCode: "961", code: "LB", name: "Lebanon" },
  { dialCode: "266", code: "LS", name: "Lesotho" },
  { dialCode: "231", code: "LR", name: "Liberia" },
  { dialCode: "218", code: "LY", name: "Libya" },
  { dialCode: "423", code: "LI", name: "Liechtenstein" },
  { dialCode: "370", code: "LT", name: "Lituania" },
  { dialCode: "352", code: "LU", name: "Luksemburg" },
  { dialCode: "853", code: "MO", name: "Makau" },
  { dialCode: "261", code: "MG", name: "Madagaskar" },
  { dialCode: "265", code: "MW", name: "Malawi" },
  { dialCode: "60",  code: "MY", name: "Malaysia" },
  { dialCode: "960", code: "MV", name: "Maladewa" },
  { dialCode: "223", code: "ML", name: "Mali" },
  { dialCode: "356", code: "MT", name: "Malta" },
  { dialCode: "692", code: "MH", name: "Kepulauan Marshall" },
  { dialCode: "222", code: "MR", name: "Mauritania" },
  { dialCode: "230", code: "MU", name: "Mauritius" },
  { dialCode: "52",  code: "MX", name: "Meksiko" },
  { dialCode: "691", code: "FM", name: "Mikronesia" },
  { dialCode: "373", code: "MD", name: "Moldova" },
  { dialCode: "377", code: "MC", name: "Monako" },
  { dialCode: "976", code: "MN", name: "Mongolia" },
  { dialCode: "382", code: "ME", name: "Montenegro" },
  { dialCode: "212", code: "MA", name: "Maroko" },
  { dialCode: "258", code: "MZ", name: "Mozambik" },
  { dialCode: "95",  code: "MM", name: "Myanmar" },
  { dialCode: "264", code: "NA", name: "Namibia" },
  { dialCode: "674", code: "NR", name: "Nauru" },
  { dialCode: "977", code: "NP", name: "Nepal" },
  { dialCode: "31",  code: "NL", name: "Belanda" },
  { dialCode: "64",  code: "NZ", name: "Selandia Baru" },
  { dialCode: "505", code: "NI", name: "Nikaragua" },
  { dialCode: "227", code: "NE", name: "Niger" },
  { dialCode: "234", code: "NG", name: "Nigeria" },
  { dialCode: "389", code: "MK", name: "Makedonia Utara" },
  { dialCode: "47",  code: "NO", name: "Norwegia" },
  { dialCode: "968", code: "OM", name: "Oman" },
  { dialCode: "92",  code: "PK", name: "Pakistan" },
  { dialCode: "680", code: "PW", name: "Palau" },
  { dialCode: "970", code: "PS", name: "Palestina" },
  { dialCode: "507", code: "PA", name: "Panama" },
  { dialCode: "675", code: "PG", name: "Papua Nugini" },
  { dialCode: "595", code: "PY", name: "Paraguay" },
  { dialCode: "51",  code: "PE", name: "Peru" },
  { dialCode: "63",  code: "PH", name: "Filipina" },
  { dialCode: "48",  code: "PL", name: "Polandia" },
  { dialCode: "351", code: "PT", name: "Portugal" },
  { dialCode: "974", code: "QA", name: "Qatar" },
  { dialCode: "40",  code: "RO", name: "Rumania" },
  { dialCode: "7",   code: "RU", name: "Rusia" },
  { dialCode: "250", code: "RW", name: "Rwanda" },
  { dialCode: "966", code: "SA", name: "Arab Saudi" },
  { dialCode: "221", code: "SN", name: "Senegal" },
  { dialCode: "381", code: "RS", name: "Serbia" },
  { dialCode: "232", code: "SL", name: "Sierra Leone" },
  { dialCode: "65",  code: "SG", name: "Singapura" },
  { dialCode: "421", code: "SK", name: "Slovakia" },
  { dialCode: "386", code: "SI", name: "Slovenia" },
  { dialCode: "677", code: "SB", name: "Kepulauan Solomon" },
  { dialCode: "252", code: "SO", name: "Somalia" },
  { dialCode: "27",  code: "ZA", name: "Afrika Selatan" },
  { dialCode: "211", code: "SS", name: "Sudan Selatan" },
  { dialCode: "34",  code: "ES", name: "Spanyol" },
  { dialCode: "94",  code: "LK", name: "Sri Lanka" },
  { dialCode: "249", code: "SD", name: "Sudan" },
  { dialCode: "597", code: "SR", name: "Suriname" },
  { dialCode: "46",  code: "SE", name: "Swedia" },
  { dialCode: "41",  code: "CH", name: "Swiss" },
  { dialCode: "963", code: "SY", name: "Suriah" },
  { dialCode: "886", code: "TW", name: "Taiwan" },
  { dialCode: "992", code: "TJ", name: "Tajikistan" },
  { dialCode: "255", code: "TZ", name: "Tanzania" },
  { dialCode: "66",  code: "TH", name: "Thailand" },
  { dialCode: "670", code: "TL", name: "Timor-Leste" },
  { dialCode: "228", code: "TG", name: "Togo" },
  { dialCode: "676", code: "TO", name: "Tonga" },
  { dialCode: "1",   code: "TT", name: "Trinidad & Tobago" },
  { dialCode: "216", code: "TN", name: "Tunisia" },
  { dialCode: "90",  code: "TR", name: "Türkiye" },
  { dialCode: "993", code: "TM", name: "Turkmenistan" },
  { dialCode: "688", code: "TV", name: "Tuvalu" },
  { dialCode: "256", code: "UG", name: "Uganda" },
  { dialCode: "380", code: "UA", name: "Ukraina" },
  { dialCode: "971", code: "AE", name: "Uni Emirat Arab" },
  { dialCode: "44",  code: "GB", name: "Inggris" },
  { dialCode: "1",   code: "US", name: "Amerika Serikat" },
  { dialCode: "598", code: "UY", name: "Uruguay" },
  { dialCode: "998", code: "UZ", name: "Uzbekistan" },
  { dialCode: "678", code: "VU", name: "Vanuatu" },
  { dialCode: "58",  code: "VE", name: "Venezuela" },
  { dialCode: "84",  code: "VN", name: "Vietnam" },
  { dialCode: "967", code: "YE", name: "Yaman" },
  { dialCode: "260", code: "ZM", name: "Zambia" },
  { dialCode: "263", code: "ZW", name: "Zimbabwe" },
];

// Build lookup maps
const BY_DIALCODE = new Map<string, CountryInfo>();
for (const c of COUNTRIES) {
  const info: CountryInfo = { ...c, flag: flagOf(c.code) };
  // Prefer lebih panjang (misal 967 vs 9)
  if (!BY_DIALCODE.has(c.dialCode)) BY_DIALCODE.set(c.dialCode, info);
}

// Priority dial codes (3-digit first, then 2, then 1)
const DC3 = COUNTRIES.filter((c) => c.dialCode.length === 3).map((c) => c.dialCode);
const DC2 = COUNTRIES.filter((c) => c.dialCode.length === 2).map((c) => c.dialCode);
const DC1 = COUNTRIES.filter((c) => c.dialCode.length === 1).map((c) => c.dialCode);

function parsePhone(raw: string): { dialCode: string; national: string; e164: string; country: CountryInfo } | null {
  const digits = raw.replace(/\D/g, "");
  if (digits.length < 7 || digits.length > 15) return null;

  for (const dc of DC3) {
    if (digits.startsWith(dc)) {
      const country = BY_DIALCODE.get(dc);
      if (country) return { dialCode: dc, national: digits.slice(dc.length), e164: `+${digits}`, country };
    }
  }
  for (const dc of DC2) {
    if (digits.startsWith(dc)) {
      const country = BY_DIALCODE.get(dc);
      if (country) return { dialCode: dc, national: digits.slice(dc.length), e164: `+${digits}`, country };
    }
  }
  for (const dc of DC1) {
    if (digits.startsWith(dc)) {
      const country = BY_DIALCODE.get(dc) ?? { code: "US", name: "Amerika Serikat", dialCode: "1", flag: "🇺🇸" };
      return { dialCode: dc, national: digits.slice(dc.length), e164: `+${digits}`, country };
    }
  }
  return null;
}

// ── Types (Flutter-compatible) ────────────────────────────────
export interface CountryJson {
  code: string;
  name: string;
  dialCode: string;
  flag: string;
}

export interface NumberResult {
  phone: string;
  country: CountryJson;
  formatValid: boolean;
  registered: boolean;
  business: boolean;
  verified: boolean;
  catalog: boolean;
  aiAgent: boolean;
  bio: string | null;
  bioDate: string | null;
  category: string | null;
  description: string | null;
  website: string | null;
  email: string | null;
  address: string | null;
  timezone: string | null;
  memberSince: string | null;
  cover: string | null;
  error: string | null;
}

export interface ScanStatistics {
  totalInput: number;
  valid: number;
  invalid: number;
  registered: number;
  unregistered: number;
  haveBio: number;
  noBio: number;
  business: number;
  aiAgent: number;
}

export interface ScanJob {
  jobId: string;
  status: "pending" | "running" | "done" | "error";
  progress: number;
  total: number;
  processed: number;
  statistics: ScanStatistics;
  result: NumberResult[];
  errorMessage: string | null;
  numbers: string[]; // input awal (untuk download)
  createdAt: number;
}

// ── In-memory job store ───────────────────────────────────────
const JOBS = new Map<string, ScanJob>();
const JOB_TTL_MS = 30 * 60 * 1000; // hapus setelah 30 menit

function cleanOldJobs() {
  const now = Date.now();
  for (const [id, job] of JOBS.entries()) {
    if (now - job.createdAt > JOB_TTL_MS) JOBS.delete(id);
  }
}

// Semaphore — batasi concurrent browser page ke 1
let browserBusy = false;
const browserQueue: Array<() => void> = [];

async function withBrowser<T>(fn: (page: Page) => Promise<T>): Promise<T> {
  // Tunggu giliran
  if (browserBusy) {
    await new Promise<void>((resolve) => browserQueue.push(resolve));
  }
  browserBusy = true;

  let page: Page | null = null;
  try {
    const browser = await getBrowser();
    page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844, isMobile: true });
    await page.setUserAgent(MOBILE_UA);
    await page.setExtraHTTPHeaders({ "Accept-Language": "en-US,en;q=0.9" });
    return await fn(page);
  } finally {
    if (page) await page.close().catch(() => {});
    browserBusy = false;
    const next = browserQueue.shift();
    if (next) next();
  }
}

// ── Check satu nomor — Baileys dulu, browser sebagai fallback ─
async function checkNumber(raw: string, baileysResult?: boolean): Promise<NumberResult> {
  const parsed = parsePhone(raw.trim());

  if (!parsed) {
    return {
      phone: raw.trim(),
      country: { code: "??", name: "Tidak diketahui", dialCode: "", flag: "🏳️" },
      formatValid: false,
      registered: false,
      business: false, verified: false, catalog: false, aiAgent: false,
      bio: null, bioDate: null, category: null, description: null,
      website: null, email: null, address: null, timezone: null,
      memberSince: null, cover: null,
      error: "Format nomor tidak valid",
    };
  }

  const fullNumber = parsed.dialCode + parsed.national;

  // ── Baileys path: jika sesi aktif, pakai hasilnya langsung ──
  if (baileysResult !== undefined) {
    return {
      phone: parsed.e164,
      country: {
        code: parsed.country.code,
        name: parsed.country.name,
        dialCode: parsed.country.dialCode,
        flag: parsed.country.flag,
      },
      formatValid: true,
      registered: baileysResult,
      business: false,
      verified: false,
      catalog: false,
      aiAgent: false,
      bio: null,
      bioDate: null,
      category: null,
      description: null,
      website: null,
      email: null,
      address: null,
      timezone: null,
      memberSince: null,
      cover: null,
      error: null,
    };
  }

  // ── Browser fallback: jika tidak ada sesi Baileys aktif ─────
  try {
    const isRegistered = await withBrowser(async (page) => {
      const url = `https://api.whatsapp.com/send?phone=${fullNumber}&source=demopage`;
      await page.goto(url, { waitUntil: "networkidle2", timeout: 22_000 });
      await new Promise<void>((r) => setTimeout(r, 1500));

      if (DEV) {
        const buf = await page.screenshot({ type: "jpeg", quality: 50, encoding: "binary" });
        await writeFile(`/tmp/cb_${fullNumber}_${Date.now()}.jpg`, buf).catch(() => {});
      }

      return page.evaluate(() => {
        const body = document.body.innerText.toLowerCase();
        const url = window.location.href.toLowerCase();
        const notRegistered = [
          "is not on whatsapp",
          "phone number shared",
          "invalid phone number",
          "not a valid phone",
        ].some((s) => body.includes(s));

        const likely = [
          "open whatsapp",
          "send message",
          "chat with",
          "web.whatsapp.com",
          "click here to start",
          "continue to chat",
        ].some((s) => body.includes(s) || url.includes(s));

        if (notRegistered) return false;
        if (likely) return true;
        // Cek link "open whatsapp" atau intent
        const hasWaLink = !!document.querySelector(
          '[href*="whatsapp"], [href*="intent://"], [data-action*="open"]',
        );
        return hasWaLink ? true : null;
      });
    });

    return {
      phone: parsed.e164,
      country: {
        code: parsed.country.code,
        name: parsed.country.name,
        dialCode: parsed.country.dialCode,
        flag: parsed.country.flag,
      },
      formatValid: true,
      registered: isRegistered === true,
      business: false,
      verified: false,
      catalog: false,
      aiAgent: false,
      bio: null,
      bioDate: null,
      category: null,
      description: null,
      website: null,
      email: null,
      address: null,
      timezone: null,
      memberSince: null,
      cover: null,
      error: isRegistered === null ? "Status tidak dapat ditentukan" : null,
    };
  } catch (err) {
    return {
      phone: parsed.e164,
      country: {
        code: parsed.country.code,
        name: parsed.country.name,
        dialCode: parsed.country.dialCode,
        flag: parsed.country.flag,
      },
      formatValid: true,
      registered: false,
      business: false, verified: false, catalog: false, aiAgent: false,
      bio: null, bioDate: null, category: null, description: null,
      website: null, email: null, address: null, timezone: null,
      memberSince: null, cover: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

// ── Hitung statistik dari result array ────────────────────────
function calcStats(results: NumberResult[], total: number): ScanStatistics {
  const valid = results.filter((r) => r.formatValid).length;
  const registered = results.filter((r) => r.registered).length;
  const haveBio = results.filter((r) => r.bio !== null).length;
  const business = results.filter((r) => r.business).length;
  const aiAgent = results.filter((r) => r.aiAgent).length;
  return {
    totalInput: total,
    valid,
    invalid: total - valid,
    registered,
    unregistered: valid - registered,
    haveBio,
    noBio: valid - haveBio,
    business,
    aiAgent,
  };
}

// ── Public: buat dan jalankan job ─────────────────────────────
export function getJob(jobId: string): ScanJob | undefined {
  return JOBS.get(jobId);
}

const MAX_NUMBERS = 100;

export function startScanJob(rawNumbers: string[], userId: number): ScanJob {
  cleanOldJobs();

  const numbers = rawNumbers
    .map((n) => n.trim())
    .filter((n) => n.length > 0)
    .slice(0, MAX_NUMBERS);

  const jobId = randomUUID();
  const job: ScanJob = {
    jobId,
    status: "pending",
    progress: 0,
    total: numbers.length,
    processed: 0,
    statistics: calcStats([], numbers.length),
    result: [],
    errorMessage: null,
    numbers,
    createdAt: Date.now(),
  };
  JOBS.set(jobId, job);

  // Jalankan di background (tidak di-await)
  void runJob(job, userId);

  return job;
}

async function runJob(job: ScanJob, userId: number): Promise<void> {
  job.status = "running";
  try {
    // ── Batch check via Baileys (jika sesi WA aktif) ─────────
    // Parse semua nomor valid dulu
    const parsedMap = new Map<string, ReturnType<typeof parsePhone>>();
    for (const raw of job.numbers) {
      const p = parsePhone(raw.trim());
      if (p) parsedMap.set(raw.trim(), p);
    }

    // Kumpulkan e164 list (tanpa +) untuk Baileys
    const e164List = [...parsedMap.values()].map((p) => p!.dialCode + p!.national);
    const baileysMap = await checkOnWhatsApp(userId, e164List).catch(() => new Map<string, boolean>());

    // ── Loop per nomor ────────────────────────────────────────
    for (let i = 0; i < job.numbers.length; i++) {
      const raw = job.numbers[i];
      const parsed = parsedMap.get(raw.trim());
      let baileysResult: boolean | undefined;

      if (parsed && baileysMap.size > 0) {
        baileysResult = baileysMap.get(parsed.dialCode + parsed.national);
      }

      const numResult = await checkNumber(raw, baileysResult);
      job.result.push(numResult);
      job.processed = i + 1;
      job.progress = job.processed / job.total;
      job.statistics = calcStats(job.result, job.total);
    }
    job.status = "done";
    job.progress = 1;
  } catch (err) {
    job.status = "error";
    job.errorMessage = err instanceof Error ? err.message : String(err);
  } finally {
    // Tutup browser 30 detik setelah job selesai — bebaskan CPU Pterodactyl
    scheduleIdleClose();
  }
}

// ── CSV export ────────────────────────────────────────────────
export function jobToCsv(job: ScanJob): string {
  const header = [
    "phone", "country", "dialCode", "formatValid",
    "registered", "business", "verified", "bio", "error",
  ].join(",");

  const rows = job.result.map((r) => [
    r.phone,
    `"${r.country.name}"`,
    r.country.dialCode,
    r.formatValid,
    r.registered,
    r.business,
    r.verified,
    r.bio ? `"${r.bio.replace(/"/g, '""')}"` : "",
    r.error ? `"${r.error.replace(/"/g, '""')}"` : "",
  ].join(","));

  return [header, ...rows].join("\r\n");
}
