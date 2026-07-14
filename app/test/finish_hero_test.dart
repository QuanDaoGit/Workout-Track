import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/finish_result.dart';
import 'package:workout_track/models/milestone_models.dart';

/// Unit tests for the pure hero/tier ladder (§5.2 / §5.3 of the design brief).
void main() {
  FinishResult result({
    FinishCompletion completion = FinishCompletion.complete,
    int oldTotalXP = 0,
    int newTotalXP = 0,
    Map<String, int> statDelta = const {},
    Map<String, int> afterStats = const {},
    int lckBefore = 0,
    int lckAfter = 0,
    List<String> lootUnlocked = const [],
    List<MilestoneEvent> milestoneEvents = const [],
  }) => FinishResult(
    completion: completion,
    earnedXP: 50,
    oldTotalXP: oldTotalXP,
    newTotalXP: newTotalXP,
    statDelta: statDelta,
    afterStats: afterStats,
    lckBefore: lckBefore,
    lckAfter: lckAfter,
    lootUnlocked: lootUnlocked,
    elapsedSeconds: 1800,
    totalSets: 6,
    exerciseCount: 3,
    estimatedCalories: 120,
    milestoneEvents: milestoneEvents,
  );

  test('rank promotion is the top hero at Tier 3', () {
    // STR 90 → 100 crosses D→C.
    final sel = selectHero(
      result(statDelta: {'STR': 10}, afterStats: {'STR': 100}),
    );
    expect(sel.hero.kind, HeroKind.rankPromotion);
    expect(sel.hero.tier, FinishTier.tier3);
    expect(sel.hero.stat, 'STR');
    expect(sel.hero.fromRank, 'D');
    expect(sel.hero.toRank, 'C');
  });

  test('level-up wins when no rank promotion, at Tier 3', () {
    final sel = selectHero(
      result(
        oldTotalXP: 0, // level 1
        newTotalXP: 20, // level 2
        statDelta: {'STR': 3},
        afterStats: {'STR': 50},
      ),
    );
    expect(sel.hero.kind, HeroKind.levelUp);
    expect(sel.hero.tier, FinishTier.tier3);
    expect(sel.hero.amount, 2); // new level
  });

  test('diamond milestone wins over loot and gain', () {
    final sel = selectHero(
      result(
        lckBefore: 0, // 0 diamonds
        lckAfter: 1, // 1 diamond (first clean week)
        statDelta: {'AGI': 4},
        afterStats: {'AGI': 50},
        lootUnlocked: ['frame_x'],
      ),
    );
    expect(sel.hero.kind, HeroKind.diamondMilestone);
    expect(sel.hero.tier, FinishTier.tier3);
    expect(sel.hero.amount, 1); // new diamond count
    // Loot demotes to a secondary badge — never a second big beat.
    expect(
      sel.secondaryBadges.map((b) => b.kind),
      contains(HeroKind.lootUnlock),
    );
    expect(
      sel.secondaryBadges.every((b) => b.tier != FinishTier.tier3),
      isTrue,
    );
  });

  test('loot unlock wins over an ordinary gain, at Tier 2', () {
    final sel = selectHero(
      result(
        statDelta: {'STR': 4},
        afterStats: {'STR': 50},
        lootUnlocked: ['frame_x'],
      ),
    );
    expect(sel.hero.kind, HeroKind.lootUnlock);
    expect(sel.hero.tier, FinishTier.tier2);
    expect(sel.hero.lootId, 'frame_x');
  });

  test('milestone events can drive a valley loot hero', () {
    final sel = selectHero(
      result(
        statDelta: {'STR': 2},
        afterStats: {'STR': 430},
        milestoneEvents: const [
          MilestoneEvent(
            kind: MilestoneKind.lootUnlock,
            label: 'NEON FRAME',
            lootId: 'frame_neon',
          ),
        ],
      ),
    );

    expect(sel.hero.kind, HeroKind.lootUnlock);
    expect(sel.hero.tier, FinishTier.tier2);
    expect(sel.hero.lootId, 'frame_neon');
  });

  test('largest gain is the default hero; Tier 2 only above the threshold', () {
    final big = selectHero(
      result(
        statDelta: {'STR': 12, 'AGI': 4},
        afterStats: {'STR': 200, 'AGI': 60},
      ),
    );
    expect(big.hero.kind, HeroKind.statGain);
    expect(big.hero.stat, 'STR');
    expect(big.hero.amount, 12);
    expect(big.hero.tier, FinishTier.tier2);

    final small = selectHero(
      result(statDelta: {'AGI': 5}, afterStats: {'AGI': 60}),
    );
    expect(small.hero.kind, HeroKind.statGain);
    expect(small.hero.tier, FinishTier.tier1);
  });

  test('DEF and VIT can never be the stat-gain hero', () {
    final sel = selectHero(
      result(
        statDelta: {'DEF': 30, 'VIT': 40, 'AGI': 3},
        afterStats: {'DEF': 200, 'VIT': 90, 'AGI': 50},
      ),
    );
    expect(sel.hero.kind, HeroKind.statGain);
    expect(sel.hero.stat, 'AGI'); // not DEF/VIT despite larger numbers
  });

  test('a higher hero demotes other fired events to secondary badges', () {
    // Rank promo (hero) + loot (secondary). A co-occurring level-up is NOT a
    // secondary chip — the XP meter owns the level display (strict single-peak),
    // so it never duplicates as `LV n`.
    final sel = selectHero(
      result(
        oldTotalXP: 40,
        newTotalXP: 60, // a level-up that loses the ladder to the rank-up
        statDelta: {'STR': 10},
        afterStats: {'STR': 100},
        lootUnlocked: ['frame_x'],
      ),
    );
    expect(sel.hero.kind, HeroKind.rankPromotion);
    // Loot demotes to a secondary badge.
    expect(
      sel.secondaryBadges.map((b) => b.kind),
      contains(HeroKind.lootUnlock),
    );
    // Level-up is shown by the meter, never as a chip.
    expect(
      sel.secondaryBadges.map((b) => b.kind),
      isNot(contains(HeroKind.levelUp)),
    );
    // The default largest-gain (5) is NOT also shown as a badge.
    expect(
      sel.secondaryBadges.map((b) => b.kind),
      isNot(contains(HeroKind.statGain)),
    );
  });

  test('zero-gain / recovery day yields an honest recovery hero', () {
    final sel = selectHero(result(statDelta: const {}, afterStats: const {}));
    expect(sel.hero.kind, HeroKind.recovery);
    expect(sel.secondaryBadges, isEmpty);
  });

  test('partial and abandoned sessions never fire a Tier-3 beat', () {
    final partial = selectHero(
      result(
        completion: FinishCompletion.partial,
        oldTotalXP: 40,
        newTotalXP: 60, // would be a level-up
        statDelta: {'STR': 10},
        afterStats: {'STR': 100}, // would be a rank promo
      ),
    );
    expect(partial.hero.tier, FinishTier.tier1);

    final abandoned = selectHero(
      result(completion: FinishCompletion.abandoned),
    );
    expect(abandoned.hero.tier, FinishTier.tier1);
  });

  test('a real title cross adds a title chip to the secondary badges', () {
    // Level 4 (Recruit) -> level 5 (Squire) crosses the Squire title threshold.
    final sel = selectHero(
      result(
        oldTotalXP: 100,
        newTotalXP: 200,
        statDelta: {'STR': 3},
        afterStats: {'STR': 50},
      ),
    );
    expect(sel.hero.kind, HeroKind.levelUp);
    final titles = sel.secondaryBadges.where(
      (b) => b.kind == HeroKind.titleUnlock,
    );
    expect(titles.length, 1);
    expect(titles.first.title, 'Squire');
  });

  test('a level-up with no title change adds no title chip', () {
    // Level 1 -> 2: still Recruit, no new title.
    final sel = selectHero(result(oldTotalXP: 0, newTotalXP: 65));
    expect(sel.hero.kind, HeroKind.levelUp);
    expect(
      sel.secondaryBadges.any((b) => b.kind == HeroKind.titleUnlock),
      isFalse,
    );
  });

  group('supportingGains (the STAT GAINS row)', () {
    test('a rank-up hero keeps its own stat — the +N must render somewhere', () {
      final sel = selectHero(
        result(statDelta: {'STR': 10, 'AGI': 3}, afterStats: {'STR': 100}),
      );
      expect(sel.hero.kind, HeroKind.rankPromotion);
      expect(
        supportingGains({'STR': 10, 'AGI': 3}, sel.hero),
        {'STR': 10, 'AGI': 3},
      );
    });

    test('a statGain hero excludes its own stat (already the headline)', () {
      final sel = selectHero(
        result(statDelta: {'STR': 8, 'END': 2}, afterStats: {'STR': 50}),
      );
      expect(sel.hero.kind, HeroKind.statGain);
      expect(sel.hero.stat, 'STR');
      expect(supportingGains({'STR': 8, 'END': 2}, sel.hero), {'END': 2});
    });

    test('a level-up hero keeps all gains (none are shown elsewhere)', () {
      final sel = selectHero(
        result(
          oldTotalXP: 40,
          newTotalXP: 60,
          statDelta: {'STR': 5, 'AGI': 2},
          afterStats: {'STR': 50},
        ),
      );
      expect(sel.hero.kind, HeroKind.levelUp);
      expect(
        supportingGains({'STR': 5, 'AGI': 2}, sel.hero),
        {'STR': 5, 'AGI': 2},
      );
    });

    test('negative and zero deltas never render', () {
      final sel = selectHero(
        result(oldTotalXP: 40, newTotalXP: 60, statDelta: const {'STR': -4}),
      );
      expect(supportingGains({'STR': -4, 'AGI': 0}, sel.hero), isEmpty);
    });
  });
}
