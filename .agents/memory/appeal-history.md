---
name: Appeal history + ticket number parsing
description: How ticket numbers are parsed and how appeal history flows from server to Flutter
---

## Ticket number parsing
- Subject format: `"WhatsApp Support 4524970751159007"` (or with "Re:" prefix)
- Regex in `artifacts/api-server/src/routes/tempmail.ts`: `/WhatsApp\s+Support\s+(\d{6,20})/i`
- Returned as `ticketNumber: string | null` in each inbox message object
- Flutter `InboxMessage` model has optional `ticketNumber` field
- `TempMailService.checkInbox()` maps `m['ticketNumber']` into the model

## Appeal history store
- Server-side: `artifacts/api-server/src/lib/appeal-history.ts` — in-memory, max 200 entries (FIFO), resets on restart
- Endpoint: `GET /api/appeal/history` → `{ history: AppealHistoryEntry[] }`
- Each entry includes: id, phone (masked, last 4 digits visible), email, timestamp, success, statusCode, diagnosis, ticketNumber
- `ticketNumber` is NOT set at submit time (no reply yet); it's only added when Flutter gets the email reply

## Flutter side
- `HistoryEntry` has `ticketNumber?: String` — persisted in SharedPreferences
- `BandingProvider._saveToHistory()` called when polling ends (hasReply or noReply)
- ticketNumber from `_replyMessage?.ticketNumber` passed into history entry
- `BandingResultScreen` shows 🎫 No. Tiket row if ticketNumber is non-null
