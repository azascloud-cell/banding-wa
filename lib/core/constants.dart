import 'package:flutter/material.dart';

/// URL base backend
class AppConstants {
  AppConstants._();

  /// API backend Pterodactyl — ganti ke URL server Pterodactyl kamu
  static const String apiBaseUrl =
      'https://98a65abf-af04-4c11-ab74-063dbe8fd7eb-00-10v1sy4mg0x7x.sisko.replit.dev/api';
}

/// Warna utama aplikasi - Dark mode dengan merah dan ungu
class AppColors {
  AppColors._();

  static const Color primaryRed = Color(0xFFE53935);
  static const Color primaryPurple = Color(0xFF7B1FA2);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2C2C2C);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF757575);
  static const Color error = Color(0xFFEF5350);
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFA726);
  static const Color divider = Color(0xFF323232);

  // Palet "cyber neon purple"
  static const Color neonPurple = Color(0xFF7B2EFF);
  static const Color neonPurpleLight = Color(0xFFA855F7);
  static const Color surfaceCard = Color(0xFF181818);
  static const Gradient neonGradient = LinearGradient(
    colors: [neonPurple, neonPurpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryRed, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// String konstan aplikasi
class AppStrings {
  AppStrings._();

  static const String appName = 'AZZA BIO X RED';
  static const String bandingTitle = '⚖️ Banding WhatsApp';
  static const String phoneLabel = 'Nomor WhatsApp';
  static const String phoneHint = '+62812345678 atau 0812345678';
  static const String startBanding = 'Mulai Banding 🚀';
  static const String warningText =
      '⚠️ Pastikan nomor benar sebelum mengajukan banding. '
      'Bot akan otomatis membuat email sementara dan mengirim banding ke WhatsApp Support.';
  static const String footerText = '© AZASTORE · Fast • Secure • Accurate';

  static const String stepDetectCountry = '🔍 Deteksi Negara';
  static const String stepCreateEmail = '📧 Membuat Email Temp';
  static const String stepSubmit = '📤 Mengirim Banding';
  static const String stepWaitReply = '⏳ Menunggu Balasan';

  static const String resultTitle = 'Hasil Banding';
  static const String appealTextTitle = '📝 Lihat Teks Banding yang Dikirim';
  static const String bandingOther = '🔁 Banding Nomor Lain';
  static const String backHome = '🏠 Kembali ke Home';

  static const String noConnection = 'Tidak ada koneksi internet';
  static const String serverError = 'Server tidak tersedia, coba lagi';
  static const String tempMailUnavailable = 'Temp Mail tidak tersedia';

  static const String menuBanding = '⚖️ Banding WA';
  static const String menuCekBio = '🔍 Cek Bio';
  static const String menuRiwayat = '📊 Riwayat';
  static const String menuPengaturan = '⚙️ Pengaturan';
  static const String comingSoon = 'coming soon';

  static const String errorMinDigits = 'Nomor minimal 8 digit';
}
