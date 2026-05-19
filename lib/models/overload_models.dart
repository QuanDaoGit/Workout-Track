/// Why a particular progression suggestion was produced. Drives the visual
/// treatment of the `TRY:` line on Set 1.
enum OverloadReason {
  /// Hit (or exceeded) the rep target last time → step up the weight.
  weightIncrease,

  /// Missed the rep target by a small margin → repeat the weight, try to hit
  /// the target this session.
  repTarget,

  /// Missed the rep target by 4+ reps → step the weight down ("lighter").
  deload,

  /// 21+ days since the last session → repeat the weight, no increase
  /// ("welcome back").
  detrained,
}

class OverloadSuggestion {
  const OverloadSuggestion({this.weight, this.reps, this.reason});

  final double? weight;
  final int? reps;
  final OverloadReason? reason;
}

class OverloadDelta {
  const OverloadDelta({required this.weightDiff, required this.repsDiff});

  final double weightDiff;
  final int repsDiff;
}
