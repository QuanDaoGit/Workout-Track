import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/start_workout.dart';

/// In-memory catalog using REAL curated chest ids (so the Replace pool, which
/// is built from `curatedExerciseIdsForMuscleGroups`, intersects it) — without
/// loading `assets/exercises.json` in the test harness.
const _catalog = [
  Exercise(id: 'Barbell_Bench_Press_-_Medium_Grip', name: 'Bench', level: 'beginner', images: [], primaryMuscle: 'chest', equipment: 'Barbell', mechanic: 'compound'),
  Exercise(id: 'Dumbbell_Bench_Press', name: 'DB Press', level: 'beginner', images: [], primaryMuscle: 'chest', equipment: 'Dumbbell', mechanic: 'compound'),
  Exercise(id: 'Dumbbell_Flyes', name: 'Fly', level: 'beginner', images: [], primaryMuscle: 'chest', equipment: 'Dumbbell', mechanic: 'isolation'),
  Exercise(id: 'Cable_Crossover', name: 'Crossover', level: 'beginner', images: [], primaryMuscle: 'chest', equipment: 'Cable', mechanic: 'isolation'),
];

/// Pumps long enough for the (overridden) catalog future and the post-frame
/// seed to apply, without pumpAndSettle (the screen has looping animations).
Future<void> _settleSeed(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

WorkoutSession _completed(String id, List<String> exerciseIds) => WorkoutSession(
  id: id,
  date: DateTime(2026, 5, 10),
  muscleGroup: 'Chest',
  targetMuscleGroups: const ['Chest'],
  targetDurationMinutes: 30,
  actualDurationSeconds: 1800,
  exercises: [
    for (final exerciseId in exerciseIds)
      ExerciseLog(exerciseId: exerciseId, exerciseName: exerciseId, sets: const [SetEntry(weight: 50, reps: 5)]),
  ],
  estimatedCalories: 100,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('returning user lands on a ready "usual" loadout', (tester) async {
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([
        _completed('s1', const ['Barbell_Bench_Press_-_Medium_Grip', 'Dumbbell_Bench_Press', 'Dumbbell_Flyes']).toJson(),
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)));
    await _settleSeed(tester);

    expect(find.text('2. YOUR LOADOUT'), findsOneWidget);
    expect(find.text('YOUR USUAL LIFTS'), findsOneWidget);
  });

  testWidgets('quality gate: a single-exercise history falls back to chips', (tester) async {
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([
        _completed('s1', const ['Barbell_Bench_Press_-_Medium_Grip']).toJson(),
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)));
    await _settleSeed(tester);

    expect(find.text('2. YOUR LOADOUT'), findsNothing);
    expect(find.text('Chest'), findsWidgets);
  });

  testWidgets('brand-new user (no history) gets the chip-first flow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)));
    await _settleSeed(tester);

    expect(find.text('2. YOUR LOADOUT'), findsNothing);
    expect(find.text('Chest'), findsWidgets);
  });

  testWidgets('repeat-workout selection wins over the history default', (tester) async {
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([
        _completed('s1', const ['Barbell_Bench_Press_-_Medium_Grip', 'Dumbbell_Bench_Press', 'Dumbbell_Flyes']).toJson(),
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: StartWorkoutPage(
          catalogOverride: _catalog,
          initialMuscleGroups: ['Chest'],
          initialSelectedExerciseIds: ['Cable_Crossover'],
        ),
      ),
    );
    await _settleSeed(tester);

    expect(find.text('REPEAT OF LAST WORKOUT'), findsOneWidget);
    expect(find.text('YOUR USUAL LIFTS'), findsNothing);
  });

  testWidgets('Replace swaps a loadout card in place', (tester) async {
    // Loadout = Bench / Fly / Crossover; DB Press is the spare alternative and
    // shares the "compound" mechanic with Bench, so it ranks as a strong match.
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([
        _completed('s1', const ['Barbell_Bench_Press_-_Medium_Grip', 'Dumbbell_Flyes', 'Cable_Crossover']).toJson(),
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)));
    await _settleSeed(tester);

    expect(find.text('DB Press'), findsNothing); // not in the loadout yet

    // First loadout card is Bench (curated order); open its Replace sheet.
    await tester.tap(find.byTooltip('Replace').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('REPLACE WITH'), findsOneWidget);
    await tester.tap(find.text('DB Press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Swapped into the loadout in place; Bench is gone.
    expect(find.text('DB Press'), findsOneWidget);
    expect(find.text('Bench'), findsNothing);
  });
}
