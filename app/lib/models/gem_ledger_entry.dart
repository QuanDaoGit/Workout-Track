enum GemLedgerSourceKind {
  quest,
  questBonus,
  cosmeticPurchase,
  demoTopUp,
  adventure,
  warmup,
  guildCache,
}

class GemLedgerEntry {
  const GemLedgerEntry({
    required this.id,
    required this.amount,
    required this.sourceKind,
    required this.sourceId,
    required this.label,
    required this.createdAt,
  });

  final String id;
  final int amount;
  final GemLedgerSourceKind sourceKind;
  final String sourceId;
  final String label;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'sourceKind': sourceKind.name,
    'sourceId': sourceId,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GemLedgerEntry.fromJson(Map<String, dynamic> json) {
    return GemLedgerEntry(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      sourceKind: GemLedgerSourceKind.values.firstWhere(
        (kind) => kind.name == json['sourceKind'],
        orElse: () => GemLedgerSourceKind.quest,
      ),
      sourceId: json['sourceId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
