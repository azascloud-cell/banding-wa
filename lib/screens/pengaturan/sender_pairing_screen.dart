import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

enum SessionStatus { loading, disconnected, waitingQr, connected, error }

class SenderPairingScreen extends StatefulWidget {
  const SenderPairingScreen({super.key});

  @override
  State<SenderPairingScreen> createState() => _SenderPairingScreenState();
}

class _SenderPairingScreenState extends State<SenderPairingScreen> {
  SessionStatus _status = SessionStatus.loading;
  String? _qrData;
  String? _connectedNumber;
  String? _errorMessage;
  String _pairingCodeInput = '';
  String? _pairingCode;
  bool _loadingPairingCode = false;
  Timer? _pollTimer;

  final _numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStatus();
    // Poll status setiap 5 detik
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiBaseUrl}/wa-session/status'))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'disconnected';
        setState(() {
          _errorMessage = null;
          if (status == 'connected') {
            _status = SessionStatus.connected;
            _connectedNumber = data['number']?.toString();
            _qrData = null;
          } else if (status == 'qr') {
            _status = SessionStatus.waitingQr;
            _qrData = data['qr']?.toString();
          } else if (status == 'connecting' || status == 'initializing') {
            // Baileys sedang konek ke WA, belum ada QR — tampilkan loading
            _status = SessionStatus.loading;
            _qrData = null;
          } else {
            _status = SessionStatus.disconnected;
            _qrData = null;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_status == SessionStatus.loading) {
          _status = SessionStatus.error;
          _errorMessage = 'Tidak dapat terhubung ke server: $e';
        }
      });
    }
  }

  Future<void> _requestQr() async {
    setState(() => _status = SessionStatus.loading);
    try {
      await http
          .post(Uri.parse('${AppConstants.apiBaseUrl}/wa-session/start'))
          .timeout(const Duration(seconds: 15));
      await _loadStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = SessionStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _requestPairingCode() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) return;
    setState(() {
      _loadingPairingCode = true;
      _pairingCode = null;
    });
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/wa-session/pairing-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'number': number}),
      ).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _pairingCode = data['code']?.toString() ?? 'Gagal mendapatkan kode';
        _loadingPairingCode = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pairingCode = 'Error: $e';
        _loadingPairingCode = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Keluar Sesi WA'),
        content: const Text('Sesi WhatsApp pengirim akan diputus. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await http
          .post(Uri.parse('${AppConstants.apiBaseUrl}/wa-session/logout'))
          .timeout(const Duration(seconds: 10));
      await _loadStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📱 Pairing Sender WA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(status: _status, number: _connectedNumber, error: _errorMessage),
            const SizedBox(height: 20),

            if (_status == SessionStatus.connected) ...[
              _InfoCard(
                icon: Icons.check_circle,
                color: AppColors.success,
                title: 'Sender Terhubung',
                subtitle: _connectedNumber ?? 'Nomor tidak diketahui',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Keluar & Ganti Sender', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],

            if (_status == SessionStatus.waitingQr && _qrData != null) ...[
              _QrCard(qrData: _qrData!),
              const SizedBox(height: 16),
              const Text(
                'Scan QR code di atas dengan WhatsApp kamu:\nWA → Perangkat Tertaut → Tautkan Perangkat',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],

            if (_status == SessionStatus.disconnected || _status == SessionStatus.error) ...[
              ElevatedButton.icon(
                onPressed: _requestQr,
                icon: const Icon(Icons.qr_code),
                label: const Text('Tampilkan QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              const _Divider(label: 'ATAU PAIRING VIA KODE'),
              const SizedBox(height: 16),
            ],

            if (_status != SessionStatus.connected) ...[
              _PairingCodeSection(
                controller: _numberController,
                loading: _loadingPairingCode,
                code: _pairingCode,
                onRequest: _requestPairingCode,
              ),
            ],

            const SizedBox(height: 24),
            _InfoCard(
              icon: Icons.info_outline,
              color: AppColors.warning,
              title: 'Catatan',
              subtitle: 'Sesi WhatsApp sender digunakan untuk fitur Cek Bio agar data profil lengkap tersedia. Banding WA tidak memerlukan sesi ini.',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final SessionStatus status;
  final String? number;
  final String? error;

  const _StatusCard({required this.status, this.number, this.error});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case SessionStatus.connected:
        color = AppColors.success;
        label = 'Terhubung';
        icon = Icons.wifi;
        break;
      case SessionStatus.waitingQr:
        color = AppColors.warning;
        label = 'Menunggu Scan QR';
        icon = Icons.qr_code_scanner;
        break;
      case SessionStatus.loading:
        color = AppColors.textMuted;
        label = 'Memuat...';
        icon = Icons.hourglass_empty;
        break;
      case SessionStatus.error:
        color = AppColors.error;
        label = error ?? 'Error';
        icon = Icons.error_outline;
        break;
      default:
        color = AppColors.textSecondary;
        label = 'Tidak Terhubung';
        icon = Icons.wifi_off;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status Sender', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
          ),
          if (status == SessionStatus.loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPurple),
            ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String qrData;
  const _QrCard({required this.qrData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'QR Code',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          // Tampilkan QR sebagai teks / data URI
          SelectableText(
            qrData.length > 200 ? '${qrData.substring(0, 200)}...' : qrData,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: qrData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR data disalin')),
              );
            },
            child: const Text('Salin QR Data'),
          ),
        ],
      ),
    );
  }
}

class _PairingCodeSection extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final String? code;
  final VoidCallback onRequest;

  const _PairingCodeSection({
    required this.controller,
    required this.loading,
    required this.code,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nomor WhatsApp Sender',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '+628123456789',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.phone, color: AppColors.neonPurpleLight),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: loading ? null : onRequest,
          icon: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.key),
          label: Text(loading ? 'Meminta kode...' : 'Minta Kode Pairing'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonPurple,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (code != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neonPurple.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                const Text('Kode Pairing', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                  code!,
                  style: const TextStyle(
                    color: AppColors.neonPurpleLight,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masukkan kode ini di WA → Perangkat Tertaut → Tautkan dengan Nomor Telepon',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kode disalin')),
                    );
                  },
                  child: const Text('Salin Kode'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoCard({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }
}
