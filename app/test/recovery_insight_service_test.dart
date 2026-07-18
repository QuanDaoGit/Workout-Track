import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/recovery_insights.dart';
import 'package:workout_track/services/recovery_insight_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  RecoveryInsightService serviceAt(DateTime now) =>
      RecoveryInsightService(nowProvider: () => now);

  /// Peek + commit in one step — the "user opened the sheet" simulation.
  Future<RecoveryInsightPick> shownAt(DateTime now) async {
    final service = serviceAt(now);
    final pick = await service.peekToday();
    await service.commitShown(pick);
    return pick;
  }

  test('peek alone consumes nothing (Codex F1: no burn before render)',
      () async {
    final day = DateTime(2026, 7, 18, 9);
    final a = await serviceAt(day).peekToday();
    final b = await serviceAt(day).peekToday();
    expect(b.insight.id, a.insight.id);
    // Nothing persisted: the state key is still absent.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(RecoveryInsightService.stateKey), isNull);
  });

  test('same day returns the same insight on reopen after a commit', () async {
    final first = await shownAt(DateTime(2026, 7, 18, 9));
    final second =
        await serviceAt(DateTime(2026, 7, 18, 21)).peekToday();
    expect(second.insight.id, first.insight.id);
    expect(first.poolWrapped, isFalse);
  });

  test('commit is idempotent per day (double-tap safe)', () async {
    final day = DateTime(2026, 7, 18);
    final service = serviceAt(day);
    final pick = await service.peekToday();
    await service.commitShown(pick);
    await service.commitShown(pick);
    final again = await service.peekToday();
    expect(again.insight.id, pick.insight.id);
  });

  test('a different pick on an already-committed day is ignored', () async {
    final day = DateTime(2026, 7, 18);
    final service = serviceAt(day);
    final pick = await service.peekToday();
    await service.commitShown(pick);
    // Forge a different pick (any other pool entry) and try to commit it.
    final other = recoveryInsights.firstWhere((i) => i.id != pick.insight.id);
    await service.commitShown(RecoveryInsightPick(
        insight: other, poolWrapped: false, dayKey: pick.dayKey));
    final again = await service.peekToday();
    expect(again.insight.id, pick.insight.id,
        reason: 'the first commit of the day must win');
  });

  test('pick carries the day it was resolved for', () async {
    final pick = await serviceAt(DateTime(2026, 7, 18, 23, 59)).peekToday();
    expect(pick.dayKey, '2026-07-18');
  });

  test('midnight straddle: commit files under the peeked day, not the clock',
      () async {
    // Peek just before midnight; the commit lands just after it (the sheet
    // was pushed at 23:59, commitShown resolved at 00:00).
    final pick = await serviceAt(DateTime(2026, 7, 18, 23, 59)).peekToday();
    final afterMidnight = serviceAt(DateTime(2026, 7, 19, 0, 1));
    await afterMidnight.commitShown(pick);
    // The new day is NOT the committed day — it resolves a fresh insight
    // (no repeat-day), and the straddled insight is spent, never re-picked.
    final nextDay = await afterMidnight.peekToday();
    expect(nextDay.dayKey, '2026-07-19');
    expect(nextDay.insight.id, isNot(pick.insight.id),
        reason: 'a commit landing past midnight must not relabel the pick '
            'as today\'s and repeat it');
  });

  test('midnight straddle keeps commit idempotence', () async {
    final pick = await serviceAt(DateTime(2026, 7, 18, 23, 59)).peekToday();
    final afterMidnight = serviceAt(DateTime(2026, 7, 19, 0, 1));
    await afterMidnight.commitShown(pick);
    await afterMidnight.commitShown(pick); // double-tap across the boundary
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString(RecoveryInsightService.stateKey)!)
        as Map<String, dynamic>;
    expect(stored['lastShownDayKey'], '2026-07-18');
    // Still exactly one seen id — the second commit was a no-op.
    expect(stored['seenIds'], [pick.insight.id]);
  });

  test('pick is deterministic for a fixed day key', () async {
    final day = DateTime(2026, 7, 18);
    final a = await shownAt(day);
    SharedPreferences.setMockInitialValues({});
    final b = await shownAt(day);
    expect(b.insight.id, a.insight.id);
  });

  test('a new day advances to an unseen insight', () async {
    final first = await shownAt(DateTime(2026, 7, 18));
    final second = await shownAt(DateTime(2026, 7, 20));
    expect(second.insight.id, isNot(first.insight.id));
  });

  test('never repeats until the pool is exhausted, then wraps with flag',
      () async {
    final seen = <String>{};
    var day = DateTime(2026, 1, 1);
    for (var i = 0; i < recoveryInsights.length; i++) {
      final pick = await shownAt(day);
      expect(pick.poolWrapped, isFalse,
          reason: 'day $i wrapped before exhaustion');
      expect(seen.add(pick.insight.id), isTrue,
          reason: 'repeated ${pick.insight.id} before exhaustion');
      day = day.add(const Duration(days: 1));
    }
    // Pool exhausted: the next day wraps, flags it, and starts a fresh cycle.
    final wrapped = await shownAt(day);
    expect(wrapped.poolWrapped, isTrue);
    // Reopening the wrap day keeps the flag (the sheet line stays honest).
    final reopened = await serviceAt(day).peekToday();
    expect(reopened.poolWrapped, isTrue);
    // The day after the wrap is a normal fresh-cycle day again.
    final after = await shownAt(day.add(const Duration(days: 1)));
    expect(after.poolWrapped, isFalse);
    expect(after.insight.id, isNot(wrapped.insight.id));
  });

  test('corrupt stored state resets cleanly instead of crashing', () async {
    SharedPreferences.setMockInitialValues(
        {RecoveryInsightService.stateKey: 'not json {{{'});
    final pick = await shownAt(DateTime(2026, 7, 18));
    expect(recoveryInsights.map((i) => i.id), contains(pick.insight.id));
  });

  test('a stored lastShownId no longer in the pool falls through to a fresh pick',
      () async {
    SharedPreferences.setMockInitialValues({
      RecoveryInsightService.stateKey:
          '{"seenIds":["ghost_id"],"lastShownId":"ghost_id","lastShownDayKey":"2026-07-18","lastShownWrapped":false}',
    });
    final pick = await shownAt(DateTime(2026, 7, 18));
    expect(recoveryInsights.map((i) => i.id), contains(pick.insight.id));
  });
}
