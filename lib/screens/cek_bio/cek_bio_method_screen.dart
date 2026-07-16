import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/cek_bio_models.dart';
import '../../providers/cek_bio_provider.dart';
import '../../widgets/menu_card.dart';

class CekBioMethodScreen extends StatefulWidget {
  const CekBioMethodScreen({super.key});

  @override
  State<CekBioMethodScreen> createState() => _CekBioMethodScreenState();
}

class _CekBioMethodScreenState extends State<CekBioMethodScreen> {
  @override
  void initState() {
    super.initState();
    // Selalu mulai dari kondisi kosong setiap kali menu Cek Bio dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CekBioProvider>().reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cek Bio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pilih Metode Input', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text(
              'Pilih cara untuk memasukkan daftar nomor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            MenuCard(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Input Nomor',
              description: 'Ketik atau tempel daftar nomor · maks. 1000 nomor',
              onTap: () {
                context.read<CekBioProvider>().setMethod(CekBioInputMethod.nomor);
                context.push('/cek-bio/input');
              },
            ),
            const SizedBox(height: 14),
            MenuCard(
              icon: Icons.description_outlined,
              title: 'Upload File TXT',
              description: 'Upload file .txt berisi daftar nomor · maks. 1000 nomor',
              onTap: () {
                context.read<CekBioProvider>().setMethod(CekBioInputMethod.upload);
                context.push('/cek-bio/upload');
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                'Format Nomor\nSatu nomor per baris, contoh:\n628123456789\n6289876543210\n628111111111',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
