import '../data/loot_registry.dart';
import '../data/muscle_groups.dart';
import '../models/loot_unlock_rule.dart';
import '../models/milestone_models.dart';
import '../models/workout_models.dart';
import 'stat_engine.dart';
import 'xp_service.dart';

class MilestoneService {
  const MilestoneService._();

  static MilestoneSnapshot snapshotFromSessions({
    required List<WorkoutSession> sessions,
    required Map<String, int> stats,
    required int totalXP,
    required int lck,
    Set<String> ownedLootIds = const {},
    Map<String, String> primaryMuscleByExerciseId = const {},
  }) {
    final completed = sessions.where((session) => !session.isPartial).toList();
    final muscleSessionCounts = <String, int>{};
    final muscleVolumes = <String, double>{};
    var lifetimeReps = 0;
    var lifetimeVolume = 0.0;

    for (final session in completed) {
      for (final muscle in session.targetMuscleGroups) {
        muscleSessionCounts[muscle] = (muscleSessionCounts[muscle] ?? 0) + 1;
      }
      for (final log in session.exercises) {
        final volume = log.totalVolume;
        lifetimeVolume += volume;
        lifetimeReps += log.sets.fold(0, (sum, set) => sum + set.reps);

        final primary = primaryMuscleByExerciseId[log.exerciseId];
        final bucket = primary == null ? null : muscleGroupForDetailed(primary);
        if (bucket != null) {
          muscleVolumes[bucket] = (muscleVolumes[bucket] ?? 0) + volume;
        } else if (session.targetMuscleGroups.isNotEmpty) {
          final split = volume / session.targetMuscleGroups.length;
          for (final target in session.targetMuscleGroups) {
            muscleVolumes[target] = (muscleVolumes[target] ?? 0) + split;
          }
        }
      }
    }

    return MilestoneSnapshot(
      stats: stats,
      totalXP: totalXP,
      lck: lck,
      ownedLootIds: ownedLootIds,
      completedSessions: completed.length,
      lifetimeReps: lifetimeReps,
      lifetimeVolume: lifetimeVolume,
      muscleSessionCounts: muscleSessionCounts,
      muscleVolumes: muscleVolumes,
    );
  }

  static List<MilestoneEvent> milestonesCrossed(
    MilestoneSnapshot before,
    MilestoneSnapshot after, {
    List<String>? lootUnlocked,
  }) {
    final events = <MilestoneEvent>[
      ..._rankEvents(before, after),
      ..._levelEvents(before, after),
      ..._diamondEvents(before, after),
      ..._lootEvents(before, after, lootUnlocked: lootUnlocked),
    ];
    return events;
  }

  static List<MilestoneHorizon> nextMilestones(
    MilestoneSnapshot current, {
    int limit = 3,
  }) {
    final horizons = <MilestoneHorizon>[];

    final nextLevelXP = XpService.xpForNextLevel(
      XpService.getLevel(current.totalXP),
    );
    if (nextLevelXP < 99999) {
      horizons.add(
        MilestoneHorizon(
          kind: MilestoneKind.levelUp,
          label: 'LEVEL ${XpService.getLevel(nextLevelXP)}',
          hint: 'A new level waits ahead.',
        ),
      );
    }

    final nextDiamond = _nextDiamond(current.lck);
    if (nextDiamond != null) {
      horizons.add(
        MilestoneHorizon(
          kind: MilestoneKind.diamondMilestone,
          label: 'LCK DIAMOND',
          hint: 'Consistency sharpens your luck.',
        ),
      );
    }

    for (final item in lootRegistry) {
      final rule = item.unlockRule;
      if (rule == null || current.ownedLootIds.contains(item.id)) continue;
      if (_meetsLootRule(current, rule)) continue;
      horizons.add(
        MilestoneHorizon(
          kind: MilestoneKind.lootUnlock,
          label: item.name.toUpperCase(),
          hint: item.unlockRule?.displayHint ?? 'Keep training to earn it.',
          lootId: item.id,
        ),
      );
    }

    return horizons.take(limit).toList(growable: false);
  }

