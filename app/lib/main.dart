import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'theme/app_fonts.dart';
import 'theme/tokens.dart';

import 'pages/boot_splash_page.dart';
import 'services/app_route_observer.dart';
import 'services/analytics_consent_service.dart';
import 'services/analytics_service.dart';
import 'services/demo_seed_service.dart';
import 'widgets/motion/ambient_drift.dart';

/// Marketing/QA-only data switch. Empty (the default) in every normal build.
///   --dart-define=SEED_DEMO=intermediate   seed a demo intermediate profile
///   --dart-define=SEED_DEMO=clear          wipe local data back to first-run
const _seedDemo = String.fromEnvironment('SEED_DEMO');

/// Sentry DSN — a public client ingestion key (safe to embed/commit, like the
/// Firebase config). Crash reporting is opt-in; see ADR 0001.
const _sentryDsn =
    'https://13f5ae6a799e4307afa57155b4caff79@o4511635128713216.ingest.us.sentry.io/4511635133825024';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Marketing/QA seed runs BEFORE telemetry init so a synthetic persona is built
  // against the no-op analytics sink and never emits real events (ADR 0001).
  if (_seedDemo == 'intermediate') {
    await DemoSeedService.seedIntermediate();
  } else if (_seedDemo == 'clear') {
    await DemoSeedService.clearAll();
  }
  // Off-device telemetry (ADR 0001). Guarded so a Firebase failure never blocks
  // boot — the no-op analytics sink stays in place if init throws.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AnalyticsService.bootstrap(
      sink: FirebaseAnalyticsSink(FirebaseAnalytics.instance),
    );
  } catch (e) {
    debugPrint('Telemetry init failed (continuing): $e');
  }
  // Crash reporting (Sentry) is OPT-IN (ADR 0001): only initialize after the
  // user consents; otherwise run the app without it. A later opt-in takes
  // effect on the next launch.
  final crashOptedIn = await AnalyticsConsentService().crashReportingEnabled();
  // Launch work is relocated to BootSplashPage so the boot animation honestly
  // covers it (occupied-time) instead of running during the native splash.
  if (crashOptedIn) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.sendDefaultPii = false; // data minimization (ADR 0001)
        options.tracesSampleRate = 0.0; // crashes only — no performance tracing
      },
      appRunner: () => runApp(const MyApp()),
    );
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      home: const BootSplashPage(),
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgGradientTop, kBgGradientBottom],
          ),
        ),
        child: Stack(
          children: [
            child!,
            Positioned.fill(child: IgnorePointer(child: AmbientDrift())),
          ],
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: AppFonts.shareTechMonoFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kNeon,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: kCard,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: kNeon,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: kNeon,
          ),
          shape: Border(bottom: BorderSide(color: kBorder)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kNeon,
            textStyle: AppFonts.shareTechMono(),
            side: const BorderSide(color: kNeon, width: 1),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kNeon,
            foregroundColor: kBg,
            elevation: 0,
            textStyle: AppFonts.shareTechMono(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
            ),
          ),
        ),
        chipTheme: const ChipThemeData(
          selectedColor: kNeon,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
          ),
        ),
        cardTheme: const CardThemeData(
          color: kCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
            side: BorderSide(color: kBorder),
          ),
        ),
        textTheme: AppFonts.shareTechMonoTextTheme().copyWith(
          headlineLarge: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18,
            color: kNeon,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: kNeon,
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: kNeon,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: kText,
          ),
          bodySmall: AppFonts.shareTechMono(color: kMutedText, fontSize: 14),
          bodyMedium: AppFonts.shareTechMono(color: kText, fontSize: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: kNeon,
          unselectedItemColor: kMutedText,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: kSurface3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
            side: BorderSide(color: kBorder),
          ),
        ),
      ),
    );
  }
}
