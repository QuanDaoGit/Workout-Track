class OverloadSuggestion {
  const OverloadSuggestion({this.weight, this.reps});

  final double? weight;
  final int? reps;
}

class OverloadDelta {
  const OverloadDelta({required this.weightDiff, required this.repsDiff});

  final double weightDiff;
  final int repsDiff;
}
