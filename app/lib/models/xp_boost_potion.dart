class XpBoostPotion {
  const XpBoostPotion({
    required this.id,
    required this.grantedAt,
    required this.expiresAt,
    this.multiplier = 2.0,
    this.isDirectionBonus = false,
    this.chargesRemaining = maxCharges,
  });

  /// Charges a freshly granted potion starts with. One charge is spent per
  /// eligible workout save (next-N-workouts model).
  static const int maxCharges = 3;

  final String id;
  final DateTime grantedAt;
  final DateTime expiresAt;
  final double multiplier;
  final bool isDirectionBonus;

  /// Eligible-workout charges left. Potion is removed when this hits 0.
  final int chargesRemaining;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingDuration {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  XpBoostPotion copyWith({int? chargesRemaining}) => XpBoostPotion(
    id: id,
    grantedAt: grantedAt,
    expiresAt: expiresAt,
    multiplier: multiplier,
    isDirectionBonus: isDirectionBonus,
    chargesRemaining: chargesRemaining ?? this.chargesRemaining,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'grantedAt': grantedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'multiplier': multiplier,
    'isDirectionBonus': isDirectionBonus,
    'chargesRemaining': chargesRemaining,
  };

  factory XpBoostPotion.fromJson(Map<String, dynamic> json) => XpBoostPotion(
    id: json['id'] as String,
    grantedAt: DateTime.parse(json['grantedAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    multiplier: (json['multiplier'] as num?)?.toDouble() ?? 2.0,
    isDirectionBonus: json['isDirectionBonus'] as bool? ?? false,
    chargesRemaining: (json['chargesRemaining'] as num?)?.toInt() ?? maxCharges,
  );
}
