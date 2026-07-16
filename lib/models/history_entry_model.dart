import 'dart:convert';
import '../models/cek_bio_models.dart';

class HistoryEntry {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String status;
  final DateTime timestamp;
  // Hasil scan lengkap (JSON string) — null jika entry lama sebelum fitur ini
  final String? resultsJson;
  /// Nomor tiket WA support dari email reply (format: "4524970751159007")
  final String? ticketNumber;

  const HistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.timestamp,
    this.resultsJson,
    this.ticketNumber,
  });

  /// Parse hasil scan kembali ke list — kosong jika tidak ada / parse gagal
  List<CekBioNumberResult> get parsedResults {
    if (resultsJson == null) return [];
    try {
      final list = jsonDecode(resultsJson!) as List<dynamic>;
      return list
          .map((e) => CekBioNumberResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        if (resultsJson != null) 'resultsJson': resultsJson,
        if (ticketNumber != null) 'ticketNumber': ticketNumber,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        status: json['status'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        resultsJson: json['resultsJson'] as String?,
        ticketNumber: json['ticketNumber'] as String?,
      );
}
