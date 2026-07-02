import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/character_service.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/pages/profile_page.dart';
import 'package:workout_track/pages/shop_page.dart';
import 'package:workout_track/pages/calendar_page.dart';
import 'package:workout_track/pages/strength_index_page.dart';
import 'package:workout_track/pages/log_weight_page.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';

import 'audit_capture.dart';

ExerciseLog _log(String id, String name, List<SetEntry> sets) =>
    ExerciseLog(exerciseId: id, exerciseName: name, sets: sets);

final List<ExerciseLog> _summaryLogs = [
  _log('Barbell_Bench_Press_-_Medium_Grip', 'Bench Press',
      const [SetEntry(weight: 80, reps: 8), SetEntry(weight: 80, reps: 8), SetEntry(weight: 80, reps: 6)]),
  _log('Wide-Grip_Lat_Pulldown', 'Lat Pulldown',
      const [SetEntry(weight: 60, reps: 10), SetEntry(weight: 60, reps: 10)]),
];

WorkoutSession _session(String id, DateTime date, String mg, List<ExerciseLog> ex) =>
    WorkoutSession(
      id: id, date: date, muscleGroup: mg, targetMuscleGroups: [mg],
      targetDurationMinutes: 45, actualDurationSeconds: 45 * 60,
      estimatedCalories: 250, exercises: ex,
    );

Future<void> _seed() async {
  SharedPreferences.setMockInitialValues({});
  await CharacterService().createCharacterAndCompleteOnboarding(Character(
    name: 'Nova',
    calibration: const CalibrationResult(
      goal: BodyGoal.cut, freq: TrainingFreq.mid, exp: Experience.beginner,
      bodyWeightKg: 72, sex: UserProfileSex.preferNotToSay, clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 6, 1),
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 1),
  ));
  final now = DateTime(2026, 6, 26, 9);
  final sessions = [
    _session('s1', now.subtract(const Duration(days: 1)), 'Chest', _summaryLogs),
    _session('s2', now.subtract(const Duration(days: 3)), 'Legs',
        [_log('Barbell_Squat', 'Squat', const [SetEntry(weight: 100, reps: 5), SetEntry(weight: 100, reps: 5)])]),
    _session('s3', now.subtract(const Duration(days: 5)), 'Back',
        [_log('Seated_Cable_Rows', 'Cable Row', const [SetEntry(weight: 70, reps: 10)])]),
  ];
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('workout_sessions', jsonEncode([for (final s in sessions) s.toJson()]));
  await GemService().awardDemoGems(packId: 'seed', amount: 240, label: 'Seed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> cap(WidgetTester t, String name, WidgetBuilder b) async {
    await _seed();
    await captureSurface(t, name: name, builder: b, precache: false);
  }

  final t90 = const Timeout(Duration(seconds: 90));
  final skip = !autoUpdateGoldenFiles;

  testWidgets('audit/workout_summary', (t) async {
    await cap(t, 'workout_summary', (_) => WorkoutSummaryPage(
      muscleGroup: 'Chest', targetMuscleGroups: const ['Chest', 'Back'],
      durationMinutes: 45, elapsedSeconds: 45 * 60, exerciseLogs: _summaryLogs,
    ));
  }, skip: skip, timeout: t90);

  testWidgets('audit/profile', (t) async {
    await cap(t, 'profile', (_) => const ProfilePage());
  }, skip: skip, timeout: t90);

  testWidgets('audit/shop', (t) async {
    await cap(t, 'shop', (_) => const ShopPage());
  }, skip: skip, timeout: t90);

  testWidgets('audit/calendar', (t) async {
    await cap(t, 'calendar', (_) => const CalendarPage());
  }, skip: skip, timeout: t90);

  testWidgets('audit/strength_index', (t) async {
    await cap(t, 'strength_index', (_) => const StrengthIndexPage());
  }, skip: skip, timeout: t90);

  testWidgets('audit/log_weight', (t) async {
    await cap(t, 'log_weight', (_) => const LogWeightPage());
  }, skip: skip, timeout: t90);
}
