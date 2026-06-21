import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/xp_service.dart';

/// Pins the concave, contiguous XP curve (`level = 1 + floor(sqrt(totalXP/11))`)
/// that replaced the convex 8-level ladder — in particular the **no-loss
/// migration** invariant: because level is derived from total XP, the re-curve
/// must never map a legacy XP total below its old level or rank.
void main() {
  // The old convex ladder being replaced: total XP → old level.
  const legacyLevels = {
    50: 2,
    200: 3,
    500: 5,
    1500: 10,
    3000: 15,
    5000: 20,
    10000: 30,
  };

  // Rank order for "no demotion" comparisons.
  const rankOrder = ['Recruit', 'Squire', 'Knight', 'Champion', 'Legend'];

  test('re-curve never demotes a legacy level (no-loss migration)', () {
    legacyLevels.forEach((xp, oldLevel) {
      expect(
        XpService.getLevel(xp),
        greaterThanOrEqualTo(oldLevel),
        reason: 'XP $xp must map to at least the old level $oldLevel',
      );
    });
  });

  test('re-curve never demotes a legacy rank', () {
    // Old rank at each legacy threshold (5/10/20/30 level cut-offs).
    const legacyRanks = {
      500: 'Squire',
      1500: 'Knight',
      3000: 'Knight',
      5000: 'Champion',
      10000: 'Legend',
    };
    legacyRanks.forEach((xp, oldRank) {
      final newRank = XpService.getRank(XpService.getLevel(xp));
      expect(
        rankOrder.indexOf(newRank),
        greaterThanOrEqualTo(rankOrder.indexOf(oldRank)),
        reason: 'XP $xp must stay at least $oldRank (got $newRank)',
      );
    });
  });

  test('curve is contiguous and self-consistent across the range', () {
    for (var level = 1; level <= 60; level++) {
      final base = XpService.xpForCurrentLevel(level);
      final next = XpService.xpForNextLevel(level);
      expect(next, greaterThan(base), reason: 'level $level span is positive');
      // Standing at a level's own base XP reads as exactly that level.
      expect(XpService.getLevel(base), level);
      // Reaching the next-level XP advances by exactly one (no skipped levels).
      expect(XpService.getLevel(next), level + 1);
      // This level's ceiling is the next level's floor (contiguity).
      expect(XpService.xpForCurrentLevel(level + 1), next);
    }
  });

  test('early levels come fast', () {
    expect(XpService.getLevel(11), 2); // a few sets in
    expect(XpService.getLevel(44), 3);
    expect(XpService.getLevel(100), greaterThanOrEqualTo(4));
  });

  test('no dead-end at the top — levels continue past the old cap of 30', () {
    expect(XpService.getLevel(10000), greaterThan(30));
    expect(XpService.getLevel(20000), greaterThan(XpService.getLevel(10000)));
  });

  test('XP progress is shown within the current level span', () {
    final progress = XpService.progressForTotalXP(224);

    // 224 XP sits inside level 5 on the concave curve (base 176, next 275).
    expect(progress.level, 5);
    expect(progress.levelBaseXP, 176);
    expect(progress.nextLevelXP, 275);
    expect(progress.currentLevelXP, 48);
    expect(progress.levelSpanXP, 99);
    expect(progress.label, '48 / 99 XP');
    expect(progress.fraction, closeTo(48 / 99, 0.0001));
  });

  test('progress bar resets to empty at a clean level boundary', () {
    final boundary = XpService.progressForTotalXP(
      XpService.xpForCurrentLevel(8),
    );
    expect(boundary.level, 8);
    expect(boundary.currentLevelXP, 0);
    expect(boundary.fraction, 0.0);
  });
}
