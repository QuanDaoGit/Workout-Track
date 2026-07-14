import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/quest_models.dart';
import 'package:workout_track/pages/quests_page.dart';

/// Unit + widget coverage for the Quests-page reset countdown:
/// - [formatResetRemaining] formatting (pure, mutation-grade);
/// - [QuestSummary] daily progress getters;
/// - the reduced-motion gate on [ResetCountdown] — it must run NO ticking timer
///   under the app's union trigger (`disableAnimations || accessibleNavigation`)
///   so an accessibility user never gets a ticking clock and a `pumpAndSettle`
///   harness in that mode never hangs (Codex review #1). The countdown is tested
///   in isolation because the full page can't settle (BIT's idle never stops).
void main() {
  group('formatResetRemaining', () {
    test('sub-day interval is a clean HH:MM:SS (no day prefix)', () {
      expect(
        formatResetRemaining(
          const Duration(hours: 14, minutes: 23, seconds: 51),
        ),
        '14:23:51',
      );
    });

    test('zero-pads every field', () {
      expect(
        formatResetRemaining(
          const Duration(hours: 4, minutes: 7, seconds: 5),
        ),
        '04:07:05',
      );
    });

    test('multi-day interval gains a "Nd " prefix and rolls H/M/S modulo', () {
      expect(
        formatResetRemaining(
          const Duration(days: 5, hours: 14, minutes: 23, seconds: 51),
        ),
        '5d 14:23:51',
      );
    });

    test('the day prefix appears exactly at the 24h boundary', () {
      expect(
        formatResetRemaining(const Duration(hours: 23, minutes: 59, seconds: 59)),
        '23:59:59',
      );
      expect(formatResetRemaining(const Duration(days: 1)), '1d 00:00:00');
    });

    test('a past / zero interval clamps to 00:00:00 (never negative)', () {
      expect(formatResetRemaining(Duration.zero), '00:00:00');
      expect(formatResetRemaining(const Duration(seconds: -30)), '00:00:00');
    });
  });

  group('QuestSummary daily progress getters', () {
    QuestItem daily(String id, {required bool completed}) => QuestItem(
          id: id,
          claimKey: 'daily:$id',
          category: QuestCategory.daily,
          title: id,
          description: id,
          rewardXP: 0,
          rewardGems: 5,
          completed: completed,
          claimed: false,
          isManual: false,
        );

    test('dailyCompleted counts completed, dailyTotal counts all', () {
      const summary = QuestSummary(
        dailyQuests: [],
        weeklyQuests: [],
        sideQuests: [],
        claimedRewardXP: 0,
        claimedRewardGems: 0,
        todayClaimedXP: 0,
        todayClaimedGems: 0,
      );
      final filled = QuestSummary(
        dailyQuests: [
          daily('a', completed: true),
          daily('b', completed: false),
          daily('c', completed: true),
        ],
        weeklyQuests: const [],
        sideQuests: const [],
        claimedRewardXP: 0,
        claimedRewardGems: 0,
        todayClaimedXP: 0,
        todayClaimedGems: 0,
      );
      expect(summary.dailyCompleted, 0);
      expect(summary.dailyTotal, 0);
      expect(filled.dailyCompleted, 2);
      expect(filled.dailyTotal, 3);
    });
  });

  group('ResetCountdown reduced-motion gate', () {
    // A fixed clock keeps the rendered value deterministic and prevents the
    // real-wall-clock from drifting the assertion.
    final fixedNow = DateTime(2026, 6, 21, 9, 0, 0); // → next midnight = 15:00:00

    Widget harness({
      required bool disableAnimations,
      required bool accessibleNavigation,
    }) {
      return MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: disableAnimations,
              accessibleNavigation: accessibleNavigation,
            ),
            child: Scaffold(
              body: ResetCountdown(
                kind: ResetKind.daily,
                nowProvider: () => fixedNow,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the live countdown value', (tester) async {
      await tester.pumpWidget(
        harness(disableAnimations: false, accessibleNavigation: false),
      );
      expect(find.textContaining('Resets in'), findsOneWidget);
      expect(find.textContaining('15:00:00'), findsOneWidget);
    });

    testWidgets('disableAnimations → no timer (pumpAndSettle returns)',
        (tester) async {
      await tester.pumpWidget(
        harness(disableAnimations: true, accessibleNavigation: false),
      );
      // Would throw "A Timer is still pending" if a periodic timer were running.
      await tester.pumpAndSettle();
      expect(find.textContaining('15:00:00'), findsOneWidget);
    });

    testWidgets(
        'accessibleNavigation only → no timer either (the union gate, Codex #1)',
        (tester) async {
      await tester.pumpWidget(
        harness(disableAnimations: false, accessibleNavigation: true),
      );
      // The regression: with the old disableAnimations-only gate this hangs.
      await tester.pumpAndSettle();
      expect(find.textContaining('15:00:00'), findsOneWidget);
    });

    testWidgets('full motion → a 1s timer ticks (and is cleaned up on dispose)',
        (tester) async {
      await tester.pumpWidget(
        harness(disableAnimations: false, accessibleNavigation: false),
      );
      // A periodic timer is live: advancing time rebuilds the widget. (Pumping a
      // bounded duration, never pumpAndSettle, since it never settles.)
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Resets in'), findsOneWidget);
      // Tearing down disposes the timer; a leaked timer fails the test binding.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
