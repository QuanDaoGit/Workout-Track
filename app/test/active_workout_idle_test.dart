import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';

Exercise _exercise(String id) => Exercise(
  id: id,
  name: id,
  level: 'beginner',
  images: const [],
);

/// A resumed session carrying one logged set, so the page boots with
/// `_loggedSets` populated (hasSets == true) without navigating to log one.
/// [id] must be unique per test: the process-wide IdleSessionGuard is keyed by
/// session id, and an earlier test ending mid-claim would silently veto a
/// later test's idle handling for the same id.
WorkoutSession _resumeWithOneSet({String id = 'r1'}) => WorkoutSession(
  id: id,
  date: DateTime.now(),
  startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
  muscleGroup: 'Chest',
  targetDurationMinutes: 30,
  actualDurationSeconds: 180,
  estimatedCalories: 20,
  isPartial: true,
  selectedExerciseIds: const ['a', 'b'],
  exercises: const [
    ExerciseLog(
      exerciseId: 'a',
      exerciseName: 'a',
      sets: [SetEntry(weight: 40, reps: 8)],
    ),
  ],
);

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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'idle timeout offers the auto-save reveal for a session with logged sets',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            muscleGroup: 'Chest',
            durationMinutes: 30,
            exercises: [_exercise('a'), _exercise('b')],
            resumeFromSession: _resumeWithOneSet(),
            idleTimeout: const Duration(seconds: 2),
          ),
        ),
      );
      await tester.pump();

      // Not yet idle.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('STILL TRAINING?'), findsNothing);

      // Cross the idle window — the reveal appears with all three actions.
      await tester.pump(const Duration(seconds: 2));
      await pumpBounded(tester);
      expect(find.text('STILL TRAINING?'), findsOneWidget);
      expect(find.text('SAVE & FINISH'), findsOneWidget);
      expect(find.text('KEEP TRAINING'), findsOneWidget);
      expect(find.text('DISCARD'), findsOneWidget);

      // KEEP TRAINING dismisses and re-arms (no reveal immediately after).
      await tester.tap(find.text('KEEP TRAINING'));
      await pumpBounded(tester);
      expect(find.text('STILL TRAINING?'), findsNothing);
    },
  );

  testWidgets('idle reveal does NOT fire while another route covers the active '
      'page, and catches up once uncovered (#3)', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: ActiveWorkoutPage(
          muscleGroup: 'Chest',
          durationMinutes: 30,
          exercises: [_exercise('a'), _exercise('b')],
          resumeFromSession: _resumeWithOneSet(),
          idleTimeout: const Duration(seconds: 2),
        ),
      ),
    );
    await tester.pump();

    // Cover the active page (mimics ExerciseSessionPage on top).
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('OTHER')),
      ),
    );
    await pumpBounded(tester);

    // Cross the idle window while covered → the reveal must NOT pop over it.
    await tester.pump(const Duration(seconds: 3));
    await pumpBounded(tester);
    expect(find.text('STILL TRAINING?'), findsNothing);

    // Uncover → the 1-minute re-poll catches up.
    navKey.currentState!.pop();
    await pumpBounded(tester);
    await tester.pump(const Duration(minutes: 1));
    await pumpBounded(tester);
    expect(find.text('STILL TRAINING?'), findsOneWidget);
  });

  testWidgets('a route-covered idle re-poll is cancelled on dispose (Codex F3)', (
    tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: ActiveWorkoutPage(
          muscleGroup: 'Chest',
          durationMinutes: 30,
          exercises: [_exercise('a'), _exercise('b')],
          resumeFromSession: _resumeWithOneSet(),
          idleTimeout: const Duration(seconds: 2),
        ),
      ),
    );
    await tester.pump();
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('OTHER')),
      ),
    );
    await pumpBounded(tester);
    // Arm the 1-minute re-poll (fires _onIdleTimeout while covered).
    await tester.pump(const Duration(seconds: 3));

    // Tear the page down, then advance past the re-poll window.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('GONE'))),
    );
    await pumpBounded(tester);
    await tester.pump(const Duration(minutes: 1));
    await pumpBounded(tester);
    expect(find.text('STILL TRAINING?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('idle timeout drops a zero-set session silently (no reveal)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ActiveWorkoutPage(
              muscleGroup: 'Chest',
              durationMinutes: 30,
              exercises: [_exercise('a'), _exercise('b')],
              idleTimeout: const Duration(seconds: 2),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    await pumpBounded(tester);
    expect(find.text('STILL TRAINING?'), findsNothing);
  });

  // The hard-boundary auto-bank scenario lives in its own file
  // (active_workout_hard_timeout_test.dart): its summary save runs through the
  // process-wide prefsWriteLock, which an earlier same-isolate test's teardown
  // can strand mid-critical-section (the KeyedLock trap) — one isolate keeps
  // it deterministic.
}
