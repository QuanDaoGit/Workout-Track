import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/start_workout.dart';

/// In-memory catalog using REAL curated ids (so curated-head defaults and the
/// Replace pool, both built from the curated registry, resolve) without loading
/// `assets/exercises.json` in the test harness. Chest head = Bench, Incline;
/// Back head = Lat Pulldown, Cable Row.
const _catalog = [
  Exercise(id: 'Barbell_Bench_Press_-_Medium_Grip', name: 'Bench', level: 'beginner', images: [], primaryMuscle: 'chest', equipment: 'Barbell', mechanic: 'compound'),
  Exercise(id: 'Barbell_Incline_Bench_Press_-_Medium_Grip', name: 'Incline', level: 'beginner', images: [], primaryMuscle: 'chest', equipment: 'Barbell', mechanic: 'compound'),
  Exercise(id: 'Dumbbell_Bench_Press', name: 'DB Press', level: 'beginner', images: [], primaryMuscle: 'chest', equipment: 'Dumbbell', mechanic: 'compound'),
  Exercise(id: 'Dumbbell_Flyes', name: 'Fly', level: 'beginner', images: [], primaryMuscle: 'chest', equipment: 'Dumbbell', mechanic: 'isolation'),
  Exercise(id: 'Wide-Grip_Lat_Pulldown', name: 'Lat Pulldown', level: 'beginner', images: [], primaryMuscle: 'lats', equipment: 'Cable', mechanic: 'compound'),
  Exercise(id: 'Seated_Cable_Rows', name: 'Cable Row', level: 'beginner', images: [], primaryMuscle: 'lats', equipment: 'Cable', mechanic: 'compound'),
];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

WorkoutSession _completed(String id, List<String> groups, List<String> exerciseIds) =>
    WorkoutSession(
      id: id,
      date: DateTime(2026, 5, 10),
      muscleGroup: groups.first,
      targetMuscleGroups: groups,
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

  testWidgets('entry pre-selects last-session groups and adds their defaults', (tester) async {
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([
        _completed('s1', const ['Chest'], const ['Barbell_Bench_Press_-_Medium_Grip', 'Dumbbell_Flyes']).toJson(),
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)));
    await _settle(tester);

    expect(find.text('2. YOUR LOADOUT'), findsOneWidget);
    // Chest history top-2 = Bench + Fly.
    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('Fly'), findsOneWidget);
  });

  testWidgets('brand-new user starts with no chips and an empty prompt', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)));
    await _settle(tester);

    expect(find.text('2. YOUR LOADOUT'), findsNothing);
    expect(find.text('Pick a target above to build your loadout.'), findsOneWidget);
    expect(find.text('Chest'), findsWidgets); // chips visible
  });

  testWidgets('selecting a chip adds 2 defaults; deselecting cleanly removes them', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)));
    await _settle(tester);

    await tester.tap(find.text('Chest'));
    await _settle(tester);
    // Curated head for Chest = Bench + Incline.
    expect(find.text('2. YOUR LOADOUT'), findsOneWidget);
    expect(find.text('Incline'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await _settle(tester);
    expect(find.text('Lat Pulldown'), findsOneWidget); // Back default added

    await tester.tap(find.text('Back'));
    await _settle(tester);
    expect(find.text('Lat Pulldown'), findsNothing); // cleanly removed
    expect(find.text('Incline'), findsOneWidget); // chest defaults stay
  });

  testWidgets('repeat import is seed-owned with chips off', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartWorkoutPage(
          catalogOverride: _catalog,
          initialSelectedExerciseIds: ['Dumbbell_Flyes'],
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('REPEAT OF LAST WORKOUT'), findsOneWidget);
    expect(find.text('Fly'), findsOneWidget);
  });

  testWidgets('Replace swaps a loadout card in place', (tester) async {
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([
        _completed('s1', const ['Chest'], const ['Barbell_Bench_Press_-_Medium_Grip', 'Dumbbell_Flyes']).toJson(),
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage(catalogOverride: _catalog)));
    await _settle(tester);

    expect(find.text('DB Press'), findsNothing); // not in loadout yet
    await tester.tap(find.byTooltip('Replace').first); // first card = Bench
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Bench shares equipment+mechanic with Incline/DB Press → strong matches.
    expect(find.text('REPLACE WITH'), findsOneWidget);
    await tester.tap(find.text('DB Press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('DB Press'), findsOneWidget);
    expect(find.text('Bench'), findsNothing);
  });

  testWidgets('program day shows the prescribed loadout with no target chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartWorkoutPage(
          catalogOverride: _catalog,
          isProgramWorkout: true,
          initialMuscleGroups: ['Chest'],
          programDayLabel: 'PUSH',
          programCuratedExerciseIds: ['Barbell_Bench_Press_-_Medium_Grip', 'Dumbbell_Flyes'],
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('2. YOUR LOADOUT'), findsOneWidget);
    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('Fly'), findsOneWidget);
    // No chip Wrap in program mode — the muscle chips are not offered.
    expect(find.text('Back'), findsNothing);
  });
}
