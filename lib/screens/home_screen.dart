import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants.dart';
import '../widgets/app_logo.dart';
import '../widgets/menu_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 84)),
              const SizedBox(height: 18),
              Text(
                'AZZA BIO X RED',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: AppColors.neonPurpleLight.withOpacity(0.6),
                          blurRadius: 18,
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'BOT CEK BIO WHATSAPP',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.neonPurpleLight,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fast • Secure • Accurate',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 32),
              ...[
                MenuCard(
                  icon: Icons.search_rounded,
                  title: AppStrings.menuCekBio,
                  description: 'Cek format nomor WhatsApp secara massal',
                  onTap: () => context.push('/cek-bio'),
                ),
                const SizedBox(height: 14),
                MenuCard(
                  icon: Icons.balance_rounded,
                  title: AppStrings.menuBanding,
                  description: 'Ajukan banding akun WhatsApp',
                  onTap: () => context.push('/banding'),
                ),
                const SizedBox(height: 14),
                MenuCard(
                  icon: Icons.bar_chart_rounded,
                  title: AppStrings.menuRiwayat,
                  description: 'Lihat riwayat aktivitas cek bio',
                  onTap: () => context.push('/riwayat'),
                ),
                const SizedBox(height: 14),
                MenuCard(
                  icon: Icons.settings_rounded,
                  title: AppStrings.menuPengaturan,
                  description: 'Kelola pengaturan aplikasi',
                  onTap: () => context.push('/pengaturan'),
                ),
              ].animate(interval: 90.ms).fadeIn(duration: 380.ms).slideY(
                    begin: 0.15,
                    end: 0,
                    duration: 380.ms,
                  ),
              const SizedBox(height: 32),
              Text(
                AppStrings.footerText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
