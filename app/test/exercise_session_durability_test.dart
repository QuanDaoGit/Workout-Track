import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/services/workout_storage_service.dart';

Exercise _exercise(String id) =>
    Exercise(id: id, name: id, level: 'beginner', images: const []);

Future<void> _pumpActive(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ActiveWorkoutPage(
        muscleGroup: 'Chest',
        durationMinutes: 30,
        exercises: [_exercise('a'), _exercise('b')],
      ),
    ),
  );
  await pumpBounded(tester);
}

/// Logs one working set inside exercise 'a' (taps the tile, fills the row, taps
/// the SAVE chip) and returns once the in-flight checkpoint has settled.
Future<void> _logOneSetInA(WidgetTester tester) async {
  await tester.tap(find.text('a'));
  await pumpBounded(tester);
  await tester.enterText(find.byType(TextField).at(0), '100');
  await tester.enterText(find.byType(TextField).at(1), '5');
  await tester.tap(find.widgetWithText(FilledButton, 'SAVE'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

// The hub now hosts a perpetual-ticker BIT (frontier companion), so
// pumpAndSettle never settles while ActiveWorkoutPage is mounted at any route
// depth (Codex F1: mechanical rule, no covered-route exception). Bounded pumps.
Future<void> pumpBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RestTimerService.instance.cancel();
    ExerciseKindCache.instance.resetForTest();
  });

  testWidgets('a set logged inside the exercise screen is checkpointed before '
      'finishing (#2)', (tester) async {
    await _pumpActive(tester);
    await _logOneSetInA(tester);

    final ongoing = await WorkoutStorageService().getOngoingSession();
    expect(ongoing, isNotNull);
    expect(
      ongoing!.exercises.any((log) => log.sets.isNotEmpty),
      isTrue,
      reason: 'the logged set should be persisted before Finish Exercise',
    );
  });

  testWidgets('backing out of the exercise keeps the logged set and shows it '
      'in-progress, not cleared (#1, Codex F1)', (tester) async {
    await _pumpActive(tester);
    await _logOneSetInA(tester);

    // Back out without tapping Finish Exercise.
    await tester.pageBack();
    await pumpBounded(tester);

    // The set survives...
    final ongoing = await WorkoutStorageService().getOngoingSession();
    expect(ongoing!.exercises.any((log) => log.sets.isNotEmpty), isTrue);
    // ...but the exercise is NOT auto-completed (no CLEARED), and Finish Workout
    // stays gated.
    expect(find.text('ACTIVE'), findsWidgets);
    expect(find.text('CLEARED'), findsNothing);
  });

  testWidgets('a warm-up commit emission still carries the working set '
      '(Codex F2)', (tester) async {
    final emissions = <List<SetEntry>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseSessionPage(
          // Barbell → the advisory warm-up card (empty bar) renders even with no
          // history, so its LOG IT can drive a warm-up-only commit emission.
          exercise: Exercise(
            id: 'a',
            name: 'a',
            level: 'beginner',
            images: const [],
            equipment: 'barbell',
          ),
          onSetsCommitted: emissions.add,
        ),
      ),
    );
    await pumpBounded(tester);

    // Commit a working set.
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE').last);
    await tester.pump();

    // Then a warm-up-only commit (SAVE on the advisory card).
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE'));
    await tester.pump();

    expect(emissions, isNotEmpty);
    expect(
      emissions.last.where((s) => !s.isWarmup),
      isNotEmpty,
      reason: 'a warm-up emission must still carry the committed working set',
    );
    expect(emissions.last.where((s) => s.isWarmup), isNotEmpty);
  });

  testWidgets('an accidental extra set row can be removed (#4)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ExerciseSessionPage(exercise: _exercise('a'))),
    );
    await pumpBounded(tester);
    expect(find.widgetWithText(FilledButton, 'SAVE'), findsOneWidget); // 1 row

    await tester.tap(find.text('+ ADD SET'));
    await pumpBounded(tester);
    expect(find.widgetWithText(FilledButton, 'SAVE'), findsNWidgets(2)); // 2 rows
    expect(find.byIcon(Icons.close_sharp), findsOneWidget); // only row 2 removable

    await tester.tap(find.byIcon(Icons.close_sharp));
    await pumpBounded(tester);
    expect(find.widgetWithText(FilledButton, 'SAVE'), findsOneWidget); // back to 1 row
  });

  testWidgets('removing a middle row preserves the locked first row '
      '(#4 reindex)', (tester) async {
    // A tall surface so + ADD SET stays above the floating rest-start snackbar.
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ExerciseSessionPage(exercise: _exercise('a'))),
    );
    await pumpBounded(tester);

    // Lock Set 1, then add two more rows.
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE'));
    await tester.pump();
    await tester.tap(find.text('+ ADD SET'));
    await pumpBounded(tester);
    await tester.tap(find.text('+ ADD SET'));
    await pumpBounded(tester);
    expect(find.byIcon(Icons.check_circle_sharp), findsOneWidget); // row 0 locked
    expect(find.byIcon(Icons.close_sharp), findsNWidgets(2)); // rows 1,2

    // Remove the middle row — the locked Set 1 must survive intact.
    await tester.tap(find.byIcon(Icons.close_sharp).first);
    await pumpBounded(tester);
    expect(find.byIcon(Icons.check_circle_sharp), findsOneWidget);
    expect(find.byIcon(Icons.close_sharp), findsOneWidget);
  });

  testWidgets('the TRY suggestion chip follows to the next unlogged set, '
      'instead of vanishing after Set 1 (#6)', (tester) async {
    // Seed ≥5 logged sets so the overload service produces a suggestion.
    final history = WorkoutSession(
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
    );
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([history.toJson()]),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseSessionPage(
          exercise: Exercise(
            id: 'bench',
            name: 'Bench',
            level: 'beginner',
            images: const [],
            mechanic: 'compound',
          ),
        ),
      ),
    );
    await pumpBounded(tester);

    // Chip present above Set 1.
    expect(find.textContaining('TRY:'), findsOneWidget);

    // Add a second row, then log Set 1.
    await tester.tap(find.text('+ ADD SET'));
    await pumpBounded(tester);
    await tester.enterText(find.byType(TextField).at(0), '60');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE').first);
    await pumpBounded(tester);

    // The chip did not vanish — it followed down to the now-first-unlogged Set 2.
    expect(find.textContaining('TRY:'), findsOneWidget);
  });

  testWidgets('re-entered sets render locked (saved), not as blank inputs (#9)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseSessionPage(
          exercise: _exercise('a'),
          initialSets: const [
            SetEntry(weight: 60, reps: 8),
            SetEntry(weight: 60, reps: 8),
          ],
        ),
      ),
    );
    await pumpBounded(tester);

    // Two locked rows → two saved-check icons, no save icons.
    expect(find.byIcon(Icons.check_circle_sharp), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'SAVE'), findsNothing);
  });
}
