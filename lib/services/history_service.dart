import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry_model.dart';

/// Penyimpanan riwayat lokal (di perangkat) — tidak mengirim data kemana pun.
class HistoryService {
  HistoryService._();

  static const _key = 'banding_wa_history_entries';

  static Future<List<HistoryEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => HistoryEntry.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> add(HistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
