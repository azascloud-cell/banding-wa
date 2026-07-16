import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/history_provider.dart';

class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  Future<void> _confirmResetRiwayat(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Riwayat'),
        content: const Text('Semua riwayat cek bio akan dihapus permanen. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<HistoryProvider>().clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat berhasil dihapus')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionTitle('Tampilan'),
          const _SettingsTile(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Selalu aktif (default)',
            trailing: Switch(value: true, onChanged: null, activeColor: AppColors.neonPurpleLight),
          ),
          const SizedBox(height: 20),

          const _SectionTitle('WhatsApp Sender'),
          _SettingsTile(
            icon: Icons.phone_android_rounded,
            title: 'Pairing Sender',
            subtitle: 'Tautkan akun WA pengirim untuk Cek Bio',
            onTap: () => context.push('/pengaturan/sender-pairing'),
          ),
          const SizedBox(height: 20),

          const _SectionTitle('Koneksi'),
          _SettingsTile(
            icon: Icons.dns_rounded,
            title: 'Server Backend',
            subtitle: AppConstants.apiBaseUrl,
          ),
          const SizedBox(height: 20),

          const _SectionTitle('Akun'),
          const _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Informasi Akun',
            subtitle: 'AZZA USER · Free User',
          ),
          const SizedBox(height: 20),

          const _SectionTitle('Lainnya'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Tentang Aplikasi',
            onTap: () => context.push('/pengaturan/tentang'),
          ),
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            title: 'Reset Riwayat',
            titleColor: AppColors.error,
            onTap: () => _confirmResetRiwayat(context),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? titleColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: titleColor ?? AppColors.neonPurpleLight),
        title: Text(title, style: TextStyle(color: titleColor)),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textMuted) : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
