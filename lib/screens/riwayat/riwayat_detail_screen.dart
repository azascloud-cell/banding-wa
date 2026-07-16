import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../models/cek_bio_models.dart';
import '../../models/history_entry_model.dart';
import '../cek_bio/cek_bio_detail_screen.dart';

/// Tampilkan hasil scan yang disimpan di history
class RiwayatDetailScreen extends StatelessWidget {
  final HistoryEntry entry;
  const RiwayatDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final results = entry.parsedResults;
    final registered = results.where((r) => r.registered).length;
    final unregistered = results.where((r) => r.formatValid && !r.registered).length;
    final hasBio = results.where((r) => r.bio != null).length;
    final business = results.where((r) => r.business).length;
    final aiAgent = results.where((r) => r.aiAgent).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: results.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Detail hasil scan tidak tersedia.\n(Scan ini dilakukan sebelum fitur history detail diaktifkan.)',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info waktu scan
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: AppColors.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _formatDate(entry.timestamp),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Statistik
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Statistik', style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 14),
                          _StatRow(label: 'Total', value: '${results.length}'),
                          _StatRow(label: 'Nomor Aktif', value: '$registered', color: AppColors.success),
                          _StatRow(label: 'Tidak Aktif', value: '$unregistered', color: AppColors.error),
                          _StatRow(label: 'Memiliki Bio', value: '$hasBio'),
                          _StatRow(label: 'Business Meta', value: '$business'),
                          _StatRow(label: 'AI Agent', value: '$aiAgent'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tombol salin nomor aktif
                  ElevatedButton.icon(
                    onPressed: () {
                      final text = results.where((r) => r.registered).map((r) => r.phone).join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor aktif disalin ke clipboard ✓')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin Nomor Aktif'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // List nomor
                  Text('Detail Per Nomor (${results.length})',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  ...results.map((r) => GestureDetector(
                        onTap: () => context.push('/cek-bio/detail', extra: r),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                r.registered ? Icons.check_circle_outline : Icons.cancel_outlined,
                                color: r.registered ? AppColors.success : AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.phone,
                                        style: Theme.of(context).textTheme.bodyLarge),
                                    Text('${r.country.flag} ${r.country.name}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.textSecondary)),
                                    if (r.bio != null)
                                      Text(r.bio!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: AppColors.textMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} · $h:$min';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
