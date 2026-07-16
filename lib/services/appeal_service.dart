import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/banding_result_model.dart';

class AppealService {
  /// Submit banding ke WhatsApp Support via backend Pterodactyl.
  /// Timeout 120 detik — server perlu warm up Chrome (~30-60 detik pertama kali).
  static Future<AppealResult> submitAppeal({
    required String phone,
    required String email,
    required String description,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/appeal/submit'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'email': email,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 120)); // Naik dari 60s → 120s

      // Parse body response
      Map<String, dynamic>? bodyMap;
      try {
        bodyMap = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        bodyMap = {'rawBody': res.body};
      }

      // Error 5xx dari server kita
      if (res.statusCode >= 500) {
        return AppealResult(
          success: false,
          statusCode: res.statusCode,
          error: bodyMap['error']?.toString() ?? 'Server error ${res.statusCode}',
          serverResponse: bodyMap,
        );
      }

      final success = bodyMap['success'] as bool? ?? false;
      final waStatusCode = bodyMap['statusCode'] as int?;
      final waResponse = bodyMap['whatsappResponse'] as Map<String, dynamic>?;
      final allAttempts = bodyMap['allAttempts'] as List<dynamic>?;
      final diagnosis = bodyMap['diagnosis']?.toString();

      String? errorMsg;
      if (!success) {
        errorMsg = bodyMap['error']?.toString();
        if (errorMsg == null && waResponse != null) {
          errorMsg = waResponse['title']?.toString() ??
              waResponse['message']?.toString() ??
              waResponse['error']?.toString();
        }
        errorMsg ??= 'HTTP ${waStatusCode ?? res.statusCode}';
      }

      return AppealResult(
        success: success,
        statusCode: waStatusCode ?? res.statusCode,
        error: success ? null : errorMsg,
        diagnosis: diagnosis,
        whatsappResponse: waResponse,
        allAttempts: allAttempts,
        serverResponse: bodyMap,
      );
    } on TimeoutException {
      return const AppealResult(
        success: false,
        statusCode: 408,
        error: 'Timeout: Server sedang memproses, banding mungkin sudah terkirim. Cek email dalam 24-48 jam.',
        diagnosis: 'client_timeout',
      );
    } catch (e) {
      return AppealResult(success: false, error: e.toString());
    }
  }
}
