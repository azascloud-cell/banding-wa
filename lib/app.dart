import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/banding_provider.dart';
import 'providers/cek_bio_provider.dart';
import 'providers/history_provider.dart';
import 'screens/home_screen.dart';
import 'screens/banding/banding_screen.dart';
import 'screens/banding/banding_progress_screen.dart';
import 'screens/banding/banding_result_screen.dart';
import 'screens/cek_bio/cek_bio_method_screen.dart';
import 'screens/cek_bio/cek_bio_input_screen.dart';
import 'screens/cek_bio/cek_bio_upload_screen.dart';
import 'screens/cek_bio/cek_bio_scan_screen.dart';
import 'screens/cek_bio/cek_bio_result_screen.dart';
import 'screens/cek_bio/cek_bio_detail_screen.dart';
import 'models/cek_bio_models.dart';
import 'screens/riwayat/riwayat_screen.dart';
import 'screens/riwayat/riwayat_detail_screen.dart';
import 'models/history_entry_model.dart';
import 'screens/pengaturan/pengaturan_screen.dart';
import 'screens/pengaturan/tentang_screen.dart';
import 'screens/pengaturan/sender_pairing_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/banding',
      builder: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final provider = context.read<BandingProvider>();
          if (provider.currentStep != BandingStep.idle) provider.reset();
        });
        return const BandingScreen();
      },
    ),
    GoRoute(path: '/banding/progress', builder: (context, state) => const BandingProgressScreen()),
    GoRoute(path: '/banding/result',   builder: (context, state) => const BandingResultScreen()),
    GoRoute(path: '/cek-bio',          builder: (context, state) => const CekBioMethodScreen()),
    GoRoute(path: '/cek-bio/input',    builder: (context, state) => const CekBioInputScreen()),
    GoRoute(path: '/cek-bio/upload',   builder: (context, state) => const CekBioUploadScreen()),
    GoRoute(path: '/cek-bio/scan',     builder: (context, state) => const CekBioScanScreen()),
    GoRoute(path: '/cek-bio/result',   builder: (context, state) => const CekBioResultScreen()),
    GoRoute(
      path: '/cek-bio/detail',
      builder: (context, state) =>
          CekBioDetailScreen(result: state.extra as CekBioNumberResult),
    ),
    GoRoute(path: '/riwayat', builder: (context, state) => const RiwayatScreen()),
    GoRoute(
      path: '/riwayat/detail',
      builder: (context, state) =>
          RiwayatDetailScreen(entry: state.extra as HistoryEntry),
    ),
    GoRoute(path: '/pengaturan',              builder: (context, state) => const PengaturanScreen()),
    GoRoute(path: '/pengaturan/tentang',      builder: (context, state) => const TentangScreen()),
    GoRoute(path: '/pengaturan/sender-pairing', builder: (context, state) => const SenderPairingScreen()),
  ],
);

class BandingWaApp extends StatelessWidget {
  const BandingWaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BandingProvider()),
        ChangeNotifierProvider(create: (_) => CekBioProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()..load()),
      ],
      child: MaterialApp.router(
        title: 'AZZA BIO X RED',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: _router,
      ),
    );
  }
}
