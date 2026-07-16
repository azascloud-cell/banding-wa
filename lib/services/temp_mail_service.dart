import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/email_model.dart';
import '../models/inbox_message_model.dart';

class TempMailService {
  // ── Public API ──────────────────────────────────────────────

  /// Buat email sementara via Replit proxy
  static Future<EmailModel> createEmail() async {
    final res = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/tempmail/create'))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('Proxy error: HTTP ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['error'] != null) {
      throw Exception(json['error']);
    }

    return EmailModel(
      email: json['email'] as String,
      provider: json['provider'] as String,
      sidToken: json['sidToken'] as String,
    );
  }

  /// Cek inbox via Replit proxy
  static Future<List<InboxMessage>> checkInbox(String sidToken) async {
    try {
      final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/tempmail/inbox?sidToken=${Uri.encodeQueryComponent(sidToken)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return [];

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = json['messages'] as List<dynamic>? ?? [];

      return list.map<InboxMessage>((item) {
        final m = item as Map<String, dynamic>;
        return InboxMessage(
          from: m['from'] as String? ?? 'Unknown',
          subject: m['subject'] as String? ?? '(Tanpa Subjek)',
          preview: m['preview'] as String? ?? '',
          ticketNumber: m['ticketNumber'] as String?,
        );
      }).toList();
    } catch (e) {
      print('[TempMail] ❌ checkInbox error: $e');
      return [];
    }
  }
}
