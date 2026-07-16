import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/constants.dart';
import '../../providers/cek_bio_provider.dart';

class CekBioUploadScreen extends StatefulWidget {
  const CekBioUploadScreen({super.key});

  @override
  State<CekBioUploadScreen> createState() => _CekBioUploadScreenState();
}

class _CekBioUploadScreenState extends State<CekBioUploadScreen> {
  String? _fileName;
  String? _error;
  bool _picking = false;

  Future<void> _pickFile() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      const typeGroup = XTypeGroup(label: 'text', extensions: ['txt']);
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        if (mounted) setState(() => _picking = false);
        return;
      }
      final content = await file.readAsString();
      if (!mounted) return;
      context.read<CekBioProvider>().setNumbersFromFile(content);
      setState(() {
        _fileName = file.name;
        _picking = false;
      });
      context.push('/cek-bio/scan');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal membaca file: $e';
        _picking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cek Bio · Upload File'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Upload File TXT', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text(
              'Upload file .txt berisi daftar nomor · maksimal 1000 nomor',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, color: AppColors.neonPurpleLight, size: 48),
                  const SizedBox(height: 12),
                  Text('Format File', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Satu nomor per baris\n628123456789\n6289876543210\n628111111111',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.neonPurple, AppColors.neonPurpleLight]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _picking ? null : _pickFile,
                icon: _picking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_fileName ?? 'Pilih File TXT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hanya file dengan ekstensi .txt',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
