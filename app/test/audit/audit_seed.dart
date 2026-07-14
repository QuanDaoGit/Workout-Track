import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/character_service.dart';
import 'package:workout_track/services/gem_service.dart';

/// Shared audit seed — a real character + a few completed sessions + gems, so
/// pages render meaningful loaded state. Seeds through real service write APIs so
/// the fixture tracks the schema. Used by the audit screen-capture batches.
ExerciseLog auditLog(String id, String name, List<SetEntry> sets) =>
    ExerciseLog(exerciseId: id, exerciseName: name, sets: sets);

WorkoutSession auditSession(
        String id, DateTime date, String mg, List<ExerciseLog> ex) =>
    WorkoutSession(
      id: id, date: date, muscleGroup: mg, targetMuscleGroups: [mg],
      targetDurationMinutes: 45, actualDurationSeconds: 45 * 60,
      estimatedCalories: 250, exercises: ex,
    );

Future<void> seedDemo() async {
  SharedPreferences.setMockInitialValues({});
  await CharacterService().createCharacterAndCompleteOnboarding(Character(
    name: 'Nova',
    calibration: const CalibrationResult(
      goal: BodyGoal.cut, freq: TrainingFreq.mid, exp: Experience.beginner,
      bodyWeightKg: 72, sex: UserProfileSex.preferNotToSay,
      clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 6, 1),
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 1),
  ));
  final now = DateTime(2026, 6, 26, 9);
  final sessions = [
    auditSession('s1', now.subtract(const Duration(days: 1)), 'Chest', [
      auditLog('Barbell_Bench_Press_-_Medium_Grip', 'Bench Press',
          const [SetEntry(weight: 80, reps: 8), SetEntry(weight: 80, reps: 8)]),
    ]),
    auditSession('s2', now.subtract(const Duration(days: 3)), 'Legs',
        [auditLog('Barbell_Squat', 'Squat', const [SetEntry(weight: 100, reps: 5)])]),
  ];
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      'workout_sessions', jsonEncode([for (final s in sessions) s.toJson()]));
  await GemService().awardDemoGems(packId: 'seed', amount: 240, label: 'Seed');
}
