import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/gem_ledger_entry.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/quests_page.dart';
import 'package:workout_track/services/gem_service.dart';

/// CLAIM ALL + the section-completion bonus, end to end through the page (reduced
/// motion → deterministic, no flight/chest animation, the bonus snaps to the
/// wallet). Proves: one tap claims every claimable quest, the daily section bonus
/// lands in the ledger as a `questBonus` entry, and re-tapping never re-awards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A session rich enough that every daily quest the rotation surfaces is
  // complete, so the whole daily section is claimable in one go.
  WorkoutSession richSession(DateTime date) => WorkoutSession(
        id: 'rich',
        date: date,
        muscleGroup: 'Chest',
        targetMuscleGroups: const [
          'Chest',
          'Back',
          'Shoulders',
          'Legs',
          'Core',
        ],
        targetDurationMinutes: 30,
        actualDurationSeconds: 2000,
        estimatedCalories: 100,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench',
            exerciseName: 'Bench Press',
            sets: [
              for (var i = 0; i < 12; i++)
                const SetEntry(weight: 100, reps: 5),
            ],
            warmupSets: const [SetEntry(weight: 40, reps: 8, isWarmup: true)],
          ),
        ],
      );

  Future<void> pumpPage(WidgetTester tester, DateTime now) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: QuestsPage(nowProvider: () => now),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('CLAIM ALL claims every claimable quest and fires the daily bonus',
      (tester) async {
    final now = DateTime(2026, 5, 13, 10);
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([richSession(now).toJson()]),
    });

    await pumpPage(tester, now);

    // Something is claimable → the CLAIM ALL strip is shown.
    expect(find.text('CLAIM ALL'), findsOneWidget);
    expect(find.text('CLAIM'), findsWidgets);

    await tester.tap(find.text('CLAIM ALL'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1)); // drain the BIT-cheer timer

    // Everything claimable was claimed — no CLAIM buttons or CLAIM ALL remain.
    expect(find.text('CLAIM'), findsNothing);
    expect(find.text('CLAIM ALL'), findsNothing);

    // The daily section bonus landed as a questBonus ledger entry (10 gems),
    // and the total includes the 3 daily quest rewards + the bonus.
    final ledger = await GemService().ledger();
    final dailyBonus = ledger.where(
      (e) => e.sourceKind == GemLedgerSourceKind.questBonus &&
          e.sourceId.startsWith('daily:'),
    );
    expect(dailyBonus.length, 1);
    expect(dailyBonus.first.amount, 10);
    expect(await GemService().balance(), greaterThanOrEqualTo(25));
  });

  testWidgets('re-opening a fully-claimed board never re-awards the bonus',
      (tester) async {
    final now = DateTime(2026, 5, 13, 10);
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([richSession(now).toJson()]),
    });

    await pumpPage(tester, now);
    await tester.tap(find.text('CLAIM ALL'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    final balanceAfterClaim = await GemService().balance();

    // Rebuild the page from the now-settled state (a reopen / reload).
    await pumpPage(tester, now);
    await tester.pump(const Duration(seconds: 1));

    // No celebration replays and no gems are re-credited (the ledger one-shot).
    expect(find.text('CLAIM'), findsNothing);
    expect(await GemService().balance(), balanceAfterClaim);
    final dailyBonuses = (await GemService().ledger()).where(
      (e) => e.sourceKind == GemLedgerSourceKind.questBonus &&
          e.sourceId.startsWith('daily:'),
    );
    expect(dailyBonuses.length, 1); // still exactly one
  });
}
