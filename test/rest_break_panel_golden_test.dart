import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/rest_break_panel.dart';

/// Rendered-artifact proof for the between-exercise rest panel (the web preview
/// can't screenshot here). Deterministic under reduced motion (BIT freezes to a
/// posed still frame); the countdown is seeded with a sub-second cushion so it
/// reads a stable `1:30`. Regenerate with `flutter test --update-goldens`.
void main() {
  // A faithful-enough theme slice; the panel's buttons set their own styles
  // (cyan SKIP REST, muted ±15s).
  final theme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kNeon,
        foregroundColor: kBg,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 11),
      ),
    ),
  );

  tearDown(() => RestTimerService.instance.cancel());

  testWidgets('rest panel — reduced motion still frame', (tester) async {
    RestTimerService.instance.current.value = RestSnapshot(
      endsAt: DateTime.now().add(const Duration(seconds: 90, milliseconds: 500)),
      totalSeconds: 90,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: SizedBox(
                width: 360,
                child: RestBreakPanel(
                  onSkip: () {},
                  nextExerciseName: 'Incline Dumbbell Press',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(RestBreakPanel),
      matchesGoldenFile('goldens/rest_break_panel.png'),
    );
  });
}
