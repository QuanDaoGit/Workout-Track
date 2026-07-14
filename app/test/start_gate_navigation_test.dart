import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/Workout session/start_workout.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/pages/root_page.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

/// Regression for the reported bug: starting the first workout from the
/// onboarding finale dropped the user on the exercise picker instead of Home,
/// because StartGate made the picker a root route with no RootPage shell
/// beneath it. The picker is now an **in-shell** selection surface (the area
/// restructure), so RootPage is unambiguously the navigation root and there is
/// no separate picker route to strand on — this test pins that.
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

  testWidgets(
    'START WORKOUT opens the in-shell selection on the RootPage shell, which '
    'stays the navigation root (no separate picker route to strand on)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          // Propagate reduced motion to pushed routes (RootPage/StartWorkout)
          // so arcade transitions are instant.
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: StartGateScreen(character: character()),
        ),
      );
      // Run the post-frame skip-to-end (reduced motion → buttons interactive).
      await tester.pump();

      // Capture the root navigator now, while there's unambiguously one.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      expect(find.text('START WORKOUT'), findsOneWidget);
      await tester.tap(find.text('START WORKOUT'));
      // Bounded pumps only — RootPage runs a 1s periodic dock timer, so the
      // tree never settles. Several frames are needed: push RootPage → its
      // post-frame pushes StartWorkoutPage → that route builds.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The starter is open as an in-shell selection surface (not a pushed
      // root route): the shell, the embedded picker, and the selection header
      // all coexist under RootPage.
      expect(find.byType(RootPage), findsOneWidget);
      expect(find.byType(StartWorkoutPage), findsOneWidget);
      expect(find.text('SELECT WORKOUT'), findsOneWidget);

      // RootPage is the navigation root: popping to the first route stays on the
      // shell — there is no separate picker route beneath it to get stranded on
      // (the old bug). The in-shell selection rides on the shell, not over it.
      navigator.popUntil((r) => r.isFirst);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RootPage), findsOneWidget);

      // Dispose RootPage so its periodic dock timer is cancelled before the
      // test ends.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the start gate embodies BIT below the character card with the first '
    'name-drop line, and both exits remain',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: StartGateScreen(character: character()),
        ),
      );
      // Run the post-frame skip-to-end so the reveal flags are all set.
      await tester.pump();

      // BIT is the living, painted core (breathing plates + glow), not a static
      // sprite — the same companion engine used across the onboarding.
      expect(find.byType(BitMoodCore), findsOneWidget);
      expect(
        find.textContaining('What should we do first', findRichText: true),
        findsOneWidget,
      );
      // The hero card stays, and both exits remain present.
      expect(find.text('START WORKOUT'), findsOneWidget);
      expect(find.text('EXPLORE FIRST'), findsOneWidget);

      // Dispose to cancel the StrobeFlash controller before the test ends.
      await tester.pumpWidget(const SizedBox());
    },
  );
}
