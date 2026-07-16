import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/utils.dart';
import '../models/country_model.dart';
import '../models/email_model.dart';
import '../models/banding_result_model.dart';
import '../models/inbox_message_model.dart';
import '../models/history_entry_model.dart';
import '../services/temp_mail_service.dart';
import '../services/appeal_service.dart';
import '../services/history_service.dart';

enum BandingStep {
  idle,
  detectingCountry,
  creatingEmail,
  emailReady,
  submitting,
  submitDone,
  waitingReply,
  hasReply,
  noReply,
  error,
}

class BandingProvider extends ChangeNotifier {
  BandingStep _currentStep = BandingStep.idle;
  String? _rawPhone;
  String? _formattedPhone;
  CountryModel? _country;
  EmailModel? _emailData;
  AppealResult? _appealResult;
  InboxMessage? _replyMessage;
  String? _errorMessage;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 120;
  bool _isRunning = false;

  Timer? _pollingTimer;

  // Getters
  BandingStep get currentStep => _currentStep;
  String? get rawPhone => _rawPhone;
  String? get formattedPhone => _formattedPhone;
  CountryModel? get country => _country;
  EmailModel? get emailData => _emailData;
  AppealResult? get appealResult => _appealResult;
  InboxMessage? get replyMessage => _replyMessage;
  String? get errorMessage => _errorMessage;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _remainingSeconds;

  String _buildAppealText(String phone) {
    return 'Hello WhatsApp Support Team,\n\n'
        'My WhatsApp account with the number $phone has been restricted '
        'and I cannot log in because of a security message. '
        'This number is very important for my daily communication, '
        'and I always follow the Terms of Service. '
        'I believe this restriction is an error, so please review '
        'and help me restore access as soon as possible.';
  }

  Future<void> startBanding(String rawPhone) async {
    // Cegah double-start
    if (_isRunning) return;
    _isRunning = true;

    // ── PENTING: Clear data SEBELUM try-block, BUKAN di reset() ──────────
    // reset() hanya set currentStep=idle tanpa hapus data, agar
    // result screen masih bisa tampilkan data setelah user navigasi back
    _rawPhone = null;
    _formattedPhone = null;
    _country = null;
    _emailData = null;
    _appealResult = null;
    _replyMessage = null;
    _errorMessage = null;
    _elapsedSeconds = 0;
    _remainingSeconds = 120;
    // ─────────────────────────────────────────────────────────────────────

    try {
      _rawPhone = rawPhone;

      // Step 1: Deteksi negara
      _currentStep = BandingStep.detectingCountry;
      notifyListeners();

      final formatted = formatPhone(rawPhone);
      _formattedPhone = formatted;
      _country = detectCountry(formatted);
      notifyListeners();

      // Step 2: Buat email sementara
      _currentStep = BandingStep.creatingEmail;
      notifyListeners();

      try {
        _emailData = await TempMailService.createEmail();
      } catch (e) {
        _currentStep = BandingStep.error;
        _errorMessage = 'Temp Mail tidak tersedia: ${e.toString()}';
        notifyListeners();
        return;
      }

      // Step 3: Email ready
      _currentStep = BandingStep.emailReady;
      notifyListeners();

      // Step 4: Submit banding
      _currentStep = BandingStep.submitting;
      notifyListeners();

      // Simpan local copy agar aman dari null setelah async
      final phone = _formattedPhone ?? formatted;
      final email = _emailData?.email ?? '';
      final appealText = _buildAppealText(phone);

      _appealResult = await AppealService.submitAppeal(
        phone: phone,
        email: email,
        description: appealText,
      );

      // Step 5: Submit done
      _currentStep = BandingStep.submitDone;
      notifyListeners();

      // Step 6: Tunggu balasan
      _currentStep = BandingStep.waitingReply;
      notifyListeners();

      await _startPolling();
    } catch (e) {
      _currentStep = BandingStep.error;
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _startPolling() async {
    _elapsedSeconds = 0;
    _remainingSeconds = 120;

    final completer = Completer<void>();

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      // Safety: jika emailData null (di-reset saat timer sudah jalan), stop
      if (_emailData == null) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      _elapsedSeconds += 15;
      _remainingSeconds -= 15;
      notifyListeners();

      try {
        final sidToken = _emailData?.sidToken;
        if (sidToken == null || sidToken.isEmpty) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
          return;
        }

        final messages = await TempMailService.checkInbox(sidToken);

        // Re-check setelah await — state bisa berubah
        if (_emailData == null) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
          return;
        }

        if (messages.isNotEmpty) {
          _replyMessage = messages.first;
          _currentStep = BandingStep.hasReply;
          timer.cancel();
          // Simpan ke riwayat dengan ticketNumber dari email reply
          await _saveToHistory(ticketNumber: _replyMessage?.ticketNumber);
          notifyListeners();
          if (!completer.isCompleted) completer.complete();
          return;
        }
      } catch (e) {
        debugPrint('[Polling] Error: $e');
      }

      if (_elapsedSeconds >= 120) {
        _currentStep = BandingStep.noReply;
        timer.cancel();
        // Simpan ke riwayat tanpa ticketNumber (tidak ada reply)
        await _saveToHistory();
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
        return;
      }
    });

    return completer.future;
  }

  /// Simpan entry banding ke riwayat lokal (SharedPreferences)
  Future<void> _saveToHistory({String? ticketNumber}) async {
    final phone = _formattedPhone ?? _rawPhone;
    if (phone == null) return;
    final result = _appealResult;
    final rng = Random();
    final id = 'banding_${DateTime.now().millisecondsSinceEpoch}_${rng.nextInt(9999)}';
    final success = result?.success ?? false;
    final ticket = ticketNumber;

    final entry = HistoryEntry(
      id: id,
      type: 'banding',
      title: '⚖️ Banding $phone',
      subtitle: ticket != null
          ? 'Tiket #$ticket'
          : (success ? 'Terkirim' : 'Tidak ada balasan'),
      status: success ? 'success' : 'pending',
      timestamp: DateTime.now(),
      ticketNumber: ticket,
    );
    await HistoryService.add(entry);
  }

  /// Reset step ke idle TANPA menghapus data hasil banding.
  /// Data (phone, country, emailData, appealResult) tetap ada agar
  /// result screen masih bisa dibaca setelah navigasi.
  /// Data baru di-clear saat startBanding() dipanggil lagi.
  void reset() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
    _currentStep = BandingStep.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
