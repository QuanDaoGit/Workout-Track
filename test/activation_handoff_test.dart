import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/pages/root_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A real workout / rest day from the recommended intermediate program.
  final workoutDay = programById(
    'upper_lower',
  )!.weekSchedule.firstWhere((d) => d.isWorkout);
  final restDay = programById(
    'upper_lower',
  )!.weekSchedule.firstWhere((d) => !d.isWorkout);

  group('buildFirstSessionStarter (program-aware launch decision)', () {
    test('a program workout day → pre-filled program-mode starter', () {
      final starter = buildFirstSessionStarter(workoutDay);
      expect(starter.isProgramWorkout, isTrue);
      expect(starter.initialMuscleGroups, isNotEmpty);
      expect(starter.programCuratedExerciseIds, isNotNull);
      expect(starter.programCuratedExerciseIds!, isNotEmpty);
    });

    test('no program (null day) → generic blank picker', () {
      final starter = buildFirstSessionStarter(null);
      expect(starter.isProgramWorkout, isFalse);
      expect(starter.programCuratedExerciseIds, isNull);
      expect(starter.initialMuscleGroups, isNull);
    });

    test('a rest day → generic picker (defensive; unreachable at onboarding)', () {
      final starter = buildFirstSessionStarter(restDay);
      expect(starter.isProgramWorkout, isFalse);
      expect(starter.programCuratedExerciseIds, isNull);
    });

    test('a workout-day launch pre-fills the full Day 1 loadout', () {
      // Express was removed: both START WORKOUT and the Home FIRST QUEST /
      // EXPLORE-FIRST path route through programDayStarter, so the first session
      // is always the full prescribed Day 1 (no trim, no onboarding-button split).
      final starter = buildFirstSessionStarter(workoutDay);
      expect(starter.programCuratedExerciseIds, workoutDay.suggestedExerciseIds);
      expect(starter.programDayLabel, workoutDay.label);
    });
  });

  group('Start Gate endowed progress', () {
    testWidgets('shows the active First Forge quest, not "0 rewards ready"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: true, accessibleNavigation: true),
            child: child ?? const SizedBox.shrink(),
          ),
          home: StartGateScreen(character: _character()),
        ),
      );
      // Reduced motion → reveal skips to its end on the first frame.
      await tester.pump();
      await tester.pump();

      expect(find.text('1 QUEST ACTIVE'), findsOneWidget);
      expect(
        find.text('▸ First Forge · log your first workout'),
        findsOneWidget,
      );
      expect(find.text('0 rewards ready'), findsNothing);
    });
  });
}

Character _character() => Character(
  name: 'Rae',
  calibration: const CalibrationResult(
    goal: BodyGoal.recomp,
    freq: TrainingFreq.mid,
    exp: Experience.beginner,
    bodyWeightKg: 80,
    sex: UserProfileSex.preferNotToSay,
    clazz: CharacterClass.bruiser,
  ),
  classConfirmedAt: DateTime(2026, 6, 6),
  characterName: 'Rae',
  createdAt: DateTime(2026, 6, 6),
);