  static List<MilestoneEvent> _rankEvents(
    MilestoneSnapshot before,
    MilestoneSnapshot after,
  ) {
    final engine = StatEngine();
    final events = <MilestoneEvent>[];
    for (final stat in MilestoneSnapshot.growthStats) {
      final beforeValue = before.stats[stat] ?? 0;
      final afterValue = after.stats[stat] ?? 0;
      final fromRank = engine.getRank(beforeValue);
      final toRank = engine.getRank(afterValue);
      if (fromRank == toRank) continue;
      events.add(
        MilestoneEvent(
          kind: MilestoneKind.rankPromotion,
          label: '$stat $fromRank->$toRank',
          stat: stat,
          fromRank: fromRank,
          toRank: toRank,
          valueBefore: beforeValue,
          valueAfter: afterValue,
        ),
      );
    }
    return events;
  }

  static List<MilestoneEvent> _levelEvents(
    MilestoneSnapshot before,
    MilestoneSnapshot after,
  ) {
    final beforeLevel = XpService.getLevel(before.totalXP);
    final afterLevel = XpService.getLevel(after.totalXP);
    if (afterLevel <= beforeLevel) return const [];
    return [
      MilestoneEvent(
        kind: MilestoneKind.levelUp,
        label: 'LEVEL $afterLevel',
        valueBefore: beforeLevel,
        valueAfter: afterLevel,
      ),
    ];
  }

  static List<MilestoneEvent> _diamondEvents(
    MilestoneSnapshot before,
    MilestoneSnapshot after,
  ) {
    final beforeDiamonds = XpService.lckDiamondCount(before.lck);
    final afterDiamonds = XpService.lckDiamondCount(after.lck);
    if (afterDiamonds <= beforeDiamonds) return const [];
    return [
      MilestoneEvent(
        kind: MilestoneKind.diamondMilestone,
        label: 'LCK DIAMOND',
        valueBefore: beforeDiamonds,
        valueAfter: afterDiamonds,
      ),
    ];
  }

  static List<MilestoneEvent> _lootEvents(
    MilestoneSnapshot before,
    MilestoneSnapshot after, {
    List<String>? lootUnlocked,
  }) {
    if (lootUnlocked != null) {
      return [
        for (final id in lootUnlocked)
          MilestoneEvent(
            kind: MilestoneKind.lootUnlock,
            label: lootItemById(id)?.name.toUpperCase() ?? id.toUpperCase(),
            lootId: id,
          ),
      ];
    }

    final events = <MilestoneEvent>[];
    for (final item in lootRegistry) {
      final rule = item.unlockRule;
      if (rule == null || before.ownedLootIds.contains(item.id)) continue;
      if (!_meetsLootRule(before, rule) && _meetsLootRule(after, rule)) {
        events.add(
          MilestoneEvent(
            kind: MilestoneKind.lootUnlock,
            label: item.name.toUpperCase(),
            lootId: item.id,
          ),
        );
      }
    }
    return events;
  }

  static bool meetsLootRule(MilestoneSnapshot snapshot, LootUnlockRule rule) =>
      _meetsLootRule(snapshot, rule);

  static bool _meetsLootRule(MilestoneSnapshot snapshot, LootUnlockRule rule) {
    switch (rule.kind) {
      case UnlockKind.sessions:
        return snapshot.completedSessions >= rule.threshold;
      case UnlockKind.lifetimeVolume:
        return snapshot.lifetimeVolume >= rule.threshold;
      case UnlockKind.lifetimeReps:
        return snapshot.lifetimeReps >= rule.threshold;
      case UnlockKind.muscleSessions:
        final group = rule.muscleGroup;
        if (group == null) return false;
        return (snapshot.muscleSessionCounts[group] ?? 0) >= rule.threshold;
      case UnlockKind.muscleVolume:
        final group = rule.muscleGroup;
        if (group == null) return false;
        return (snapshot.muscleVolumes[group] ?? 0) >= rule.threshold;
      case UnlockKind.statThreshold:
        final key = rule.statKey;
        if (key == null) return false;
        if (!MilestoneSnapshot.growthStats.contains(key)) return false;
        return (snapshot.stats[key] ?? 0) >= rule.threshold;
      case UnlockKind.anyStatThreshold:
        return MilestoneSnapshot.growthStats.any(
          (stat) => (snapshot.stats[stat] ?? 0) >= rule.threshold,
        );
      case UnlockKind.allStatsAbove:
        return MilestoneSnapshot.growthStats.every(
          (stat) => (snapshot.stats[stat] ?? 0) >= rule.threshold,
        );
    }
  }

  static int? _nextDiamond(int lck) {
    for (final threshold in XpService.lckDiamondWeekThresholds) {
      if (lck < threshold) return threshold;
    }
    return null;
  }
}
