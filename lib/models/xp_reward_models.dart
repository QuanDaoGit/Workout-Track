class SessionRewardEligibility {
  const SessionRewardEligibility({
    required this.eligible,
    required this.reason,
  });

  final bool eligible;
  final String reason;
}

class SessionXpBreakdown {
  const SessionXpBreakdown({
    required this.eligibility,
    required this.baseXP,
    required this.lckMultiplier,
    required this.potionMultiplier,
    required this.lootBonusXP,
  });

  final SessionRewardEligibility eligibility;
  final int baseXP;
  final double lckMultiplier;
  final double potionMultiplier;
  final int lootBonusXP;

  int get multipliedWorkoutXP => eligibility.eligible
      ? (baseXP * lckMultiplier * potionMultiplier).round()
      : 0;

  int get potionBonusXP => eligibility.eligible
      ? (baseXP * lckMultiplier * (potionMultiplier - 1.0)).round()
      : 0;

  int get finalXP => multipliedWorkoutXP + lootBonusXP;
}
