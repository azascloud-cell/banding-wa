import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/cek_bio_models.dart';

/// Hasil satu job scan: status, progress, statistik, dan detail per nomor.
/// Diisi langsung dari respons backend — backend yang melakukan pengecekan
/// nyata ke WhatsApp (lewat sesi WhatsApp Web yang ditautkan di server).
class CekBioScanJob {
  final String jobId;
  final String status; // pending | running | done | error
  final double progress;
  final int total;
  final int processed;
  final CekBioStatistics? statistics;
  final List<CekBioNumberResult> result;
  final String? errorMessage;

  const CekBioScanJob({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.total,
    required this.processed,
    required this.statistics,
    required this.result,
    required this.errorMessage,
  });

  factory CekBioScanJob.fromJson(Map<String, dynamic> json) {
    final statsJson = json['statistics'] as Map<String, dynamic>?;
    final resultJson = json['result'] as List<dynamic>? ?? [];
    return CekBioScanJob(
      jobId: json['jobId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      total: json['total'] as int? ?? 0,
      processed: json['processed'] as int? ?? 0,
      statistics: statsJson != null ? CekBioStatistics.fromJson(statsJson) : null,
      result: resultJson
          .map((e) => CekBioNumberResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// Berbicara dengan backend Cek Bio: memulai job scan lalu melakukan polling
/// sampai selesai. Backend menautkan satu akun WhatsApp nyata (lihat
/// `/wa-session`) dan memakainya untuk mengecek nomor-nomor yang dikirim.
class CekBioService {
  CekBioService._();

  static Uri _uri(String path) => Uri.parse('${AppConstants.apiBaseUrl}$path');

  static Future<String> startScan(List<String> rawNumbers) async {
    final numbers = rawNumbers.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final response = await http.post(
      _uri('/cek-bio/scan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'numbers': numbers}),
    );

    if (response.statusCode != 202) {
      throw Exception('Gagal memulai scan (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['jobId'] as String;
  }

  static Future<CekBioScanJob> getScanStatus(String jobId) async {
    final response = await http.get(_uri('/cek-bio/scan/$jobId'));

    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil status scan (${response.statusCode}): ${response.body}');
    }

    return CekBioScanJob.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static String downloadUrl(String jobId) => '${AppConstants.apiBaseUrl}/cek-bio/scan/$jobId/download';

  /// Melakukan polling job sampai statusnya `done` atau `error`.
  static Future<CekBioScanJob> pollUntilFinished(
    String jobId, {
    required void Function(CekBioScanJob job) onProgress,
  }) async {
    while (true) {
      final job = await getScanStatus(jobId);
      onProgress(job);
      if (job.status == 'done' || job.status == 'error') {
        return job;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
