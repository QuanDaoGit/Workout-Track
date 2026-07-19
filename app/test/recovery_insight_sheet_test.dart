import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/recovery_insights.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/home.dart';
import 'package:workout_track/services/recovery_insight_service.dart';
import 'package:workout_track/services/rest_service.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';
import 'package:workout_track/widgets/recovery_insight_sheet.dart';

/// Records the prefs state of [RecoveryInsightService.stateKey] at the exact
/// moment the briefing's modal-sheet route is pushed (didPush runs
/// synchronously inside the push, before the opener's commit even starts).
class _SheetPushObserver extends NavigatorObserver {
  _SheetPushObserver(this.onSheetPush);
  final void Function() onSheetPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) onSheetPush();
    super.didPush(route, previousRoute);
  }
}

void main() {
  const insight = RecoveryInsight(
    id: 'test_insight',
    category: 'sleep',
    text: 'Most muscle repair runs during deep sleep.',
  );

  Widget host(RecoveryInsightPick pick) => MaterialApp(
        home: Scaffold(
          body: RecoveryInsightSheetContent(pick: pick),
        ),
      );

  testWidgets('renders the insight text, category icon, and close button',
      (tester) async {
    await tester.pumpWidget(host(const RecoveryInsightPick(
        insight: insight, poolWrapped: false, dayKey: '2026-07-18')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(
        find.textContaining('deep sleep', findRichText: true), findsOneWidget);
    // Icon-only category marker: no visible tag text, but the category is
    // still announced to screen readers via its Semantics label.
    expect(find.text('SLEEP'), findsNothing);
    expect(find.bySemanticsLabel('sleep'), findsOneWidget);
    expect(find.byType(ImageIcon), findsOneWidget);
    // BIT must render FACED (app doctrine: never faceless after onboarding).
    final bit = tester.widget<BitMoodCore>(find.byType(BitMoodCore));
    expect(bit.reveal, 1);
    expect(find.text('CLOSE'), findsOneWidget);
    expect(find.text(kRecoveryInsightWrapLine), findsNothing);
  });

  testWidgets('shows the honest wrap line only on a wrap day', (tester) async {
    await tester.pumpWidget(host(const RecoveryInsightPick(
        insight: insight, poolWrapped: true, dayKey: '2026-07-18')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(kRecoveryInsightWrapLine), findsOneWidget);
  });

  testWidgets(
      'ordering contract: RESTING... writes no state until the sheet '
      'route is pushed', (tester) async {
    // A rest-day Home: one completed session in the past (not a new user), and
    // a rest schedule whose only training weekday is NOT today — so today is a
    // planned rest day whatever real date the test runs on.
    final today = DateUtils.dateOnly(DateTime.now());
    final offWeekday = today.weekday == 1 ? 2 : 1;
    final past = today.subtract(const Duration(days: 3));
    final session = WorkoutSession(
      id: 's1',
      date: past,
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 30,
      actualDurationSeconds: 1800,
      exercises: [
        ExerciseLog(
          exerciseId: 'Test_Lift',
          exerciseName: 'Test Lift',
          sets: [SetEntry(weight: 40, reps: 5)],
        ),
      ],
      estimatedCalories: 100,
    );
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([session.toJson()]),
      RestService.stateKey: jsonEncode({
        'trainingWeekdays': [offWeekday],
        'recoveryClaims': <String, dynamic>{},
        'protectedMissDateKeys': <String>[],
        'shieldCharges': 0,
        'consecutiveSuccessfulWeeks': 0,
      }),
    });
    final prefs = await SharedPreferences.getInstance();

    var sheetPushes = 0;
    String? stateAtPush;
    final observer = _SheetPushObserver(() {
      sheetPushes++;
      stateAtPush = prefs.getString(RecoveryInsightService.stateKey);
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: HomePage(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    final button = find.text('RESTING...');
    for (var i = 0; i < 30 && button.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(button, findsOneWidget,
        reason: 'the rest-day recovery card must be showing');
    // Rendering the card alone commits nothing (peek is a pure read).
    expect(prefs.getString(RecoveryInsightService.stateKey), isNull);

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    // Bounded pumps, not pumpAndSettle: the sheet route sits above the nested
    // reduced-motion MediaQuery, so BIT's ambient idle float never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(sheetPushes, 1);
    expect(find.text('CLOSE'), findsOneWidget,
        reason: 'the briefing sheet must be open');
    expect(stateAtPush, isNull,
        reason: 'the pick must not be committed before the sheet route is '
            'pushed (never burn an insight the user never saw)');
    // ...and once the route is up, the fire-and-forget commit lands.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(prefs.getString(RecoveryInsightService.stateKey), isNotNull,
        reason: 'the commit must land after the sheet is pushed');
  });
}
