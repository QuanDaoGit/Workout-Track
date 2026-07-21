import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/widgets/rest_break_panel.dart';
import 'package:workout_track/widgets/strobe_flash.dart';

/// The rest-end flight's trigger taxonomy + the single-owner celebration
/// (spec: docs/superpowers/specs/2026-07-21-rest-end-bit-flight-design.md).
/// The StrobeFlash trigger is the celebration oracle; the seal-beat tests
/// assert it is STILL 0 mid-flight (a fallback consumer firing early would
/// already show 1 — Codex F4) and exactly 1 after the seal.
Exercise _exercise(String id, String name) =>
    Exercise(id: id, name: name, level: 'beginner', images: const []);

// The hub hosts perpetual tickers — bounded pumps, never pumpAndSettle.
Future<void> pumpBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

Finder overlayBit() => find.byKey(const ValueKey('flight_bit'));
Finder frontierBit() => find.byKey(const ValueKey('frontier_bit'));

int strobeTrigger(WidgetTester tester, String name) {
  final strobe = tester.widget<StrobeFlash>(
    find
        .ancestor(of: find.text(name), matching: find.byType(StrobeFlash))
        .first,
  );
  return (strobe.trigger ?? 0) as int;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RestTimerService.instance.cancel();
    ExerciseKindCache.instance.resetForTest();
  });
  tearDown(() => RestTimerService.instance.cancel());

  Future<void> pumpHub(
    WidgetTester tester, {
    int restSeconds = 1,
    bool reduceMotion = false,
    List<Exercise>? exercises,
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: ActiveWorkoutPage(
          muscleGroup: 'Chest',
          durationMinutes: 30,
          restSeconds: restSeconds,
          exercises:
              exercises ??
              [_exercise('a', 'alpha'), _exercise('b', 'bravo')],
        ),
      ),
    );
    await pumpBounded(tester);
  }

  // Open [tile], log one set, Finish Exercise → back on the hub, rest started.
  Future<void> finishExercise(WidgetTester tester, String tile) async {
    await tester.tap(find.text(tile));
    await pumpBounded(tester);
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE'));
    await tester.pump();
    await tester.tap(find.text('Finish Exercise'));
    await pumpBounded(tester);
  }

  testWidgets('natural expiry: flight runs, seal stamps exactly once', (
    tester,
  ) async {
    await pumpHub(tester, restSeconds: 90);
    await finishExercise(tester, 'alpha');
    expect(find.byType(RestBreakPanel), findsOneWidget);
    // The rest snapshot's isActive reads REAL DateTime.now while the test
    // clock is fake — force a LIVE expiry (1s past, inside the <3s overshoot
    // window) then let the panel ticker notice it.
    RestTimerService.instance.current.value = RestSnapshot(
      endsAt: DateTime.now().subtract(const Duration(seconds: 1)),
      totalSeconds: 90,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(overlayBit(), findsOneWidget);
    expect(frontierBit(), findsNothing); // slot reserved, no double BIT
    // Mid-flight, before the seal (~560ms in the natural profile): the
    // celebration must NOT have fired yet (proves it's the seal, not the
    // return-consumer fallback).
    expect(strobeTrigger(tester, 'alpha'), 0);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(strobeTrigger(tester, 'alpha'), 1);
    // Landing: overlay gone, in-card BIT back, still exactly one celebration.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(overlayBit(), findsNothing);
    expect(frontierBit(), findsOneWidget);
    expect(strobeTrigger(tester, 'alpha'), 1);
    // Drain the strobe's 6×80ms toggles.
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('skip: panel gone on the tap, flight still flies + seals once', (
    tester,
  ) async {
    await pumpHub(tester, restSeconds: 90);
    await finishExercise(tester, 'alpha');
    expect(find.byType(RestBreakPanel), findsOneWidget);
    await tester.tap(find.text('SKIP REST'));
    await tester.pump();
    expect(find.byType(RestBreakPanel), findsNothing); // dismissed on the tap
    await tester.pump(const Duration(milliseconds: 50));
    expect(overlayBit(), findsOneWidget);
    expect(strobeTrigger(tester, 'alpha'), 0); // pre-seal
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    expect(strobeTrigger(tester, 'alpha'), 1); // sealed
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(overlayBit(), findsNothing);
    expect(strobeTrigger(tester, 'alpha'), 1);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('stale expiry: no flight, celebration fires once on return', (
    tester,
  ) async {
    await pumpHub(tester, restSeconds: 90);
    await finishExercise(tester, 'alpha');
    expect(find.byType(RestBreakPanel), findsOneWidget);
    // Simulate a backgrounded expiry: the snapshot ended 5s ago.
    RestTimerService.instance.current.value = RestSnapshot(
      endsAt: DateTime.now().subtract(const Duration(seconds: 5)),
      totalSeconds: 90,
    );
    await tester.pump(const Duration(seconds: 1)); // panel ticker notices
    await pumpBounded(tester);
    expect(overlayBit(), findsNothing);
    expect(strobeTrigger(tester, 'alpha'), 1); // fallback consumer, once
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('reduced motion: no flight, no strobe — warmth is the signal', (
    tester,
  ) async {
    await pumpHub(tester, restSeconds: 90, reduceMotion: true);
    await finishExercise(tester, 'alpha');
    await tester.tap(find.text('SKIP REST'));
    await pumpBounded(tester);
    expect(overlayBit(), findsNothing);
    expect(strobeTrigger(tester, 'alpha'), 0);
    expect(find.text('CLEARED'), findsOneWidget); // the still signal + warmth
  });

  testWidgets('mid-flight tap navigates instantly and cancels the seal', (
    tester,
  ) async {
    await pumpHub(tester, restSeconds: 90);
    await finishExercise(tester, 'alpha');
    await tester.tap(find.text('SKIP REST'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // pre-seal
    expect(overlayBit(), findsOneWidget);
    await tester.tap(find.text('bravo'));
    await pumpBounded(tester);
    expect(find.byType(ExerciseSessionPage), findsOneWidget); // navigated
    // The interrupted flight never seals — the celebration was cancelled.
    await tester.pump(const Duration(seconds: 1));
    expect(overlayBit(), findsNothing);
  });

  testWidgets('two-action stress: skip then instant open → one owner, no leak', (
    tester,
  ) async {
    await pumpHub(tester, restSeconds: 90);
    await finishExercise(tester, 'alpha');
    await tester.tap(find.text('SKIP REST'));
    await tester.pump(); // flight requested, gate armed, not yet begun
    await tester.tap(find.text('bravo'));
    await pumpBounded(tester);
    expect(find.byType(ExerciseSessionPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(overlayBit(), findsNothing); // the stale gate never resurrected
  });

  testWidgets('final exercise: immediate single celebration, no flight', (
    tester,
  ) async {
    await pumpHub(
      tester,
      exercises: [_exercise('a', 'alpha')],
    );
    await finishExercise(tester, 'alpha');
    expect(find.byType(RestBreakPanel), findsNothing); // rest suppressed
    expect(overlayBit(), findsNothing);
    expect(strobeTrigger(tester, 'alpha'), 1);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('final exercise under reduced motion: silent (warmth only)', (
    tester,
  ) async {
    await pumpHub(
      tester,
      reduceMotion: true,
      exercises: [_exercise('a', 'alpha')],
    );
    await finishExercise(tester, 'alpha');
    expect(strobeTrigger(tester, 'alpha'), 0);
    expect(find.text('CLEARED'), findsOneWidget);
  });
}
