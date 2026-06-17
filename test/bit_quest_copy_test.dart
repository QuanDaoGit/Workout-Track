import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/bit_quest_copy.dart';

/// BIT's quest-board line is state-derived and body-neutral. The load-bearing
/// guarantee is the **quiet-board case never shames** (anti-guilt doctrine).
void main() {
  String line({
    int claimable = 0,
    int todayClaimed = 0,
    int weeklyDone = 0,
    int weeklyTotal = 5,
  }) =>
      BitQuestCopy.briefing(
        claimable: claimable,
        todayClaimed: todayClaimed,
        weeklyDone: weeklyDone,
        weeklyTotal: weeklyTotal,
      );

  test('claimable rewards lead the briefing (with singular/plural)', () {
    expect(line(claimable: 1), contains('1 reward ready'));
    expect(line(claimable: 3), contains('3 rewards ready'));
  });

  test('a finished weekly set is acknowledged when nothing is claimable', () {
    expect(
      line(weeklyDone: 5, weeklyTotal: 5),
      contains('cleared'),
    );
  });

  test('a day already banked gets a warm nod, not a nag', () {
    expect(line(todayClaimed: 2), contains('Good haul'));
  });

  test('a quiet board is forward and collaborative, never a guilt-poke', () {
    final quiet = line(); // nothing claimable, nothing today, weekly not done
    expect(quiet, isNotEmpty);
    // Anti-guilt guard: no failure / streak / loss framing anywhere in the line.
    final lowered = quiet.toLowerCase();
    for (final banned in const [
      'streak',
      'missed',
      'miss',
      'fail',
      'lost',
      'lose',
      'broke',
      'behind',
      "haven't",
      'should',
    ]) {
      expect(lowered.contains(banned), isFalse, reason: 'guilt word: $banned');
    }
  });
}
