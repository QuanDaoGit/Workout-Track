enum UnlockKind {
  sessions,
  lifetimeVolume,
  lifetimeReps,
  muscleSessions,
  muscleVolume,
  statThreshold,
  anyStatThreshold,
  allStatsAbove,
}

class LootUnlockRule {
  const LootUnlockRule({
    required this.kind,
    required this.threshold,
    this.muscleGroup,
    this.statKey,
  });

  final UnlockKind kind;
  final num threshold;
  final String? muscleGroup;
  final String? statKey;

  String get displayHint {
    switch (kind) {
      case UnlockKind.sessions:
        return 'COMPLETE ${threshold.toInt()} SESSIONS';
      case UnlockKind.lifetimeVolume:
        return 'LIFT ${threshold.toInt()} KG LIFETIME';
      case UnlockKind.lifetimeReps:
        return 'LOG ${threshold.toInt()} REPS LIFETIME';
      case UnlockKind.muscleSessions:
        return 'COMPLETE ${threshold.toInt()} ${(muscleGroup ?? '').toUpperCase()} SESSIONS';
      case UnlockKind.muscleVolume:
        return 'LIFT ${threshold.toInt()} KG ${(muscleGroup ?? '').toUpperCase()}';
      case UnlockKind.statThreshold:
        return 'REACH $statKey ${threshold.toInt()}';
      case UnlockKind.anyStatThreshold:
        return 'ANY STAT ${threshold.toInt()}';
      case UnlockKind.allStatsAbove:
        return 'ALL STATS ABOVE ${threshold.toInt()}';
    }
  }
}
