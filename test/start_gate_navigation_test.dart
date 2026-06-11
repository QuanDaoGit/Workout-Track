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

/// Regression for the reported bug: starting the first workout from the
/// onboarding finale and then ending early dropped the user on the exercise
/// picker instead of Home, because StartGate made StartWorkoutPage the root
/// route (no RootPage shell beneath it). Every workout exit funnels through
/// `popUntil((r) => r.isFirst)`, so the app shell must be the first route.
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
    'START WORKOUT keeps RootPage as the navigation root so a workout exit '
    'returns to the app shell, not the exercise picker',
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

      // The workout starter is open on top of the shell.
      expect(find.byType(StartWorkoutPage), findsOneWidget);

      // Simulate any workout exit. End-early (Save & Exit / Discard), the back
      // button, and a normal Finish → "BACK TO HOME" all call popUntil(isFirst).
      navigator.popUntil((r) => r.isFirst);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Must land on the RootPage shell — never the exercise picker.
      expect(find.byType(StartWorkoutPage), findsNothing);
      expect(find.byType(RootPage), findsOneWidget);

      // Dispose RootPage so its periodic dock timer is cancelled before the
      // test ends.
      await tester.pumpWidget(const SizedBox());
    },
  );
}
