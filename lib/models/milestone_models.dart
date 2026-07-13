enum MilestoneKind { rankPromotion, levelUp, diamondMilestone, lootUnlock }

class MilestoneSnapshot {
  const MilestoneSnapshot({
    required this.stats,
    required this.totalXP,
    required this.lck,
    required this.ownedLootIds,
    required this.completedSessions,
    required this.lifetimeReps,
    required this.lifetimeVolume,
    required this.muscleSessionCounts,
    required this.muscleVolumes,
  });

  /// Visible rankable growth stats. VIT is recovery state and LCK is a streak
  /// multiplier — neither should silently gate visible milestone unlocks.
  static const growthStats = ['STR', 'AGI', 'END'];

  final Map<String, int> stats;
  final int totalXP;
  final int lck;
  final Set<String> ownedLootIds;
  final int completedSessions;
  final int lifetimeReps;
  final double lifetimeVolume;
  final Map<String, int> muscleSessionCounts;
  final Map<String, double> muscleVolumes;
}

class MilestoneEvent {
  const MilestoneEvent({
    required this.kind,
    required this.label,
    this.stat,
    this.lootId,
    this.fromRank,
    this.toRank,
    this.valueBefore = 0,
    this.valueAfter = 0,
  });

  final MilestoneKind kind;
  final String label;
  final String? stat;
  final String? lootId;
  final String? fromRank;
  final String? toRank;
  final int valueBefore;
  final int valueAfter;
}

class MilestoneHorizon {
  const MilestoneHorizon({
    required this.kind,
    required this.label,
    required this.hint,
    this.stat,
    this.lootId,
  });

  final MilestoneKind kind;
  final String label;
  final String hint;
  final String? stat;
  final String? lootId;
}
