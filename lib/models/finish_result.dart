import '../services/stat_engine.dart';
import '../services/xp_service.dart';

/// Completion status of the finished session (drives the muted-tone paths).
enum FinishCompletion { complete, partial, abandoned }

/// The headline event a finished session produced.
enum HeroKind {
  rankPromotion,
  levelUp,
  diamondMilestone,
  lootUnlock,
  statGain,
  recovery,
}

/// Celebration intensity. Tier 3 (the "orchestra") is reserved for rank
/// promotions, level-ups, and diamond milestones.
enum FinishTier { tier1, tier2, tier3 }

/// A single-session top stat delta at or above this earns a Tier-2 medium beat.
/// Tunable. Self-reserving: the engine's diminishing-returns curve
/// (`floor(100·log(vol/500+1))`) means early/first sessions clear it while
/// mid/late sessions rarely do.
const int kFinishTier2GainThreshold = 10;

/// Visible capability stats eligible to be the "largest gain" hero. DEF is
/// hidden (`kDefVisible=false`), VIT is the recovery meter, LCK is a milestone —
/// none can headline as a stat gain.
const List<String> kHeroStatCandidates = ['STR', 'AGI', 'END'];

/// One headline or secondary event, with enough raw data for the widget to
/// format. (Formatting lives in the widget, not here, so this stays testable.)
class FinishHero {
  const FinishHero({
    required this.kind,
    required this.tier,
    this.stat,
    this.amount = 0,
    this.fromRank,
    this.toRank,
    this.lootId,
  });

  final HeroKind kind;
  final FinishTier tier;

  /// Stat name for [HeroKind.rankPromotion] / [HeroKind.statGain].
  final String? stat;

  /// Delta (statGain), new level (levelUp), or new diamond count (diamond).
  final int amount;

  /// Rank letters for [HeroKind.rankPromotion].
  final String? fromRank;
  final String? toRank;

  /// Loot id for [HeroKind.lootUnlock].
  final String? lootId;

  FinishHero copyWith({FinishTier? tier}) => FinishHero(
    kind: kind,
    tier: tier ?? this.tier,
    stat: stat,
    amount: amount,
    fromRank: fromRank,
    toRank: toRank,
    lootId: lootId,
  );
}

/// The chosen hero plus any non-hero events shown as smaller secondary badges.
class FinishSelection {
  const FinishSelection({required this.hero, this.secondaryBadges = const []});

  final FinishHero hero;
  final List<FinishHero> secondaryBadges;
}

/// Immutable view model the finish arc consumes. Built from the engine's
/// already-computed outputs plus a before-snapshot captured before the save.
class FinishResult {
  const FinishResult({
    required this.completion,
    required this.earnedXP,
    required this.oldTotalXP,
    required this.newTotalXP,
    required this.statDelta,
    required this.afterStats,
    required this.lckBefore,
    required this.lckAfter,
    required this.lootUnlocked,
    required this.elapsedSeconds,
    required this.totalSets,
    required this.exerciseCount,
    required this.estimatedCalories,
  });

  final FinishCompletion completion;
  final int earnedXP;
  final int oldTotalXP;
  final int newTotalXP;

  /// Per-stat last-session delta (only stats this session touched).
  final Map<String, int> statDelta;

  /// Combat stats after this session.
  final Map<String, int> afterStats;

  final int lckBefore;
  final int lckAfter;
  final List<String> lootUnlocked;

  final int elapsedSeconds;
  final int totalSets;
  final int exerciseCount;
  final int estimatedCalories;

  int get levelBefore => XpService.getLevel(oldTotalXP);
  int get levelAfter => XpService.getLevel(newTotalXP);
  int get diamondsBefore => XpService.lckDiamondCount(lckBefore);
  int get diamondsAfter => XpService.lckDiamondCount(lckAfter);
  bool get leveledUp => levelAfter > levelBefore;
  bool get crossedDiamond => diamondsAfter > diamondsBefore;
}

/// Pure hero/tier selection per the design's priority ladder. No IO — depends
/// only on [FinishResult] plus the engine's stateless rank logic, so it is
/// unit-testable in isolation.
FinishSelection selectHero(FinishResult r) {
  final engine = StatEngine();

  // 1. Rank promotion among the visible capability stats (best after-rank wins).
  FinishHero? rankPromo;
  for (final stat in kHeroStatCandidates) {
    final delta = r.statDelta[stat] ?? 0;
    if (delta <= 0) continue;
    final after = r.afterStats[stat] ?? 0;
    final before = after - delta;
    final fromRank = engine.getRank(before);
    final toRank = engine.getRank(after);
    if (fromRank == toRank) continue;
    if (rankPromo == null || after > (r.afterStats[rankPromo.stat] ?? 0)) {
      rankPromo = FinishHero(
        kind: HeroKind.rankPromotion,
        tier: FinishTier.tier3,
        stat: stat,
        amount: delta,
        fromRank: fromRank,
        toRank: toRank,
      );
    }
  }

  // 2. Level-up.
  final levelUp = r.leveledUp
      ? FinishHero(
          kind: HeroKind.levelUp,
          tier: FinishTier.tier3,
          amount: r.levelAfter,
        )
      : null;

  // 3. Streak / diamond milestone.
  final diamond = r.crossedDiamond
      ? FinishHero(
          kind: HeroKind.diamondMilestone,
          tier: FinishTier.tier3,
          amount: r.diamondsAfter,
        )
      : null;

  // 4. Loot unlock.
  final loot = r.lootUnlocked.isNotEmpty
      ? FinishHero(
          kind: HeroKind.lootUnlock,
          tier: FinishTier.tier2,
          lootId: r.lootUnlocked.first,
        )
      : null;

  // 5. Largest stat gain among the visible capability stats (default hero).
  String? bestStat;
  var bestDelta = 0;
  for (final stat in kHeroStatCandidates) {
    final delta = r.statDelta[stat] ?? 0;
    if (delta > bestDelta) {
      bestDelta = delta;
      bestStat = stat;
    }
  }
  final statGain = bestStat == null
      ? null
      : FinishHero(
          kind: HeroKind.statGain,
          tier: bestDelta >= kFinishTier2GainThreshold
              ? FinishTier.tier2
              : FinishTier.tier1,
          stat: bestStat,
          amount: bestDelta,
        );

  // Priority ladder 1–4; the highest fired is the hero, the rest are badges.
  // The default largest-gain (5) is only used when none of 1–4 fired (so it
  // never doubles up as a badge under a higher hero).
  final ladder = [
    rankPromo,
    levelUp,
    diamond,
    loot,
  ].whereType<FinishHero>().toList();

  FinishHero hero;
  List<FinishHero> secondary;
  if (ladder.isNotEmpty) {
    hero = ladder.first;
    secondary = ladder.skip(1).toList();
  } else if (statGain != null) {
    hero = statGain;
    secondary = const [];
  } else {
    hero = const FinishHero(kind: HeroKind.recovery, tier: FinishTier.tier1);
    secondary = const [];
  }

  // Muted tone for partial/abandoned: never a reserved Tier-3 celebration.
  if (r.completion != FinishCompletion.complete) {
    hero = hero.copyWith(tier: FinishTier.tier1);
    secondary = [
      for (final badge in secondary) badge.copyWith(tier: FinishTier.tier1),
    ];
  }

  return FinishSelection(hero: hero, secondaryBadges: secondary);
}
