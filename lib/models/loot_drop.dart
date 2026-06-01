enum LootDropTier { common, uncommon, rare, epic }

enum LootDropContentKind { xpBonus, frameFragment, fullItem }

class LootDrop {
  const LootDrop({
    required this.id,
    required this.sessionId,
    required this.tier,
    required this.contentKind,
    required this.awardedAt,
    this.itemId,
    this.xpBonus = 0,
    this.fragmentCount = 0,
    this.assembledItemId,
    this.viewedAt,
  });

  final String id;
  final String sessionId;
  final LootDropTier tier;
  final LootDropContentKind contentKind;
  final DateTime awardedAt;
  final String? itemId;
  final int xpBonus;
  final int fragmentCount;
  final String? assembledItemId;
  final DateTime? viewedAt;

  bool get isRareOrBetter =>
      tier == LootDropTier.rare || tier == LootDropTier.epic;

  LootDrop copyWith({DateTime? viewedAt, String? assembledItemId}) => LootDrop(
    id: id,
    sessionId: sessionId,
    tier: tier,
    contentKind: contentKind,
    awardedAt: awardedAt,
    itemId: itemId,
    xpBonus: xpBonus,
    fragmentCount: fragmentCount,
    assembledItemId: assembledItemId ?? this.assembledItemId,
    viewedAt: viewedAt ?? this.viewedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'tier': tier.name,
    'contentKind': contentKind.name,
    'awardedAt': awardedAt.toIso8601String(),
    if (itemId != null) 'itemId': itemId,
    if (xpBonus != 0) 'xpBonus': xpBonus,
    if (fragmentCount != 0) 'fragmentCount': fragmentCount,
    if (assembledItemId != null) 'assembledItemId': assembledItemId,
    if (viewedAt != null) 'viewedAt': viewedAt!.toIso8601String(),
  };

  factory LootDrop.fromJson(Map<String, dynamic> json) => LootDrop(
    id: json['id'] as String? ?? '',
    sessionId: json['sessionId'] as String? ?? '',
    tier: LootDropTier.values.firstWhere(
      (tier) => tier.name == json['tier'],
      orElse: () => LootDropTier.common,
    ),
    contentKind: LootDropContentKind.values.firstWhere(
      (kind) => kind.name == json['contentKind'],
      orElse: () => LootDropContentKind.xpBonus,
    ),
    awardedAt:
        DateTime.tryParse(json['awardedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    itemId: json['itemId'] as String?,
    xpBonus: (json['xpBonus'] as num?)?.toInt() ?? 0,
    fragmentCount: (json['fragmentCount'] as num?)?.toInt() ?? 0,
    assembledItemId: json['assembledItemId'] as String?,
    viewedAt: DateTime.tryParse(json['viewedAt'] as String? ?? ''),
  );
}

class LootDropState {
  const LootDropState({
    this.rollAttemptsSinceRare = 0,
    this.lastRollAt,
    this.rolledSessionIds = const {},
  });

  final int rollAttemptsSinceRare;
  final DateTime? lastRollAt;
  final Set<String> rolledSessionIds;

  LootDropState copyWith({
    int? rollAttemptsSinceRare,
    DateTime? lastRollAt,
    Set<String>? rolledSessionIds,
  }) => LootDropState(
    rollAttemptsSinceRare: rollAttemptsSinceRare ?? this.rollAttemptsSinceRare,
    lastRollAt: lastRollAt ?? this.lastRollAt,
    rolledSessionIds: rolledSessionIds ?? this.rolledSessionIds,
  );

  Map<String, dynamic> toJson() => {
    'rollAttemptsSinceRare': rollAttemptsSinceRare,
    if (lastRollAt != null) 'lastRollAt': lastRollAt!.toIso8601String(),
    'rolledSessionIds': rolledSessionIds.toList()..sort(),
  };

  factory LootDropState.fromJson(Map<String, dynamic> json) => LootDropState(
    rollAttemptsSinceRare:
        (json['rollAttemptsSinceRare'] as num?)?.toInt() ?? 0,
    lastRollAt: DateTime.tryParse(json['lastRollAt'] as String? ?? ''),
    rolledSessionIds:
        (json['rolledSessionIds'] as List<dynamic>?)?.cast<String>().toSet() ??
        <String>{},
  );
}

class FrameFragmentState {
  const FrameFragmentState({this.counts = const {}});

  final Map<String, int> counts;

  int countFor(String itemId) => counts[itemId] ?? 0;

  FrameFragmentState add(String itemId, int amount) => FrameFragmentState(
    counts: {...counts, itemId: (counts[itemId] ?? 0) + amount},
  );

  Map<String, dynamic> toJson() => counts;

  factory FrameFragmentState.fromJson(Object? raw) {
    if (raw is! Map) return const FrameFragmentState();
    return FrameFragmentState(
      counts: {
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is num)
            entry.key as String: (entry.value as num).toInt(),
      },
    );
  }
}
