import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/sfx_service.dart';
import 'package:workout_track/widgets/companion/bit_companion.dart';
import 'package:workout_track/widgets/companion/session_ceremony.dart';
import 'package:workout_track/widgets/xp_level_meter.dart';

/// The ceremony ⇄ summary contract: under normal motion the staged reveal is
/// gated on the ceremony's touchdown (max(saveDone, touchdown)), the seat is
/// hidden until then, and the whole path collapses to the shipped instant
/// reveal under reduced motion (covered by the existing summary tests, which
/// all force `disableAnimations`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SfxService.enabled = false;
    HapticService.enabled = false;
  });
  tearDown(() {
    SfxService.enabled = true;
    HapticService.enabled = true;
  });

  Future<void> pumpFor(WidgetTester tester, int ms) async {
    var left = ms;
    while (left > 0) {
      final step = left < 50 ? left : 50;
      await tester.pump(Duration(milliseconds: step));
      left -= step;
    }
  }

  testWidgets(
    'reveal waits for the ceremony touchdown; the seat appears with it',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkoutSummaryPage(
            muscleGroup: 'Chest',
            durationMinutes: 20,
            elapsedSeconds: 600,
            exerciseLogs: [],
            debugShowcase: true, // synchronous synthetic finish (saved=true)
          ),
        ),
      );
      await tester.pump(); // post-frame: showcase loads, ceremony starts

      // The ceremony is on stage and the showcase data is saved — but the
      // reveal must NOT have started (no XP meter) and the seat is hidden.
      expect(find.byType(SessionCeremony), findsOneWidget);
      await pumpFor(tester, 2000);
      expect(find.byType(XpLevelMeter), findsNothing);
      final seatOpacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(BitCompanion),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(seatOpacity.opacity, 0);

      // Past touchdown (2550ms) + the meter beat (+800ms): the reveal runs
      // and the seat is visible.
      await pumpFor(tester, 1500);
      expect(find.byType(XpLevelMeter), findsOneWidget);
      final seatedOpacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(BitCompanion),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(seatedOpacity.opacity, 1);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('tapping the ceremony skips straight to the gated reveal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutSummaryPage(
          muscleGroup: 'Chest',
          durationMinutes: 20,
          elapsedSeconds: 600,
          exerciseLogs: [],
          debugShowcase: true,
        ),
      ),
    );
    await tester.pump();
    await pumpFor(tester, 300);

    await tester.tap(find.byKey(const ValueKey('ceremony_skip')));
    await tester.pump();

    // Touchdown landed instantly: reveal begins (stage timers run from here).
    await pumpFor(tester, 900);
    expect(find.byType(XpLevelMeter), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
