import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../providers/banding_provider.dart';

class BandingResultScreen extends StatelessWidget {
  const BandingResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.resultTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<BandingProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, provider),
                const SizedBox(height: 24),
                _buildSummaryCard(context, provider),
                const SizedBox(height: 16),
                if (!(provider.appealResult?.success ?? true)) ...[
                  _buildErrorDetailCard(context, provider),
                  const SizedBox(height: 16),
                ],
                _buildReplySection(context, provider),
                const SizedBox(height: 16),
                _buildAppealTextSection(context, provider),
                const SizedBox(height: 32),
                _buildActionButtons(context, provider),
              ]
                  .animate(interval: 80.ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, end: 0, duration: 350.ms),
            ),
          );
        },
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, BandingProvider p) {
    final ok = p.appealResult?.success == true;
    return Column(
      children: [
        Text(ok ? '✅' : '⚖️', style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(
          AppStrings.resultTitle,
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ],
    );
  }

  // ── Ringkasan ───────────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context, BandingProvider p) {
    final result = p.appealResult;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _InfoRow(icon: '📱', label: 'Nomor', value: p.formattedPhone ?? '-'),
            const SizedBox(height: 10),
            _InfoRow(
              icon: p.country?.flag ?? '🌐',
              label: 'Negara',
              value: p.country != null
                  ? '${p.country!.name} (+${p.country!.dialCode})'
                  : 'Unknown',
            ),
            const SizedBox(height: 10),
            _InfoRow(icon: '📧', label: 'Email', value: p.emailData?.email ?? '-'),
            const SizedBox(height: 10),
            _InfoRow(icon: '🏷', label: 'Provider', value: p.emailData?.provider ?? 'Mail.tm'),
            const SizedBox(height: 10),
            _InfoRow(
              icon: '📤',
              label: 'Status',
              value: result?.success == true
                  ? '✅ Terkirim'
                  : '⚠️ HTTP ${result?.statusCode ?? '-'}',
              valueColor: result?.success == true ? AppColors.success : AppColors.warning,
            ),
            if (p.replyMessage?.ticketNumber != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: '🎫',
                label: 'No. Tiket',
                value: '#${p.replyMessage!.ticketNumber!}',
                valueColor: AppColors.neonPurpleLight,
              ),
            ],
            if (result != null && !result.success && result.error != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: '❌',
                label: 'Error',
                value: result.error!,
                valueColor: AppColors.error,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Detail Error ────────────────────────────────────────────

  Widget _buildErrorDetailCard(BuildContext context, BandingProvider p) {
    final result = p.appealResult;
    if (result == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.35)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            '🔍 Detail Error (Debug)',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Diagnosis penyebab
                  if (result.diagnosis != null) ...[
                    _SectionLabel('🧠 Diagnosis'),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Text(
                        result.diagnosis!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // WhatsApp Response (parsed, bersih)
                  if (result.whatsappResponse != null) ...[
                    _DebugJsonBlock(
                      label: '📦 WhatsApp Response (parsed)',
                      data: result.whatsappResponse!,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Semua percobaan request
                  if (result.allAttempts != null && result.allAttempts!.isNotEmpty) ...[
                    _SectionLabel('🔄 Semua Percobaan (${result.allAttempts!.length}x)'),
                    const SizedBox(height: 4),
                    ...result.allAttempts!.asMap().entries.map((e) {
                      final attempt = e.value as Map<String, dynamic>?;
                      if (attempt == null) return const SizedBox.shrink();
                      final label = attempt['label'] ?? 'attempt ${e.key + 1}';
                      final status = attempt['httpStatus'] ?? attempt['error'] ?? '-';
                      final ok = attempt['success'] == true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(ok ? '✅' : '❌', style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$label → HTTP $status',
                                style: TextStyle(
                                  color: ok ? AppColors.success : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Balasan ─────────────────────────────────────────────────

  Widget _buildReplySection(BuildContext context, BandingProvider p) {
    if (p.currentStep == BandingStep.hasReply && p.replyMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📬 Balasan Diterima!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.success)),
            const SizedBox(height: 12),
            _InfoRow(icon: '📤', label: 'Dari', value: p.replyMessage!.from),
            const SizedBox(height: 8),
            _InfoRow(icon: '📌', label: 'Subjek', value: p.replyMessage!.subject),
            const SizedBox(height: 8),
            _InfoRow(icon: '📄', label: 'Preview', value: p.replyMessage!.preview),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⏰ Belum Ada Balasan dalam 2 Menit',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'WhatsApp biasanya merespons dalam 24–48 jam.\nBanding telah berhasil dikirim atas namamu.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Teks Banding ────────────────────────────────────────────

  Widget _buildAppealTextSection(BuildContext context, BandingProvider p) {
    final appealText = 'Hello WhatsApp Support Team,\n\n'
        'My WhatsApp account with the number ${p.formattedPhone ?? ""} '
        'has been restricted and I cannot log in because of a security message. '
        'This number is very important for my daily communication, '
        'and I always follow the Terms of Service. '
        'I believe this restriction is an error, so please review '
        'and help me restore access as soon as possible.';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(AppStrings.appealTextTitle, style: Theme.of(context).textTheme.bodyLarge),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              appealText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tombol Aksi ─────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context, BandingProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: ElevatedButton(
            onPressed: () { p.reset(); context.go('/banding'); },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(AppStrings.bandingOther,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () { p.reset(); context.go('/'); },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.divider),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(AppStrings.backHome,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Widgets Pendukung ────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String icon, label, value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        Expanded(
          child: Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  )),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5));
  }
}

class _DebugJsonBlock extends StatelessWidget {
  final String label;
  final Map<String, dynamic> data;
  const _DebugJsonBlock({required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel(label),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: prettyJson));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON disalin ke clipboard!')));
              },
              child: const Text('📋 Salin',
                  style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: SelectableText(
            prettyJson,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFF90CAF9),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
