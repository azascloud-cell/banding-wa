import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/country_model.dart';
import '../../providers/banding_provider.dart';

class BandingScreen extends StatefulWidget {
  const BandingScreen({super.key});

  @override
  State<BandingScreen> createState() => _BandingScreenState();
}

class _BandingScreenState extends State<BandingScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  CountryModel? _detectedCountry;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;
    if (text.length >= 2) {
      final formatted = formatPhone(text);
      setState(() => _detectedCountry = detectCountry(formatted));
    } else {
      setState(() => _detectedCountry = null);
    }
    if (_validationError != null) {
      setState(() => _validationError = null);
    }
  }

  void _startBanding() {
    final phone = _phoneController.text.trim();
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 8) {
      setState(() => _validationError = AppStrings.errorMinDigits);
      return;
    }

    final provider = context.read<BandingProvider>();
    if (provider.currentStep != BandingStep.idle) return;

    context.push('/banding/progress');
    provider.startBanding(phone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BandingProvider>();
    final isLoading = provider.currentStep != BandingStep.idle;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.bandingTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Input nomor ──────────────────────────────────
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                ],
                decoration: InputDecoration(
                  labelText: AppStrings.phoneLabel,
                  hintText: AppStrings.phoneHint,
                  prefixIcon: const Icon(Icons.phone, color: AppColors.textSecondary),
                  errorText: _validationError,
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 12),

              // ── Preview negara (real-time) ────────────────────
              AnimatedOpacity(
                opacity: _detectedCountry != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _detectedCountry != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _detectedCountry!.flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _detectedCountry!.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '+${_detectedCountry!.dialCode}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // ── Info warning ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Text(
                  AppStrings.warningText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                      ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Tombol Mulai Banding ──────────────────────────
              Tooltip(
                message:
                    isLoading ? 'Sedang memproses...' : 'Mulai proses banding',
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius:
                        BorderRadius.all(Radius.circular(12)),
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _startBanding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textPrimary,
                              ),
                            ),
                          )
                        : const Text(
                            AppStrings.startBanding,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ]
                .animate(interval: 80.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1, end: 0, duration: 400.ms),
          ),
        ),
      ),
    );
  }
}
