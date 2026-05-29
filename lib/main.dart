import 'package:flutter/material.dart';
import 'theme/app_fonts.dart';
import 'theme/tokens.dart';

import 'pages/onboarding/onboarding_flow_page.dart';
import 'pages/root_page.dart';
import 'services/class_migration_service.dart';
import 'services/migration_service.dart';
import 'services/onboarding_service.dart';
import 'services/stat_engine.dart';
import 'widgets/motion/ambient_drift.dart';
import 'widgets/pixel_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MigrationService.runOnce();
  await MigrationService.runEndStatBackfillOnce();
  await StatEngine().applyDecayIfNeeded();
  await ClassMigrationService().migrateIfNeeded();
  runApp(const MyApp());
}

/// Decides the first screen on launch: the onboarding flow for new users, or
/// the main app for everyone else. Completion navigates forward explicitly, so
/// this gate only runs once per launch.
class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingService().isComplete(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: PixelLoader(size: 32)));
        }
        return snapshot.data! ? const RootPage() : const OnboardingFlowPage();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _AppGate(),
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
