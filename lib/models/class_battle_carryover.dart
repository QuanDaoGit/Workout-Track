class ClassBattleCarryover {
  const ClassBattleCarryover({
    this.nextBattleCritBonus = 0,
    this.nextBattleDamageMult = 1.0,
    this.bruiserBattleWinCounter = 0,
  });

  /// Phantom Edge: +10 crit chance for next battle.
  final int nextBattleCritBonus;

  /// Iron Tide: 1.5x damage for next battle (first hit only).
  final double nextBattleDamageMult;

  /// Tracks consecutive battle wins for Iron Tide trigger (every 5th).
  final int bruiserBattleWinCounter;

  ClassBattleCarryover copyWith({
    int? nextBattleCritBonus,
    double? nextBattleDamageMult,
    int? bruiserBattleWinCounter,
  }) =>
      ClassBattleCarryover(
        nextBattleCritBonus: nextBattleCritBonus ?? this.nextBattleCritBonus,
        nextBattleDamageMult: nextBattleDamageMult ?? this.nextBattleDamageMult,
        bruiserBattleWinCounter:
            bruiserBattleWinCounter ?? this.bruiserBattleWinCounter,
      );

  Map<String, dynamic> toJson() => {
    'nextBattleCritBonus': nextBattleCritBonus,
    'nextBattleDamageMult': nextBattleDamageMult,
    'bruiserBattleWinCounter': bruiserBattleWinCounter,
  };

  factory ClassBattleCarryover.fromJson(Map<String, dynamic> json) =>
      ClassBattleCarryover(
        nextBattleCritBonus: json['nextBattleCritBonus'] as int? ?? 0,
        nextBattleDamageMult:
            (json['nextBattleDamageMult'] as num?)?.toDouble() ?? 1.0,
        bruiserBattleWinCounter:
            json['bruiserBattleWinCounter'] as int? ?? 0,
      );
}
