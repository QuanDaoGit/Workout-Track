import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/exercise_history_page.dart';
import 'package:workout_track/pages/strength_index_page.dart';
import 'package:workout_track/services/unit_settings_service.dart';

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

  // Bench: 2 weighted sessions → a trend row. Curl: 1 session → locked row.
  List<WorkoutSession> sample() => [
    session([
      log('Bench', 'Bench Press', [const SetEntry(weight: 100, reps: 5)]),
    ], daysAgo: 9),
    session([
      log('Bench', 'Bench Press', [const SetEntry(weight: 105, reps: 5)]),
      log('Curl', 'Barbell Curl', [const SetEntry(weight: 30, reps: 8)]),
    ], daysAgo: 2),
  ];

  Widget host() => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: StrengthIndexPage(),
  );

  testWidgets('lists logged lifts; single-session lift shows a locked row', (
    tester,
  ) async {
    seed(sample());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Barbell Curl'), findsOneWidget);
    // Curl has one session → the calm "log once more" line, no warning.
    expect(find.text('1 session · log once more for a trend'), findsOneWidget);
    expect(find.textContaining('PLATEAU'), findsNothing);
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

  testWidgets('golden — strength index, sample lifts', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const StrengthIndexPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StrengthIndexPage),
      matchesGoldenFile('_strength_index.png'),
    );
  });
}
