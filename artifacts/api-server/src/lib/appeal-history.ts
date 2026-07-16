/**
 * appeal-history.ts — In-memory store untuk riwayat banding WA
 *
 * Disimpan di RAM (tidak persisten antar restart). Flutter app menyimpan
 * salinannya sendiri via SharedPreferences — ini hanya referensi server-side.
 * Max 200 entri (FIFO) agar tidak bloat memory di Pterodactyl.
 */

export interface AppealHistoryEntry {
  id: string;
  phone: string;         // format +CCNUMBER, 4 digit terakhir saja
  email: string;
  timestamp: string;     // ISO 8601
  success: boolean;
  statusCode?: number;
  diagnosis?: string;
  ticketNumber?: string; // dari email reply "WhatsApp Support XXXX"
}

const MAX_ENTRIES = 200;
const history: AppealHistoryEntry[] = [];

export function addAppealHistory(entry: Omit<AppealHistoryEntry, "id">): AppealHistoryEntry {
  const id = `appeal_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const full: AppealHistoryEntry = { id, ...entry };
  history.unshift(full); // terbaru di depan
  if (history.length > MAX_ENTRIES) history.splice(MAX_ENTRIES);
  return full;
}

export function getAppealHistory(): AppealHistoryEntry[] {
  return [...history];
}

export function clearAppealHistory(): void {
  history.splice(0, history.length);
}
