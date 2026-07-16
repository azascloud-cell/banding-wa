import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../models/cek_bio_models.dart';

/// Detail lengkap satu nomor hasil Cek Bio, diambil dari data nyata WhatsApp
/// yang dikembalikan backend. Field yang tidak tersedia dari WhatsApp
/// ditampilkan sebagai "Tidak tersedia" — tidak pernah direkayasa.
class CekBioDetailScreen extends StatelessWidget {
  final CekBioNumberResult result;

  const CekBioDetailScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(result.phone),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: result.registered
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: result.registered
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    result.registered ? Icons.check_circle : Icons.cancel,
                    color: result.registered ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.registered ? 'Terdaftar di WhatsApp' : 'Tidak terdaftar di WhatsApp',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: result.registered ? AppColors.success : AppColors.error,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InfoCard(title: 'Identitas', rows: [
              _Row('Nomor', result.phone),
              _Row('Negara', '${result.country.flag} ${result.country.name}'),
              _Row('Format valid', result.formatValid ? 'Ya' : 'Tidak'),
              _Row('Terverifikasi', result.verified ? 'Ya' : 'Tidak'),
            ]),
            const SizedBox(height: 12),
            _InfoCard(title: 'Bio', rows: [
              _Row('Bio', result.bio ?? 'Tidak tersedia'),
              _Row('Tanggal bio diatur', result.bioDate ?? 'Tidak tersedia'),
            ]),
            const SizedBox(height: 12),
            _InfoCard(title: 'Profil Bisnis', rows: [
              _Row('Akun bisnis', result.business ? 'Ya' : 'Tidak'),
              _Row('Kategori', result.category ?? 'Tidak tersedia'),
              _Row('Deskripsi', result.description ?? 'Tidak tersedia'),
              _Row('Website', result.website ?? 'Tidak tersedia'),
              _Row('Email', result.email ?? 'Tidak tersedia'),
              _Row('Alamat', result.address ?? 'Tidak tersedia'),
            ]),
            const SizedBox(height: 12),
            _InfoCard(title: 'Lainnya', rows: [
              _Row('Punya katalog', result.catalog ? 'Ya' : 'Tidak tersedia dari WhatsApp'),
              _Row('AI Agent', result.aiAgent ? 'Ya' : 'Tidak tersedia dari WhatsApp'),
              _Row('Zona waktu', result.timezone ?? 'Tidak tersedia'),
              _Row('Member sejak', result.memberSince ?? 'Tidak tersedia'),
            ]),
            if (result.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Text(
                  'Catatan: ${result.error}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_Row> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(r.value, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
