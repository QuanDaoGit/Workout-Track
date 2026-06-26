import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/widgets/rest_break_panel.dart';

/// The between-exercise rest panel on the workout overview: it takes over the
/// list after a genuine Finish Exercise (not a between-set rest bleeding through
/// on a back-out — Codex F4); SKIP REST restores the list; it is suppressed once
/// every exercise is cleared; and no rest carries into the finished workout (F1).
Exercise _exercise(String id) =>
    Exercise(id: id, name: id, level: 'beginner', images: const []);

WorkoutSession _resumeBothDone() => WorkoutSession(
  id: 'r1',
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
    ExerciseLog(
      exerciseId: 'b',
      exerciseName: 'b',
      sets: [SetEntry(weight: 40, reps: 8)],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RestTimerService.instance.cancel();
    ExerciseKindCache.instance.resetForTest();
  });
  tearDown(() => RestTimerService.instance.cancel());

  Future<void> pumpFresh(WidgetTester tester) async {
    // A tall surface so Finish Exercise / the full takeover are all on-screen.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveWorkoutPage(
          muscleGroup: 'Chest',
          durationMinutes: 30,
          exercises: [_exercise('a'), _exercise('b')],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpResumeBothDone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveWorkoutPage(
          muscleGroup: 'Chest',
          durationMinutes: 30,
          exercises: [_exercise('a'), _exercise('b')],
          resumeFromSession: _resumeBothDone(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Open [tile], log one set, then tap Finish Exercise (the genuine finish).
  Future<void> finishExercise(WidgetTester tester, String tile) async {
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.byIcon(Icons.radio_button_unchecked_sharp));
    await tester.pump();
    await tester.tap(find.text('Finish Exercise'));
    // The overview rest panel mounts BIT (a perpetual Ticker) — pumpAndSettle
    // would never settle, so advance the route pop with explicit pumps.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('finishing an exercise (work remaining) takes over the list', (
    tester,
  ) async {
    await pumpFresh(tester);
    await finishExercise(tester, 'a');

    expect(find.byType(RestBreakPanel), findsOneWidget);
    expect(find.text('EXERCISES'), findsNothing);
    expect(find.text('NEXT · b'), findsOneWidget); // next un-cleared movement
    expect(RestTimerService.instance.current.value?.isActive, isTrue);
  });

  testWidgets('SKIP REST cancels the rest and restores the list', (
    tester,
  ) async {
    await pumpFresh(tester);
    await finishExercise(tester, 'a');
    expect(find.byType(RestBreakPanel), findsOneWidget);

    await tester.tap(find.text('SKIP REST'));
    await tester.pump(); // cancel → panel (and BIT's ticker) unmounts
    await tester.pumpAndSettle();

    expect(RestTimerService.instance.current.value, isNull);
    expect(find.byType(RestBreakPanel), findsNothing);
    expect(find.text('EXERCISES'), findsOneWidget);
  });

  testWidgets('a between-set rest on back-out does NOT take over (Codex F4)', (
    tester,
  ) async {
    await pumpFresh(tester);
    // Log a set inside 'a' (starts a between-set rest) then back out — NOT finish.
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.byIcon(Icons.radio_button_unchecked_sharp));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The list stays — the between-set rest must not trigger the takeover.
    expect(find.byType(RestBreakPanel), findsNothing);
    expect(find.text('EXERCISES'), findsOneWidget);
    expect(find.text('ACTIVE'), findsWidgets);
  });

  testWidgets('the panel is suppressed once every exercise is cleared', (
    tester,
  ) async {
    await pumpResumeBothDone(tester);
    RestTimerService.instance.start(90); // a stray rest, all cleared
    await tester.pump();

    expect(find.byType(RestBreakPanel), findsNothing);
    expect(find.text('EXERCISES'), findsOneWidget);
    expect(find.text('Finish Workout'), findsOneWidget);
  });

  testWidgets('finishing the workout leaves no rest active (Codex F1)', (
    tester,
  ) async {
    await pumpResumeBothDone(tester);
    RestTimerService.instance.start(90); // a stray rest at finish time
    await tester.pump();

    await tester.tap(find.text('Finish Workout'));
    await tester.pump(); // handler cancels the rest before navigating

    expect(RestTimerService.instance.current.value, isNull);
  });

  testWidgets('the session header collapses during rest, expands, and restores '
      'when the rest ends', (tester) async {
    await pumpFresh(tester);
    await finishExercise(tester, 'a');

    // Collapsed by default during the takeover: ELAPSED hidden, expand chevron.
    expect(find.text('ELAPSED'), findsNothing);
    expect(find.byIcon(Icons.expand_more_sharp), findsOneWidget);

    // Expand → the (dimmed, still-live) ELAPSED returns with a collapse chevron.
    await tester.tap(find.byIcon(Icons.expand_more_sharp));
    await tester.pump();
    expect(find.text('ELAPSED'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less_sharp), findsOneWidget);

    // End the rest → full bright header restores (no collapse affordance).
    await tester.tap(find.text('SKIP REST'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('ELAPSED'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_sharp), findsNothing);
    expect(find.byIcon(Icons.expand_less_sharp), findsNothing);
  });

  testWidgets('opening an exercise carries the rest over — no skip dialog, no '
      'silent cancel (Codex F1)', (tester) async {
    await pumpResumeBothDone(tester); // list visible (all cleared)
    RestTimerService.instance.start(90);
    await tester.pump();

    // Re-open a cleared exercise while a rest is active.
    await tester.tap(find.text('a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // No SKIP REST? dialog, and the rest is carried (not silently cancelled).
    expect(find.text('SKIP REST?'), findsNothing);
    expect(RestTimerService.instance.current.value, isNotNull);
  });
}
