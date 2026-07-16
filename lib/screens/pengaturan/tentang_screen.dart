import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../widgets/app_logo.dart';

class TentangScreen extends StatelessWidget {
  const TentangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 88),
              const SizedBox(height: 20),
              Text('AZZA BIO X RED', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 4),
              Text(
                'BOT CEK BIO WHATSAPP',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neonPurpleLight),
              ),
              const SizedBox(height: 24),
              const _InfoLine(label: 'Versi', value: '1.0.0'),
              const _InfoLine(label: 'Developer', value: 'AZASTORE'),
              const SizedBox(height: 24),
              Text(
                'Aplikasi untuk cek format nomor WhatsApp dan mengajukan banding akun dengan mudah.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              Text('© AZASTORE', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
              Text('Fast • Secure • Accurate', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
