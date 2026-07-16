import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../providers/banding_provider.dart';

// ── Data helper ──────────────────────────────────────────────

enum _StepStatus { pending, running, done, failed }

class _StepData {
  final String label;
  final String detail;
  final _StepStatus status;
  const _StepData(
      {required this.label, required this.detail, required this.status});
}

// ── Main Screen ──────────────────────────────────────────────

class BandingProgressScreen extends StatelessWidget {
  const BandingProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.bandingTitle),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<BandingProvider>(
        builder: (context, provider, child) {
          final steps = _buildSteps(provider);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return _StepItem(
                      index: index,
                      label: step.label,
                      detail: step.detail,
                      status: step.status,
                    )
                        .animate()
                        .fadeIn(
                            duration: 400.ms, delay: (index * 100).ms)
                        .slideY(
                            begin: 0.3, end: 0, duration: 400.ms);
                  },
                ),
              ),

              // Error card
              if (provider.currentStep == BandingStep.error)
                _ErrorCard(
                  message:
                      provider.errorMessage ?? 'Terjadi kesalahan',
                  onRetry: () {
                    provider.reset();
                    context.pop();
                  },
                ),

              // Tombol Lihat Hasil
              if (provider.currentStep == BandingStep.hasReply ||
                  provider.currentStep == BandingStep.noReply)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius:
                            BorderRadius.all(Radius.circular(12)),
                      ),
                      child: ElevatedButton(
                        onPressed: () =>
                            context.push('/banding/result'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Lihat Hasil',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<_StepData> _buildSteps(BandingProvider p) {
    return [
      // Step 1: Deteksi Negara
      _StepData(
        label: AppStrings.stepDetectCountry,
        detail: p.country != null
            ? '${p.country!.flag} ${p.country!.name} (+${p.country!.dialCode})'
            : '...',
        status: _getStatus(1, p),
      ),

      // Step 2: Buat Email Temp
      _StepData(
        label: AppStrings.stepCreateEmail,
        detail: p.emailData != null
            ? '${p.emailData!.email} | ${p.emailData!.provider}'
            : (p.currentStep == BandingStep.error
                ? '❌ ${p.errorMessage ?? "Gagal"}'
                : '...'),
        status: _getStatus(2, p),
      ),

      // Step 3: Kirim Banding
      _StepData(
        label: AppStrings.stepSubmit,
        detail: p.appealResult != null
            ? (p.appealResult!.success
                ? '✅ Terkirim'
                : '⚠️ HTTP ${p.appealResult!.statusCode ?? "error"}')
            : '...',
        status: _getStatus(3, p),
      ),

      // Step 4: Tunggu Balasan
      _StepData(
        label: AppStrings.stepWaitReply,
        detail: p.currentStep == BandingStep.waitingReply
            ? 'Sudah: ${p.elapsedSeconds}s · Sisa: ~${p.remainingSeconds}s'
            : p.currentStep == BandingStep.hasReply
                ? '📬 Balasan diterima!'
                : p.currentStep == BandingStep.noReply
                    ? '⏰ Tidak ada balasan dalam 2 menit'
                    : '...',
        status: _getStatus(4, p),
      ),
    ];
  }

  _StepStatus _getStatus(int stepNum, BandingProvider p) {
    final step = p.currentStep;
    // mapping step index → BandingStep thresholds
    switch (stepNum) {
      case 1: // Deteksi Negara
        if (step == BandingStep.idle ||
            step == BandingStep.detectingCountry) {
          return step == BandingStep.detectingCountry
              ? _StepStatus.running
              : _StepStatus.pending;
        }
        if (step == BandingStep.error && p.country == null) {
          return _StepStatus.failed;
        }
        return _StepStatus.done;

      case 2: // Buat Email
        if (step == BandingStep.idle ||
            step == BandingStep.detectingCountry) {
          return _StepStatus.pending;
        }
        if (step == BandingStep.creatingEmail) {
          return _StepStatus.running;
        }
        if (step == BandingStep.error && p.emailData == null) {
          return _StepStatus.failed;
        }
        return p.emailData != null
            ? _StepStatus.done
            : _StepStatus.pending;

      case 3: // Submit
        if (step.index < BandingStep.submitting.index) {
          return _StepStatus.pending;
        }
        if (step == BandingStep.submitting) {
          return _StepStatus.running;
        }
        return p.appealResult != null
            ? _StepStatus.done
            : _StepStatus.pending;

      case 4: // Tunggu Balasan
        if (step.index < BandingStep.waitingReply.index) {
          return _StepStatus.pending;
        }
        if (step == BandingStep.waitingReply) {
          return _StepStatus.running;
        }
        if (step == BandingStep.hasReply ||
            step == BandingStep.noReply) {
          return _StepStatus.done;
        }
        return _StepStatus.pending;

      default:
        return _StepStatus.pending;
    }
  }
}

// ── Step Item Widget ─────────────────────────────────────────

class _StepItem extends StatelessWidget {
  final int index;
  final String label;
  final String detail;
  final _StepStatus status;

  const _StepItem({
    required this.index,
    required this.label,
    required this.detail,
    required this.status,
  });

  Widget _buildIcon() {
    switch (status) {
      case _StepStatus.running:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor:
                AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1200.ms);
      case _StepStatus.done:
        return const Icon(Icons.check_circle,
            color: AppColors.success, size: 24,
            semanticLabel: 'Selesai');
      case _StepStatus.failed:
        return const Icon(Icons.cancel,
            color: AppColors.error, size: 24,
            semanticLabel: 'Gagal');
      case _StepStatus.pending:
      default:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider, width: 2),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: status == _StepStatus.pending
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: status == _StepStatus.failed
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error Card ───────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: 48,
              semanticLabel: 'Terjadi kesalahan'),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 500.ms);
  }
}
