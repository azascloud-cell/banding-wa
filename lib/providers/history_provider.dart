import 'package:flutter/material.dart';
import '../models/history_entry_model.dart';
import '../services/history_service.dart';

class HistoryProvider extends ChangeNotifier {
  List<HistoryEntry> _entries = [];
  bool _loading = true;

  List<HistoryEntry> get entries {
    final sorted = [..._entries];
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _entries = await HistoryService.loadAll();
    _loading = false;
    notifyListeners();
  }

  Future<void> add(HistoryEntry entry) async {
    await HistoryService.add(entry);
    _entries = [..._entries, entry];
    notifyListeners();
  }

  Future<void> clear() async {
    await HistoryService.clear();
    _entries = [];
    notifyListeners();
  }
}
