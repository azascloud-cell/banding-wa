class AppealResult {
  final bool success;
  final int? statusCode;
  final String? error;

  /// Diagnosis penyebab error (dari server)
  final String? diagnosis;

  /// Body JSON dari WhatsApp (sudah diparse, bersih — bukan HTML mentah)
  final Map<String, dynamic>? whatsappResponse;

  /// Semua variasi request yang dicoba (untuk debug lanjut)
  final List<dynamic>? allAttempts;

  /// Full response dari proxy server kita
  final Map<String, dynamic>? serverResponse;

  const AppealResult({
    required this.success,
    this.statusCode,
    this.error,
    this.diagnosis,
    this.whatsappResponse,
    this.allAttempts,
    this.serverResponse,
  });

  /// Pesan error ringkas untuk ditampilkan
  String get errorSummary {
    if (success) return 'Berhasil';
    if (error != null && error!.isNotEmpty) return error!;
    if (statusCode != null) return 'HTTP $statusCode';
    return 'Error tidak diketahui';
  }

  @override
  String toString() =>
      'AppealResult(success: $success, statusCode: $statusCode, error: $error)';
}
