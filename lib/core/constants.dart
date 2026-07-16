import 'package:flutter/material.dart';

/// URL base backend
class AppConstants {
  AppConstants._();

  /// API backend Pterodactyl — IP langsung menghindari DNS failure
  /// Server: nodeprvt.lynzzofficial.com (38.49.212.104) port 2298
  static const String apiBaseUrl = 'http://38.49.212.104:2298/api';
}

/// Warna utama aplikasi - Dark mode dengan merah dan ungu
class AppColors {
  AppColors._();

  static const Color primaryRed = Color(0xFFE53935);
  static const Color primaryPurple = Color(0xFF7B1FA2);
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF161616);
  static const Color surfaceLight = Color(0xFF232323);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF757575);
  static const Color error = Color(0xFFEF5350);
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFA726);
  static const Color divider = Color(0xFF2A2A2A);

  // Palet "cyber neon purple" — AZASTORE branding
  static const Color neonPurple = Color(0xFF7B2EFF);
  static const Color neonPurpleLight = Color(0xFFA855F7);
  static const Color neonPurpleDark = Color(0xFF5B1FBF);
  static const Color accentRed = Color(0xFFFF2D55);
  static const Color surfaceCard = Color(0xFF141414);
  static const Gradient neonGradient = LinearGradient(
    colors: [neonPurple, neonPurpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient primaryGradient = LinearGradient(
    colors: [accentRed, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// String konstan aplikasi
class AppStrings {
  AppStrings._();

  static const String appName = 'AZZA BIO X RED';
  static const String appTagline = 'BOT CEK BIO WHATSAPP';
  static const String bandingTitle = 'Banding WhatsApp';
  static const String phoneLabel = 'Nomor WhatsApp';
  static const String phoneHint = '+62812345678 atau 0812345678';
  static const String startBanding = 'Mulai Banding';
  static const String warningText =
      'Pastikan nomor benar sebelum mengajukan banding. '
      'Bot akan otomatis membuat email sementara dan mengirim banding ke WhatsApp Support.';
  static const String footerText = '© AZASTORE · Fast • Secure • Accurate';

  static const String stepDetectCountry = 'Deteksi Negara';
  static const String stepCreateEmail = 'Membuat Email Temp';
  static const String stepSubmit = 'Mengirim Banding';
  static const String stepWaitReply = 'Menunggu Balasan';

  static const String resultTitle = 'Hasil Banding';
  static const String appealTextTitle = 'Lihat Teks Banding yang Dikirim';
  static const String bandingOther = 'Banding Nomor Lain';
  static const String backHome = 'Kembali ke Home';

  static const String noConnection = 'Tidak ada koneksi internet';
  static const String serverError = 'Server tidak tersedia, coba lagi';
  static const String tempMailUnavailable = 'Temp Mail tidak tersedia';

  static const String menuBanding = 'Banding WA';
  static const String menuCekBio = 'Cek Bio';
  static const String menuRiwayat = 'Riwayat';
  static const String menuPengaturan = 'Pengaturan';
  static const String comingSoon = 'coming soon';

  static const String errorMinDigits = 'Nomor minimal 8 digit';
}
