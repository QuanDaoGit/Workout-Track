import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/pages/Workout session/session_detail.dart';
import 'package:workout_track/pages/Workout session/start_workout.dart';
import 'package:workout_track/pages/boot_splash_page.dart';
import 'package:workout_track/pages/class_select_page.dart';
import 'package:workout_track/pages/exercise_detail.dart';
import 'package:workout_track/pages/exercise_history_page.dart';
import 'package:workout_track/pages/log_weight_reward_page.dart';
import 'package:workout_track/pages/onboarding/onboarding_flow_page.dart';
import 'package:workout_track/pages/program_detail_page.dart';
import 'package:workout_track/services/exercise_catalog_service.dart';

import 'audit_capture.dart';
import 'audit_seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t90 = const Timeout(Duration(seconds: 90));
  final skip = !autoUpdateGoldenFiles;

  Future<void> cap(WidgetTester t, String name, WidgetBuilder b) async {
    await seedDemo();
    await captureSurface(t, name: name, builder: b, precache: false);
  }

  // No-param / simple-value screens
  testWidgets('audit/start_workout', (t) =>
      cap(t, 'start_workout', (_) => const StartWorkoutPage()), skip: skip, timeout: t90);
  testWidgets('audit/class_select', (t) =>
      cap(t, 'class_select', (_) => const ClassSelectPage()), skip: skip, timeout: t90);
  testWidgets('audit/boot_splash', (t) =>
      cap(t, 'boot_splash', (_) => const BootSplashPage()), skip: skip, timeout: t90);
  testWidgets('audit/onboarding_flow', (t) =>
      cap(t, 'onboarding_flow', (_) => const OnboardingFlowPage()), skip: skip, timeout: t90);
  testWidgets('audit/exercise_history', (t) =>
      cap(t, 'exercise_history',
          (_) => const ExerciseHistoryPage(exerciseId: 'Barbell_Squat', exerciseName: 'Squat')),
      skip: skip, timeout: t90);
  testWidgets('audit/log_weight_reward', (t) =>
      cap(t, 'log_weight_reward', (_) => const LogWeightRewardPage(weightKg: 72)),
      skip: skip, timeout: t90);
  testWidgets('audit/program_detail', (t) =>
      cap(t, 'program_detail',
          (_) => ProgramDetailPage(program: programsLibrary.first, activeProgramId: null)),
      skip: skip, timeout: t90);
  testWidgets('audit/session_detail', (t) =>
      cap(t, 'session_detail',
          (_) => SessionDetailPage(session: auditSession('d1', DateTime(2026, 6, 25), 'Chest',
              [auditLog('Barbell_Bench_Press_-_Medium_Grip', 'Bench Press',
                  const [SetEntry(weight: 80, reps: 8), SetEntry(weight: 85, reps: 6)])]))),
      skip: skip, timeout: t90);

  // Screens needing Exercise objects (load the real catalog via runAsync)
  testWidgets('audit/active_workout', (t) async {
    await seedDemo();
    final all = await t.runAsync(() => ExerciseCatalogService().getFullCatalog());
    final picks = all!.take(3).toList();
    await captureSurface(t, name: 'active_workout', precache: false,
        builder: (_) => ActiveWorkoutPage(
            muscleGroup: 'Chest', durationMinutes: 45, exercises: picks));
  }, skip: skip, timeout: t90);

  testWidgets('audit/exercise_session', (t) async {
    await seedDemo();
    final all = await t.runAsync(() => ExerciseCatalogService().getFullCatalog());
    await captureSurface(t, name: 'exercise_session', precache: false,
        builder: (_) => ExerciseSessionPage(exercise: all!.first));
  }, skip: skip, timeout: t90);

  testWidgets('audit/exercise_detail', (t) async {
    await seedDemo();
    final all = await t.runAsync(() => ExerciseCatalogService().getFullCatalog());
    await captureSurface(t, name: 'exercise_detail', precache: false,
        builder: (_) => ExerciseDetailPage(exercise: all!.first));
  }, skip: skip, timeout: t90);
}
