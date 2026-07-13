import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/charge_ritual_screen.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Character character() => Character(
    name: 'Nova',
    calibration: const CalibrationResult(
      goal: BodyGoal.cut,
      freq: TrainingFreq.mid,
      exp: Experience.beginner,
      bodyWeightKg: 72,
      sex: UserProfileSex.preferNotToSay,
      clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 5, 29, 12),
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 29, 12),
  );

  Future<void> pumpRitual(WidgetTester tester, {required bool reduced}) {
    return tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: child!,
        ),
        home: ChargeRitualScreen(character: character()),
      ),
    );
  }

  // Drive the engine in small frames — the engine clamps dt to 64ms, so a single
  // long pump would only advance one clamped step.
  Future<void> advance(WidgetTester tester, int ms, {int step = 32}) async {
    for (var t = 0; t < ms; t += step) {
      await tester.pump(Duration(milliseconds: step));
    }
  }

  testWidgets(
    'reduced motion lands on the accessible hold/tap state and a tap ignites to '
    'the gate (name carried through)',
    (tester) async {
      await pumpRitual(tester, reduced: true);
      await tester.pump();

      // No animated reel — the still hold state with the tap CTA + HOLD prompt.
      expect(find.text('CHARGING'), findsOneWidget);
      expect(find.text('HOLD TO CHARGE UP'), findsWidgets); // keycap + prompt
      expect(find.textContaining('BIT pours it'), findsOneWidget);

      // The always-available tap path completes the charge.
      await tester.tap(find.textContaining('BIT pours it'));
      await advance(tester, 1300); // > autoFillMs (1000)
      await tester.pump(const Duration(milliseconds: 300)); // route (fade)
      await tester.pump();

      expect(find.byType(ChargeRitualScreen), findsNothing);
      expect(find.byType(StartGateScreen), findsOneWidget);
      expect(find.text('Nova'), findsOneWidget);
    },
  );

  testWidgets('skip is delayed (~3s) then routes to the gate', (tester) async {
    // Reduced so the Start Gate settles instantly (no pending reveal Timers);
    // the delayed-skip gate reads wall-clock elapsed, independent of motion.
    await pumpRitual(tester, reduced: true);
    await tester.pump();

    // Hidden immediately.
    expect(find.textContaining('continue without charging'), findsNothing);

    // A single long pump advances wall-clock (the skip gate reads raw elapsed).
    await tester.pump(const Duration(milliseconds: 3200));
    expect(find.textContaining('continue without charging'), findsOneWidget);

    await tester.tap(find.textContaining('continue without charging'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // route (flow)
    await tester.pump();

    expect(find.byType(StartGateScreen), findsOneWidget);
  });

  testWidgets('builds under full motion — video falls back to poster, no crash', (
    tester,
  ) async {
    await pumpRitual(tester, reduced: false);
    await tester.pump();
    await advance(tester, 500); // video init fails in test -> poster + watchdog

    expect(find.byType(ChargeRitualScreen), findsOneWidget);
    expect(find.text('CHARGING'), findsOneWidget);
    // Still early — the skip stays hidden.
    expect(find.textContaining('continue without charging'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
