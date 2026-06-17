import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/quests_page.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/widgets/quest_claim_flight.dart';

/// Motion-ON coverage for the ported "reward homecoming": claiming a quest flies
/// gems from the CLAIM button up to the pinned wallet, which counts up to the
/// reward; a single "+N" reveal floats by the wallet. (The reduced-motion snap
/// path is covered in quests_page_gems_test.) BIT's perpetual idle ticker means
/// the tree never settles, so this uses bounded frame-pumps, never pumpAndSettle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpFrames(WidgetTester tester, int n,
      [int ms = 100]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(Duration(milliseconds: ms));
    }
  }

  testWidgets('claim flies gems and the wallet counts up to the reward', (
    tester,
  ) async {
    final session = WorkoutSession(
      id: 'today',
      date: DateTime.now(),
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 30,
      actualDurationSeconds: 30 * 60,
      estimatedCalories: 0,
      exercises: const [
        ExerciseLog(
          exerciseId: 'bench',
          exerciseName: 'Bench Press',
          sets: [SetEntry(weight: 100, reps: 10)],
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([session.toJson()]),
    });

    // Motion ON (no disableAnimations override).
    await tester.pumpWidget(const MaterialApp(home: QuestsPage()));
    await pumpFrames(tester, 6); // let the async reload + wallet seed settle

    expect(find.text('CLAIM'), findsWidgets);

    await tester.tap(find.text('CLAIM').first); // 'Show up' → 5 gems
    await pumpFrames(tester, 2, 80); // the "+N" reveal is up

    // The single per-claim "+N" reveal floats by the wallet (motion on).
    expect(
      find.descendant(of: find.byType(GemWallet), matching: find.text('+5')),
      findsOneWidget,
    );

    await pumpFrames(tester, 28); // flight (~0.85s) + count-up settle

    // The gems landed in the ledger and the wallet counted up to them.
    expect(await GemService().balance(), 5);
    expect(
      find.descendant(of: find.byType(GemWallet), matching: find.text('5')),
      findsOneWidget,
    );
    expect(find.text('CLAIMED'), findsWidgets);
  });
}
