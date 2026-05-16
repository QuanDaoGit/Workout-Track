class XpBoostPotion {
  const XpBoostPotion({
    required this.id,
    required this.grantedAt,
    required this.expiresAt,
    this.multiplier = 2.0,
    this.isDirectionBonus = false,
  });

  final String id;
  final DateTime grantedAt;
  final DateTime expiresAt;
  final double multiplier;
  final bool isDirectionBonus;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingDuration {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'grantedAt': grantedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'multiplier': multiplier,
    'isDirectionBonus': isDirectionBonus,
  };

  factory XpBoostPotion.fromJson(Map<String, dynamic> json) => XpBoostPotion(
    id: json['id'] as String,
    grantedAt: DateTime.parse(json['grantedAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    multiplier: (json['multiplier'] as num?)?.toDouble() ?? 2.0,
    isDirectionBonus: json['isDirectionBonus'] as bool? ?? false,
  );
}
