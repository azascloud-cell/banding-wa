import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/history_provider.dart';
import '../../models/history_entry_model.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          Consumer<HistoryProvider>(
            builder: (_, history, __) => history.entries.isEmpty
                ? const SizedBox()
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Hapus semua riwayat',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Hapus semua riwayat?'),
                          content: const Text('Tindakan ini tidak bisa dibatalkan.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Batal')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Hapus',
                                    style: TextStyle(color: AppColors.error))),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        context.read<HistoryProvider>().clear();
                      }
                    },
                  ),
          ),
        ],
      ),
      body: Consumer<HistoryProvider>(
        builder: (context, history, _) {
          if (history.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = history.entries
              .where((e) => e.title.toLowerCase().contains(_query.toLowerCase()))
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Cari riwayat...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history, color: AppColors.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty ? 'Belum ada riwayat.' : 'Tidak ada riwayat untuk "$_query".',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: entries.length,
                        itemBuilder: (context, index) =>
                            _HistoryTile(entry: entries[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasDetail = entry.resultsJson != null && entry.resultsJson!.isNotEmpty;
    return GestureDetector(
      onTap: () => context.push('/riwayat/detail', extra: entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonPurple.withOpacity(0.15)),
              child: const Icon(Icons.search_rounded,
                  color: AppColors.neonPurpleLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(entry.subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(_formatDate(entry.timestamp),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(entry.status,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.success)),
                ),
                if (hasDetail) ...[
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                ],
              ],
            ),
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
