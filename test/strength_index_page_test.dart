import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/exercise_history_page.dart';
import 'package:workout_track/pages/strength_index_page.dart';
import 'package:workout_track/services/unit_settings_service.dart';
import 'package:workout_track/widgets/pinned_lift_card.dart';

void main() {
  final now = DateTime(2026, 6, 26, 12);

  ExerciseLog log(String id, String name, List<SetEntry> sets) =>
      ExerciseLog(exerciseId: id, exerciseName: name, sets: sets);

  WorkoutSession session(List<ExerciseLog> logs, {required int daysAgo}) =>
      WorkoutSession(
        id: 's$daysAgo',
        date: now.subtract(Duration(days: daysAgo)),
        muscleGroup: 'Chest',
        targetDurationMinutes: 30,
        actualDurationSeconds: 1800,
        exercises: logs,
        estimatedCalories: 0,
      );

  void seed(List<WorkoutSession> sessions) {
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode(sessions.map((s) => s.toJson()).toList()),
    });
    Units.weight = WeightUnit.kg;
  }

  // Bench: 2 weighted sessions, rising to an all-time high → NEW BEST.
  // Curl: 1 session → a fresh "log once more" row (RECENTLY TRAINED).
  List<WorkoutSession> sample() => [
    session([
      log('Bench', 'Bench Press', [const SetEntry(weight: 100, reps: 5)]),
    ], daysAgo: 9),
    session([
      log('Bench', 'Bench Press', [const SetEntry(weight: 105, reps: 5)]),
      log('Curl', 'Barbell Curl', [const SetEntry(weight: 30, reps: 8)]),
    ], daysAgo: 2),
  ];

  // Four lifts, each with 2 rising sessions → all have trends (for the cap test).
  List<WorkoutSession> manyLifts() => [
    session([
      log('Bench', 'Bench Press', [const SetEntry(weight: 80, reps: 5)]),
      log('Squat', 'Back Squat', [const SetEntry(weight: 120, reps: 5)]),
      log('Dead', 'Deadlift', [const SetEntry(weight: 140, reps: 5)]),
      log('OHP', 'Overhead Press', [const SetEntry(weight: 50, reps: 5)]),
    ], daysAgo: 9),
    session([
      log('Bench', 'Bench Press', [const SetEntry(weight: 85, reps: 5)]),
      log('Squat', 'Back Squat', [const SetEntry(weight: 125, reps: 5)]),
      log('Dead', 'Deadlift', [const SetEntry(weight: 145, reps: 5)]),
      log('OHP', 'Overhead Press', [const SetEntry(weight: 52, reps: 5)]),
    ], daysAgo: 2),
  ];

  Finder cardPin() => find.descendant(
    of: find.byType(PinnedLiftCard),
    matching: find.byIcon(Icons.push_pin_sharp),
  );

  // Reduced motion → the entrance stagger snaps complete (deterministic test).
  Widget host() => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: const StrengthIndexPage(),
      ),
    ),
  );

  testWidgets('lists logged lifts; single-session lift shows a fresh row', (
    tester,
  ) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Barbell Curl'), findsOneWidget);
    expect(find.text('1 session · log once more'), findsOneWidget);
    expect(find.textContaining('PLATEAU'), findsNothing);
  });

  testWidgets('ALL view groups lifts into completeness-preserving sections', (
    tester,
  ) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('NEW BESTS'), findsOneWidget); // Bench
    expect(find.text('RECENTLY TRAINED'), findsOneWidget); // Curl (fresh)
    // The honest column hint, not "best".
    expect(find.textContaining('EST. MAX'), findsOneWidget);
  });

  testWidgets('a momentum chip slices the list (and shows a kind empty)', (
    tester,
  ) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('NEW')); // only new bests
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Barbell Curl'), findsNothing);
    expect(find.text('NEW BESTS'), findsNothing); // flat slice, no headers

    await tester.tap(find.text('RISING')); // none rising in the sample
    await tester.pumpAndSettle();
    expect(find.textContaining('No lifts on the rise'), findsOneWidget);
  });

  testWidgets('search filters the index by exercise name', (tester) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'curl');
    await tester.pumpAndSettle();

    expect(find.text('Barbell Curl'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
  });

  testWidgets('tapping a row opens its full ExerciseHistoryPage', (tester) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseHistoryPage), findsOneWidget);
  });

  testWidgets('no weighted history → calm empty state', (tester) async {
    seed(const []);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.textContaining('Log a weighted set'), findsOneWidget);
  });

  testWidgets('long-press pins a lift to the top (and shows the count)', (
    tester,
  ) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(PinnedLiftCard), findsNothing);
    expect(find.text('Hold a lift to pin it to the top'), findsOneWidget);

    await tester.longPress(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.byType(PinnedLiftCard), findsOneWidget);
    expect(find.textContaining('PINNED 1/3'), findsOneWidget);
  });

  testWidgets('a 4th pin is blocked with an unpin-first notice', (tester) async {
    // Tall surface so all four lifts build (3 cards would push the 4th off the
    // lazy-built fold otherwise).
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    seed(manyLifts());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (final name in ['Bench Press', 'Back Squat', 'Deadlift']) {
      await tester.longPress(find.text(name));
      await tester.pumpAndSettle();
    }
    expect(find.byType(PinnedLiftCard), findsNWidgets(3));
    expect(find.textContaining('PINNED 3/3'), findsOneWidget);

    await tester.longPress(find.text('Overhead Press'));
    await tester.pump(); // surface the SnackBar
    expect(find.textContaining('pins max'), findsOneWidget);
    expect(find.byType(PinnedLiftCard), findsNWidgets(3)); // still 3
  });

  testWidgets('unpinning from the card returns the lift to its section', (
    tester,
  ) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(find.byType(PinnedLiftCard), findsOneWidget);

    await tester.tap(cardPin());
    await tester.pumpAndSettle();
    expect(find.byType(PinnedLiftCard), findsNothing);
    expect(find.text('Bench Press'), findsOneWidget); // back as a row
    expect(find.text('Hold a lift to pin it to the top'), findsOneWidget);
  });

  testWidgets('long-press a pinned card unpins it (gesture symmetry)', (
    tester,
  ) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Bench Press')); // hold a row → pin
    await tester.pumpAndSettle();
    expect(find.byType(PinnedLiftCard), findsOneWidget);

    await tester.longPress(find.byType(PinnedLiftCard)); // hold the card → unpin
    await tester.pumpAndSettle();
    expect(find.byType(PinnedLiftCard), findsNothing);
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('golden — reworked strength index (sections + icons)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    seed([
      session([
        log('Bench', 'Bench Press', [const SetEntry(weight: 80, reps: 5)]),
      ], daysAgo: 16),
      session([
        log('Bench', 'Bench Press', [const SetEntry(weight: 85, reps: 5)]),
        log('Squat', 'Back Squat', [const SetEntry(weight: 120, reps: 5)]),
      ], daysAgo: 9),
      session([
        log('Bench', 'Bench Press', [const SetEntry(weight: 90, reps: 5)]),
        log('Squat', 'Back Squat', [const SetEntry(weight: 130, reps: 5)]),
        log('Curl', 'Barbell Curl', [const SetEntry(weight: 30, reps: 8)]),
      ], daysAgo: 2),
    ]);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    // Load the lift-icon assets so the golden renders the real art.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StrengthIndexPage),
      matchesGoldenFile('_strength_index.png'),
    );
  });
}
