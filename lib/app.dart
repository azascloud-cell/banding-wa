import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/banding_provider.dart';
import 'providers/cek_bio_provider.dart';
import 'providers/history_provider.dart';
import 'screens/auth/login_screen.dart';
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

// ── Auth redirect helper ──────────────────────────────────────
String? _authGuard(BuildContext context, GoRouterState state) {
  final auth = context.read<AuthProvider>();
  final loggedIn = auth.isLoggedIn;
  final onAuthPage = state.matchedLocation == '/login' ||
      state.matchedLocation == '/register';

  if (!loggedIn && !onAuthPage) return '/login';
  if (loggedIn && onAuthPage) return '/';
  return null;
}

GoRouter _buildRouter(AuthProvider auth) => GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: _authGuard,
      routes: [
        // ── Auth ───────────────────────────────────────────────
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

        // ── App ────────────────────────────────────────────────
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
        GoRoute(path: '/banding/progress', builder: (_, __) => const BandingProgressScreen()),
        GoRoute(path: '/banding/result',   builder: (_, __) => const BandingResultScreen()),
        GoRoute(path: '/cek-bio',          builder: (_, __) => const CekBioMethodScreen()),
        GoRoute(path: '/cek-bio/input',    builder: (_, __) => const CekBioInputScreen()),
        GoRoute(path: '/cek-bio/upload',   builder: (_, __) => const CekBioUploadScreen()),
        GoRoute(path: '/cek-bio/scan',     builder: (_, __) => const CekBioScanScreen()),
        GoRoute(path: '/cek-bio/result',   builder: (_, __) => const CekBioResultScreen()),
        GoRoute(
          path: '/cek-bio/detail',
          builder: (_, state) =>
              CekBioDetailScreen(result: state.extra as CekBioNumberResult),
        ),
        GoRoute(path: '/riwayat', builder: (_, __) => const RiwayatScreen()),
        GoRoute(
          path: '/riwayat/detail',
          builder: (_, state) =>
              RiwayatDetailScreen(entry: state.extra as HistoryEntry),
        ),
        GoRoute(path: '/pengaturan', builder: (_, __) => const PengaturanScreen()),
        GoRoute(path: '/pengaturan/tentang', builder: (_, __) => const TentangScreen()),
        GoRoute(path: '/pengaturan/sender-pairing', builder: (_, __) => const SenderPairingScreen()),
      ],
    );

class BandingWaApp extends StatefulWidget {
  const BandingWaApp({super.key});

  @override
  State<BandingWaApp> createState() => _BandingWaAppState();
}

class _BandingWaAppState extends State<BandingWaApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _router = _buildRouter(_authProvider);
    // Init auth di background — refresh listener akan trigger redirect otomatis
    _authProvider.init();
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
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
