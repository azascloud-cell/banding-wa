import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/cek_bio_models.dart';
import '../../providers/cek_bio_provider.dart';

class CekBioScanScreen extends StatefulWidget {
  const CekBioScanScreen({super.key});

  @override
  State<CekBioScanScreen> createState() => _CekBioScanScreenState();
}

class _CekBioScanScreenState extends State<CekBioScanScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final provider = context.read<CekBioProvider>();
        await provider.startScan();
        if (!mounted) return;
        if (provider.status == CekBioStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.errorMessage ?? 'Scan gagal')),
          );
          context.go('/cek-bio');
        } else {
          context.go('/cek-bio/result');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proses Scan'), automaticallyImplyLeading: false),
      body: Center(
        child: Consumer<CekBioProvider>(
          builder: (context, provider, _) {
            final percent = (provider.progress * 100).clamp(0, 100).toInt();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Memulai Scan...', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 24),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: provider.progress,
                          strokeWidth: 8,
                          backgroundColor: AppColors.divider,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonPurpleLight),
                        ),
                      ),
                      Text('$percent%', style: Theme.of(context).textTheme.displayMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Total Input : ${provider.totalInput}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  'Mohon tunggu, sedang memproses data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Jangan tutup aplikasi saat proses scan sedang berjalan',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
