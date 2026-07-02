import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/Workout session/start_workout.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/services/workout_draft_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A real workout day from the recommended intermediate program.
  final workoutDay = programById(
    'upper_lower',
  )!.weekSchedule.firstWhere((d) => d.isWorkout);

  // The live onboarding launch (`_RootPageState._openFirstSession`) no longer
  // builds a StartWorkoutPage directly: for a program workout day it seeds the
  // in-shell draft via `workoutDraftSeedForProgramDay(effective)`, and for a
  // rest/null day it falls back to `WorkoutDraftSeed.manual()`. These tests pin
  // that draft-seed shape — the program-day arm and the blank arm. The *routing*
  // decision (whether a fresh user even sees the program Day-1 card) is
  // `newUserMissionShowsProgramDayOne`, covered by home_first_quest_routing_test.
  group('first-session draft seed (_openFirstSession seam)', () {
    test('a program workout day → pre-filled program-mode draft seed', () {
      final seed = workoutDraftSeedForProgramDay(workoutDay);
      expect(seed.isProgramWorkout, isTrue);
      expect(seed.initialMuscleGroups, isNotEmpty);
      expect(seed.programCuratedExerciseIds, isNotNull);
      expect(seed.programCuratedExerciseIds!, isNotEmpty);
    });

    test('the seed carries the full prescribed Day 1 loadout', () {
      // START WORKOUT and the Home program-day start share this seed builder, so
      // the first session is always the full prescribed Day 1 — curated lifts,
      // prescriptions and label intact — trimmed later on the review screen.
      final seed = workoutDraftSeedForProgramDay(workoutDay);
      expect(seed.programCuratedExerciseIds, workoutDay.suggestedExerciseIds);
      expect(seed.programPrescriptions, workoutDay.prescription);
      expect(seed.programDayLabel, workoutDay.label);
    });

    test('the manual fallback arm → blank draft seed', () {
      // `_openFirstSession` uses this seed when there is no program or the
      // resolved day is a rest day, so the user lands on the free-pick picker.
      const seed = WorkoutDraftSeed.manual();
      expect(seed.isProgramWorkout, isFalse);
      expect(seed.programCuratedExerciseIds, isNull);
      expect(seed.initialMuscleGroups, isNull);
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
        find.text('▸ First Forge · save your first workout'),
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
