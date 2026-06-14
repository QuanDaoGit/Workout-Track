import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/services/unit_settings_service.dart';

Exercise _exercise(String equipment) => Exercise(
  id: 'Test_Lift',
  name: 'Test Lift',
  level: 'beginner',
  images: const [],
  primaryMuscle: 'chest',
  equipment: equipment,
  mechanic: 'compound',
);

/// One completed session logging [id] at [weightKg], so `getLastSessionSets`
/// resolves a warm-up anchor without needing a confident overload suggestion.
void _seedHistory(String id, double weightKg) {
  final session = WorkoutSession(
    id: 's1',
    date: DateTime(2026, 5, 10),
    muscleGroup: 'Chest',
    targetMuscleGroups: const ['Chest'],
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: [
      ExerciseLog(
        exerciseId: id,
        exerciseName: id,
        sets: [SetEntry(weight: weightKg, reps: 5)],
      ),
    ],
    estimatedCalories: 100,
  );
  SharedPreferences.setMockInitialValues({
    'workout_sessions': jsonEncode([session.toJson()]),
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _pump(WidgetTester tester, Exercise exercise) async {
  await tester.pumpWidget(MaterialApp(home: ExerciseSessionPage(exercise: exercise)));
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Units.weight = WeightUnit.kg;
  });

  testWidgets('barbell with history shows a muted, non-logged warm-up card', (tester) async {
    _seedHistory('Test_Lift', 100);
    await _pump(tester, _exercise('barbell'));

    expect(find.text('Warm up'), findsOneWidget);
    expect(find.text('50 kg  ×  8'), findsOneWidget);
    // Plate calc on both the working set row and the plate-loaded warm-up.
    expect(find.byTooltip('Plate calculator'), findsNWidgets(2));
  });

  testWidgets('barbell with no anchor suggests the empty bar (no plate calc on it)', (tester) async {
    await _pump(tester, _exercise('barbell'));

    expect(find.text('Warm up'), findsOneWidget);
    expect(find.text('Empty bar  ×  8'), findsOneWidget);
    // Only the per-set plate calc — the empty bar needs no plate math.
    expect(find.byTooltip('Plate calculator'), findsOneWidget);
  });

  testWidgets('dumbbell with no anchor shows no warm-up card', (tester) async {
    await _pump(tester, _exercise('dumbbell'));

    expect(find.text('Warm up'), findsNothing);
  });

  testWidgets('dumbbell never shows a plate calculator (set row or warm-up)', (tester) async {
    _seedHistory('Test_Lift', 30);
    await _pump(tester, _exercise('dumbbell'));

    // The warm-up card shows for a dumbbell with history…
    expect(find.text('Warm up'), findsOneWidget);
    // …but a dumbbell isn't plate-loaded, so no plate calc anywhere.
    expect(find.byTooltip('Plate calculator'), findsNothing);
  });

  testWidgets('bodyweight exercise never shows a warm-up card', (tester) async {
    _seedHistory('Test_Lift', 0);
    await _pump(tester, _exercise('body only'));

    expect(find.text('Warm up'), findsNothing);
  });
}
