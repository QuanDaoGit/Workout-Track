import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/pages/Workout session/start_workout.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/services/simple_mode_service.dart';

/// Simple Mode (variant A from research 2026-06-28): an opt-in Settings toggle
/// that strips PRE-WORKOUT SCAFFOLDING (warm-up advisory card + TRY suggestion +
/// the curated first-run loadout default) while keeping the user's own
/// history-derived defaults and the in-set auto-copy convenience (Codex F1).
///
/// Seed via the prefs INSTANCE (not setMockInitialValues) + a per-test clear():
/// the cached SharedPreferences singleton leaks across tests, so setMockInitialValues
/// alone reads stale. Each state is its own single-pump test — the session pages
/// keep tickers alive, so two pumps in one test collide.

// Curated catalog mirroring start_workout_seed_test (real curated ids so the
// curated-head fallback and history both resolve without loading assets).
const _catalog = [
  Exercise(
    id: 'Barbell_Bench_Press_-_Medium_Grip',
    name: 'Bench',
    level: 'beginner',
    images: [],
    primaryMuscle: 'chest',
    equipment: 'Barbell',
    mechanic: 'compound',
  ),
  Exercise(
    id: 'Barbell_Incline_Bench_Press_-_Medium_Grip',
    name: 'Incline',
    level: 'beginner',
    images: [],
    primaryMuscle: 'chest',
    equipment: 'Barbell',
    mechanic: 'compound',
  ),
  Exercise(
    id: 'Dumbbell_Flyes',
    name: 'Fly',
    level: 'beginner',
    images: [],
    primaryMuscle: 'chest',
    equipment: 'Dumbbell',
    mechanic: 'isolation',
  ),
];

Exercise _exercise(String id, {String equipment = ''}) => Exercise(
  id: id,
  name: id,
  level: 'beginner',
  images: const [],
  equipment: equipment,
);

final _bench = Exercise(
  id: 'bench',
  name: 'Bench',
  level: 'beginner',
  images: const [],
  mechanic: 'compound',
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _writeSessions(String json) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('workout_sessions', json);
}

String _benchHistoryJson() => jsonEncode([
  WorkoutSession(
    id: 'h1',
    date: DateTime(2026, 6, 1),
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    estimatedCalories: 100,
    exercises: const [
      ExerciseLog(
        exerciseId: 'bench',
        exerciseName: 'Bench',
        sets: [
          SetEntry(weight: 60, reps: 8),
          SetEntry(weight: 60, reps: 8),
          SetEntry(weight: 60, reps: 8),
          SetEntry(weight: 60, reps: 8),
          SetEntry(weight: 60, reps: 8),
        ],
      ),
    ],
  ).toJson(),
]);

String _chestHistoryJson() => jsonEncode([
  WorkoutSession(
    id: 's1',
    date: DateTime(2026, 5, 10),
    muscleGroup: 'Chest',
    targetMuscleGroups: const ['Chest'],
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: const [
      ExerciseLog(
        exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
        exerciseName: 'Bench',
        sets: [SetEntry(weight: 50, reps: 5)],
      ),
      ExerciseLog(
        exerciseId: 'Dumbbell_Flyes',
        exerciseName: 'Fly',
        sets: [SetEntry(weight: 20, reps: 10)],
      ),
    ],
    estimatedCalories: 100,
  ).toJson(),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Clear the *cached* prefs instance — setMockInitialValues leaks across tests.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    RestTimerService.instance.cancel();
    ExerciseKindCache.instance.resetForTest();
  });
  tearDown(() => RestTimerService.instance.cancel());

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  test('SimpleModeService defaults OFF and round-trips', () async {
    expect(await SimpleModeService().isEnabled(), isFalse);
    await SimpleModeService().setEnabled(true);
    expect(await SimpleModeService().isEnabled(), isTrue);
    await SimpleModeService().setEnabled(false);
    expect(await SimpleModeService().isEnabled(), isFalse);
  });

  testWidgets('warm-up advisory card shows when Simple Mode OFF', (
    tester,
  ) async {
    tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseSessionPage(
          exercise: _exercise('a', equipment: 'barbell'),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Warm up'), findsOneWidget);
  });

  testWidgets('warm-up advisory card hidden when Simple Mode ON', (
    tester,
  ) async {
    tallView(tester);
    await SimpleModeService().setEnabled(true);
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseSessionPage(
          exercise: _exercise('a', equipment: 'barbell'),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Warm up'), findsNothing);
  });

  testWidgets('in-set auto-copy still works in Simple Mode (kept — Codex F1)', (
    tester,
  ) async {
    tallView(tester);
    await SimpleModeService().setEnabled(true);
    await tester.pumpWidget(
      MaterialApp(home: ExerciseSessionPage(exercise: _exercise('a'))),
    );
    await _settle(tester);
    await tester.tap(find.text('+ ADD SET'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).at(0), '55');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE').first);
    await _settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
      '55',
    );
  });

  testWidgets('TRY suggestion shows when Simple Mode OFF', (tester) async {
    tallView(tester);
    await _writeSessions(_benchHistoryJson());
    await tester.pumpWidget(
      MaterialApp(home: ExerciseSessionPage(exercise: _bench)),
    );
    await _settle(tester);
    expect(find.textContaining('TRY:'), findsOneWidget);
  });

  testWidgets('TRY suggestion hidden when Simple Mode ON', (tester) async {
    tallView(tester);
    await _writeSessions(_benchHistoryJson());
    await SimpleModeService().setEnabled(true);
    await tester.pumpWidget(
      MaterialApp(home: ExerciseSessionPage(exercise: _bench)),
    );
    await _settle(tester);
    expect(find.textContaining('TRY:'), findsNothing);
  });

  // Drive the curated-default path through the entry seed (initialMuscleGroups),
  // which _initSeed AWAITS — so the SimpleMode read fully settles before the
  // assertion, with no fire-and-forget tap async lingering at teardown.
  testWidgets('curated first-run default is added when Simple Mode OFF', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartWorkoutPage(
          catalogOverride: _catalog,
          initialMuscleGroups: ['Chest'],
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('2. YOUR LOADOUT'), findsOneWidget);
    expect(find.text('Incline'), findsOneWidget);
  });

  testWidgets('curated first-run default is skipped when Simple Mode ON', (
    tester,
  ) async {
    await SimpleModeService().setEnabled(true);
    await tester.pumpWidget(
      const MaterialApp(
        home: StartWorkoutPage(
          catalogOverride: _catalog,
          initialMuscleGroups: ['Chest'],
        ),
      ),
    );
    await _settle(tester);
    // No auto-prefilled loadout: the loadout step never materialises (Incline may
    // still appear in the exercise picker — that's the user's own pick path).
    expect(find.text('2. YOUR LOADOUT'), findsNothing);
  });

  testWidgets(
    'history-derived defaults are KEPT in Simple Mode (their own picks)',
    (tester) async {
      await _writeSessions(_chestHistoryJson());
      await SimpleModeService().setEnabled(true);
      await tester.pumpWidget(
        const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)),
      );
      await _settle(tester);
      expect(find.text('2. YOUR LOADOUT'), findsOneWidget);
      expect(find.text('Bench'), findsOneWidget);
      expect(find.text('Fly'), findsOneWidget);
    },
  );
}
