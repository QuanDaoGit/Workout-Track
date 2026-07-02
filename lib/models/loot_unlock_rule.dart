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
        return 'Earned through completed training sessions.';
      case UnlockKind.lifetimeVolume:
        return 'Earned through lifetime training volume.';
      case UnlockKind.lifetimeReps:
        return 'Earned through lifetime saved reps.';
      case UnlockKind.muscleSessions:
        return 'Earned by returning to ${muscleGroup ?? 'this focus'}.';
      case UnlockKind.muscleVolume:
        return 'Earned by building ${muscleGroup ?? 'focused'} volume.';
      case UnlockKind.statThreshold:
        return 'Earned as your ${statKey ?? 'stat'} rank climbs.';
      case UnlockKind.anyStatThreshold:
        return 'Earned as one combat stat climbs.';
      case UnlockKind.allStatsAbove:
        return 'Earned by raising your combat stats together.';
    }
  }
}
