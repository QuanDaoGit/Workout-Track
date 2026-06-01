import 'workout_models.dart';

/// Why a particular progression suggestion was produced. Drives the visual
/// treatment of the `TRY:` line on Set 1.
enum OverloadReason {
  /// Hit or exceeded the rep target last time -> step up the weight.
  weightIncrease,

  /// Missed the target by a small margin -> repeat the load and finish it.
  repTarget,

  /// Missed the target by a larger margin -> step the weight down.
  deload,

  /// 14+ days since the last session -> come back slightly lighter.
  detrained,
}

class OverloadSuggestion {
  const OverloadSuggestion({
    this.weight,
    this.reps,
    this.reason,
    this.confidenceHigh = false,
    this.setsLogged = 0,
    this.appliedByUser = false,
  });

  final double? weight;
  final int? reps;
  final OverloadReason? reason;
  final bool confidenceHigh;
  final int setsLogged;

  /// Service-generated suggestions always start false; UI code can persist a
  /// separate applied state without mutating the service result.
  final bool appliedByUser;
}

class ExerciseProgressionSnapshot {
  const ExerciseProgressionSnapshot({
    required this.exerciseId,
    required this.totalSetsLogged,
    required this.lastSessionAt,
    required this.lastSets,
    required this.topSet,
    required this.targetReps,
    required this.isBodyweight,
    required this.estimatedOneRepMax,
  });

  final String exerciseId;
  final int totalSetsLogged;
  final DateTime lastSessionAt;
  final List<SetEntry> lastSets;
  final SetEntry topSet;
  final int targetReps;
  final bool isBodyweight;
  final double estimatedOneRepMax;
}

class OverloadDelta {
  const OverloadDelta({required this.weightDiff, required this.repsDiff});

  final double weightDiff;
  final int repsDiff;
}
