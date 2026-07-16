import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../models/cek_bio_models.dart';
import '../../providers/cek_bio_provider.dart';
import '../../providers/history_provider.dart';
import '../../models/history_entry_model.dart';

class CekBioResultScreen extends StatefulWidget {
  const CekBioResultScreen({super.key});

  @override
  State<CekBioResultScreen> createState() => _CekBioResultScreenState();
}

class _CekBioResultScreenState extends State<CekBioResultScreen> {
  bool _saved = false;
  String _query = '';
  bool _exporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_saved) {
      _saved = true;
      final provider = context.read<CekBioProvider>();
      final stats = provider.statistics;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<HistoryProvider>().add(HistoryEntry(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              type: 'cek_bio',
              title: 'Cek Bio · ${provider.totalInput} nomor',
              subtitle: stats != null
                  ? '${stats.registered} aktif, ${stats.unregistered} tidak aktif'
                  : '${provider.validCount} format valid, ${provider.invalidCount} tidak valid',
              status: 'Selesai',
              timestamp: DateTime.now(),
              resultsJson: jsonEncode(
                provider.results.map((r) => {
                  'phone': r.phone,
                  'country': {'code': r.country.code, 'name': r.country.name, 'dialCode': r.country.dialCode, 'flag': r.country.flag},
                  'formatValid': r.formatValid,
                  'registered': r.registered,
                  'business': r.business,
                  'verified': r.verified,
                  'catalog': r.catalog,
                  'aiAgent': r.aiAgent,
                  'bio': r.bio,
                  'bioDate': r.bioDate,
                  'category': r.category,
                  'description': r.description,
                  'website': r.website,
                  'email': r.email,
                  'address': r.address,
                  'error': r.error,
                }).toList(),
              ),
            ));
      });
    }
  }

  Future<void> _exportTxt(List<CekBioNumberResult> results) async {
    final active = results.where((r) => r.registered).map((r) => r.phone).toList();
    if (active.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada nomor aktif untuk diekspor.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/cekbio_aktif_$ts.txt');
      await file.writeAsString(active.join('\n'), encoding: utf8);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        subject: 'Nomor WA Aktif — ${active.length} nomor',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ekspor: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Cek Bio'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Consumer<CekBioProvider>(
        builder: (context, provider, _) {
          final stats = provider.statistics;
          final filtered = _query.isEmpty
              ? provider.results
              : provider.results
                  .where((r) => r.phone.contains(_query) ||
                      r.country.name.toLowerCase().contains(_query.toLowerCase()))
                  .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Banner status ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Scan selesai — data diambil langsung dari WhatsApp',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Statistik ──────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Statistik Ringkas', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 16),
                        _StatRow(label: 'Total Input', value: '${stats?.totalInput ?? provider.totalInput}'),
                        _StatRow(label: 'Nomor Aktif', value: '${stats?.registered ?? 0}', color: AppColors.success),
                        _StatRow(label: 'Nomor Tidak Aktif', value: '${stats?.unregistered ?? 0}', color: AppColors.error),
                        _StatRow(label: 'Memiliki Bio', value: '${stats?.haveBio ?? 0}'),
                        _StatRow(label: 'Tanpa Bio', value: '${stats?.noBio ?? 0}'),
                        _StatRow(label: 'Business Meta', value: '${stats?.business ?? 0}'),
                        _StatRow(label: 'AI Agent', value: '${stats?.aiAgent ?? 0}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Detail Per Nomor ───────────────────────────────────
                Text('Detail Per Nomor', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),

                // Search bar
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Cari nomor atau negara...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Tidak ada hasil untuk "$_query"',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...filtered.map((r) => GestureDetector(
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
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.phone, style: Theme.of(context).textTheme.bodyLarge),
                                    Row(
                                      children: [
                                        Text('${r.country.flag} ${r.country.name}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: AppColors.textSecondary)),
                                        if (r.business) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('Bisnis',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(color: Colors.blue, fontSize: 10)),
                                          ),
                                        ],
                                        if (r.aiAgent) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('AI',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(color: Colors.purpleAccent, fontSize: 10)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (r.bio != null)
                                      Text(
                                        r.bio!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                            ],
                          ),
                        ),
                      )),

                const SizedBox(height: 20),

                // ── Tombol aksi ────────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: _exporting
                      ? null
                      : () => _exportTxt(provider.results),
                  icon: _exporting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_outlined),
                  label: Text(_exporting ? 'Mengekspor...' : 'Ekspor .txt Nomor Aktif',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    final active = provider.results
                        .where((r) => r.registered)
                        .map((r) => r.phone)
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: active));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nomor aktif disalin ke clipboard ✓')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin Nomor Aktif',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    context.read<CekBioProvider>().reset();
                    context.go('/');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kembali ke Home',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        },
      ),
    );
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
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
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
