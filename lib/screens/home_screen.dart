import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/menu_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row: logo kiri, logout kanan
              Row(
                children: [
                  const Spacer(),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
                    tooltip: 'Keluar',
                    onPressed: () => auth.logout(),
                  ),
                ],
              ),

              // Logo + title
              Center(
                child: Column(
                  children: [
                    const AppLogo(size: 100),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.textPrimary, AppColors.neonPurpleLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'AZZA BIO X RED',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'BOT CEK BIO WHATSAPP',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: AppColors.neonPurpleLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (auth.user != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.neonPurple.withOpacity(0.4)),
                          color: AppColors.neonPurple.withOpacity(0.08),
                        ),
                        child: Text(
                          'Halo, ${auth.user!.username}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.neonPurpleLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Divider dekoratif
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, AppColors.neonPurple.withOpacity(0.5)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neonPurple,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.neonPurple.withOpacity(0.5), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Menu cards
              ...[
                MenuCard(
                  icon: Icons.search_rounded,
                  title: AppStrings.menuCekBio,
                  description: 'Cek format nomor WhatsApp secara massal',
                  onTap: () => context.push('/cek-bio'),
                ),
                const SizedBox(height: 12),
                MenuCard(
                  icon: Icons.balance_rounded,
                  title: AppStrings.menuBanding,
                  description: 'Ajukan banding akun WhatsApp',
                  onTap: () => context.push('/banding'),
                ),
                const SizedBox(height: 12),
                MenuCard(
                  icon: Icons.bar_chart_rounded,
                  title: AppStrings.menuRiwayat,
                  description: 'Lihat riwayat aktivitas cek bio',
                  onTap: () => context.push('/riwayat'),
                ),
                const SizedBox(height: 12),
                MenuCard(
                  icon: Icons.settings_rounded,
                  title: AppStrings.menuPengaturan,
                  description: 'Kelola pengaturan aplikasi',
                  onTap: () => context.push('/pengaturan'),
                ),
              ].animate(interval: 80.ms).fadeIn(duration: 350.ms).slideY(
                    begin: 0.12,
                    end: 0,
                    duration: 350.ms,
                  ),

              const SizedBox(height: 36),

              // Footer
              const Text(
                AppStrings.footerText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
