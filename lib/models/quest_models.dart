enum QuestCategory { daily, weekly, side }

class QuestClaim {
  const QuestClaim({
    required this.xp,
    required this.gems,
    required this.claimedAt,
    this.title,
  });

  final int xp;
  final int gems;
  final DateTime claimedAt;
  final String? title;

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'gems': gems,
    'claimedAt': claimedAt.toIso8601String(),
    'title': title,
  };

  factory QuestClaim.fromJson(Map<String, dynamic> json) => QuestClaim(
    xp: (json['xp'] as num?)?.toInt() ?? 0,
    gems: (json['gems'] as num?)?.toInt() ?? 0,
    claimedAt:
        DateTime.tryParse(json['claimedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    title: json['title'] as String?,
  );
}

class QuestClaimResult {
  const QuestClaimResult({required this.xp, required this.gems, this.title});

  final int xp;
  final int gems;
  final String? title;
}

class QuestState {
  const QuestState({
    required this.dailyPeriodKey,
    required this.weeklyPeriodKey,
    required this.manualDoneKeys,
    required this.claims,
    this.selectedTitle,
  });

  final String dailyPeriodKey;
  final String weeklyPeriodKey;
  final Set<String> manualDoneKeys;
  final Map<String, QuestClaim> claims;
  final String? selectedTitle;

  int get claimedXP => claims.values.fold(0, (sum, claim) => sum + claim.xp);
  int get claimedGems =>
      claims.values.fold(0, (sum, claim) => sum + claim.gems);

  QuestState copyWith({
    String? dailyPeriodKey,
    String? weeklyPeriodKey,
    Set<String>? manualDoneKeys,
    Map<String, QuestClaim>? claims,
    String? selectedTitle,
    bool clearSelectedTitle = false,
  }) {
    return QuestState(
      dailyPeriodKey: dailyPeriodKey ?? this.dailyPeriodKey,
      weeklyPeriodKey: weeklyPeriodKey ?? this.weeklyPeriodKey,
      manualDoneKeys: manualDoneKeys ?? this.manualDoneKeys,
      claims: claims ?? this.claims,
      selectedTitle: clearSelectedTitle
          ? null
          : selectedTitle ?? this.selectedTitle,
    );
  }

  Map<String, dynamic> toJson() => {
    'dailyPeriodKey': dailyPeriodKey,
    'weeklyPeriodKey': weeklyPeriodKey,
    'manualDoneKeys': manualDoneKeys.toList()..sort(),
    'claims': claims.map((key, claim) => MapEntry(key, claim.toJson())),
    'selectedTitle': selectedTitle,
  };

  factory QuestState.fromJson(Map<String, dynamic> json) => QuestState(
    dailyPeriodKey: json['dailyPeriodKey'] as String? ?? '',
    weeklyPeriodKey: json['weeklyPeriodKey'] as String? ?? '',
    manualDoneKeys:
        (json['manualDoneKeys'] as List<dynamic>?)?.cast<String>().toSet() ??
        <String>{},
    claims: {
      for (final entry
          in (json['claims'] as Map<String, dynamic>? ?? {}).entries)
        entry.key: QuestClaim.fromJson(entry.value as Map<String, dynamic>),
    },
    selectedTitle: json['selectedTitle'] as String?,
  );

  factory QuestState.empty({
    required String dailyPeriodKey,
    required String weeklyPeriodKey,
  }) => QuestState(
    dailyPeriodKey: dailyPeriodKey,
    weeklyPeriodKey: weeklyPeriodKey,
    manualDoneKeys: <String>{},
    claims: <String, QuestClaim>{},
  );
}

class QuestItem {
  const QuestItem({
    required this.id,
    required this.claimKey,
    required this.category,
    required this.title,
    required this.description,
    required this.rewardXP,
    required this.rewardGems,
    required this.completed,
    required this.claimed,
    required this.isManual,
    this.progressLabel,
    this.rewardTitle,
  });

  final String id;
  final String claimKey;
  final QuestCategory category;
  final String title;
  final String description;
  final int rewardXP;
  final int rewardGems;
  final bool completed;
  final bool claimed;
  final bool isManual;
  final String? progressLabel;
  final String? rewardTitle;

  bool get claimable => completed && !claimed;
}

class QuestSummary {
  const QuestSummary({
    required this.dailyQuests,
    required this.weeklyQuests,
    required this.sideQuests,
    required this.claimedRewardXP,
    required this.claimedRewardGems,
    required this.todayClaimedXP,
    required this.todayClaimedGems,
  });

  final List<QuestItem> dailyQuests;
  final List<QuestItem> weeklyQuests;
  final List<QuestItem> sideQuests;
  final int claimedRewardXP;
  final int claimedRewardGems;
  final int todayClaimedXP;
  final int todayClaimedGems;

  int get weeklyCompleted =>
      weeklyQuests.where((quest) => quest.completed).length;
  int get weeklyTotal => weeklyQuests.length;

  int get claimableCount => [
    ...dailyQuests,
    ...weeklyQuests,
    ...sideQuests,
  ].where((quest) => quest.claimable).length;
}
