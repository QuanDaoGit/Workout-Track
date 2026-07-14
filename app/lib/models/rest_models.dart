class RestRecoveryClaim {
  const RestRecoveryClaim({required this.xp, required this.claimedAt});

  final int xp;
  final DateTime claimedAt;

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'claimedAt': claimedAt.toIso8601String(),
  };

  factory RestRecoveryClaim.fromJson(Map<String, dynamic> json) =>
      RestRecoveryClaim(
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        claimedAt:
            DateTime.tryParse(json['claimedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

enum RestDayKind {
  trainingDay,
  plannedRest,
  protectedMiss,
  unplannedMiss,
  workoutComplete,
  abandonedOnly,
}

class RestDayInfo {
  const RestDayInfo({
    required this.dateKey,
    required this.kind,
    required this.isScheduledTrainingDay,
    required this.hasCompletedWorkout,
    required this.hasRecoveryClaim,
    required this.isProtected,
    required this.recoveryXP,
    required this.shieldCharges,
  });

  final String dateKey;
  final RestDayKind kind;
  final bool isScheduledTrainingDay;
  final bool hasCompletedWorkout;
  final bool hasRecoveryClaim;
  final bool isProtected;
  final int recoveryXP;
  final int shieldCharges;

  bool get isPlannedRestDay => kind == RestDayKind.plannedRest;
}

class RestState {
  const RestState({
    required this.trainingWeekdays,
    required this.recoveryClaims,
    required this.protectedMissDateKeys,
    required this.shieldCharges,
    required this.consecutiveSuccessfulWeeks,
    this.pendingTrainingWeekdays,
    this.pendingStartWeekKey,
    this.lastProcessedWeekKey,
    this.decayChainStartKey,
    this.autoRecoveryStartKey,
    this.appliedDecayUnits = 0,
    this.scheduleByWeekKey = const {},
    this.programRestDateKeys = const {},
    this.programTrainingDateKeys = const {},
  });

  static const defaultTrainingWeekdays = {1, 3, 5};

  final Set<int> trainingWeekdays;
  final Set<int>? pendingTrainingWeekdays;
  final String? pendingStartWeekKey;
  final Map<String, RestRecoveryClaim> recoveryClaims;
  final Set<String> protectedMissDateKeys;
  final int shieldCharges;
  final int consecutiveSuccessfulWeeks;
  final String? lastProcessedWeekKey;
  final String? decayChainStartKey;
  final String? autoRecoveryStartKey;
  final int appliedDecayUnits;
  final Map<String, Set<int>> scheduleByWeekKey;
  final Set<String> programRestDateKeys;
  final Set<String> programTrainingDateKeys;

  RestState copyWith({
    Set<int>? trainingWeekdays,
    Set<int>? pendingTrainingWeekdays,
    String? pendingStartWeekKey,
    Map<String, RestRecoveryClaim>? recoveryClaims,
    Set<String>? protectedMissDateKeys,
    int? shieldCharges,
    int? consecutiveSuccessfulWeeks,
    String? lastProcessedWeekKey,
    String? decayChainStartKey,
    String? autoRecoveryStartKey,
    int? appliedDecayUnits,
    Map<String, Set<int>>? scheduleByWeekKey,
    Set<String>? programRestDateKeys,
    Set<String>? programTrainingDateKeys,
    bool clearPending = false,
    bool clearDecayChain = false,
  }) {
    return RestState(
      trainingWeekdays: trainingWeekdays ?? this.trainingWeekdays,
      pendingTrainingWeekdays: clearPending
          ? null
          : pendingTrainingWeekdays ?? this.pendingTrainingWeekdays,
      pendingStartWeekKey: clearPending
          ? null
          : pendingStartWeekKey ?? this.pendingStartWeekKey,
      recoveryClaims: recoveryClaims ?? this.recoveryClaims,
      protectedMissDateKeys:
          protectedMissDateKeys ?? this.protectedMissDateKeys,
      shieldCharges: shieldCharges ?? this.shieldCharges,
      consecutiveSuccessfulWeeks:
          consecutiveSuccessfulWeeks ?? this.consecutiveSuccessfulWeeks,
      lastProcessedWeekKey: lastProcessedWeekKey ?? this.lastProcessedWeekKey,
      decayChainStartKey: clearDecayChain
          ? null
          : decayChainStartKey ?? this.decayChainStartKey,
      autoRecoveryStartKey: autoRecoveryStartKey ?? this.autoRecoveryStartKey,
      appliedDecayUnits: appliedDecayUnits ?? this.appliedDecayUnits,
      scheduleByWeekKey: scheduleByWeekKey ?? this.scheduleByWeekKey,
      programRestDateKeys: programRestDateKeys ?? this.programRestDateKeys,
      programTrainingDateKeys:
          programTrainingDateKeys ?? this.programTrainingDateKeys,
    );
  }

  Map<String, dynamic> toJson() => {
    'trainingWeekdays': _sortedWeekdays(trainingWeekdays),
    'pendingTrainingWeekdays': pendingTrainingWeekdays == null
        ? null
        : _sortedWeekdays(pendingTrainingWeekdays!),
    'pendingStartWeekKey': pendingStartWeekKey,
    'recoveryClaims': recoveryClaims.map(
      (key, claim) => MapEntry(key, claim.toJson()),
    ),
    'protectedMissDateKeys': protectedMissDateKeys.toList()..sort(),
    'shieldCharges': shieldCharges,
    'consecutiveSuccessfulWeeks': consecutiveSuccessfulWeeks,
    'lastProcessedWeekKey': lastProcessedWeekKey,
    'decayChainStartKey': decayChainStartKey,
    'autoRecoveryStartKey': autoRecoveryStartKey,
    'appliedDecayUnits': appliedDecayUnits,
    'scheduleByWeekKey': scheduleByWeekKey.map(
      (key, weekdays) => MapEntry(key, _sortedWeekdays(weekdays)),
    ),
    'programRestDateKeys': programRestDateKeys.toList()..sort(),
    'programTrainingDateKeys': programTrainingDateKeys.toList()..sort(),
  };

  factory RestState.fromJson(Map<String, dynamic> json) {
    return RestState(
      trainingWeekdays: _decodeWeekdays(json['trainingWeekdays']),
      pendingTrainingWeekdays: json['pendingTrainingWeekdays'] == null
          ? null
          : _decodeWeekdays(json['pendingTrainingWeekdays']),
      pendingStartWeekKey: json['pendingStartWeekKey'] as String?,
      recoveryClaims: {
        for (final entry
            in (json['recoveryClaims'] as Map<String, dynamic>? ?? {}).entries)
          entry.key: RestRecoveryClaim.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
      protectedMissDateKeys:
          (json['protectedMissDateKeys'] as List<dynamic>?)
              ?.cast<String>()
              .toSet() ??
          <String>{},
      shieldCharges: (json['shieldCharges'] as num?)?.toInt() ?? 0,
      consecutiveSuccessfulWeeks:
          (json['consecutiveSuccessfulWeeks'] as num?)?.toInt() ?? 0,
      lastProcessedWeekKey: json['lastProcessedWeekKey'] as String?,
      decayChainStartKey: json['decayChainStartKey'] as String?,
      autoRecoveryStartKey: json['autoRecoveryStartKey'] as String?,
      appliedDecayUnits: (json['appliedDecayUnits'] as num?)?.toInt() ?? 0,
      scheduleByWeekKey: {
        for (final entry
            in (json['scheduleByWeekKey'] as Map<String, dynamic>? ?? {})
                .entries)
          entry.key: _decodeWeekdays(entry.value),
      },
      programRestDateKeys:
          (json['programRestDateKeys'] as List<dynamic>?)
              ?.cast<String>()
              .toSet() ??
          <String>{},
      programTrainingDateKeys:
          (json['programTrainingDateKeys'] as List<dynamic>?)
              ?.cast<String>()
              .toSet() ??
          <String>{},
    );
  }

  factory RestState.defaults({String? currentWeekKey}) {
    final schedule = <String, Set<int>>{};
    if (currentWeekKey != null) {
      schedule[currentWeekKey] = defaultTrainingWeekdays;
    }
    return RestState(
      trainingWeekdays: defaultTrainingWeekdays,
      recoveryClaims: const {},
      protectedMissDateKeys: const {},
      shieldCharges: 0,
      consecutiveSuccessfulWeeks: 0,
      scheduleByWeekKey: schedule,
    );
  }

  static List<int> _sortedWeekdays(Set<int> weekdays) =>
      weekdays.toList()..sort();

  static Set<int> _decodeWeekdays(Object? raw) {
    final values =
        (raw as List<dynamic>?)?.map((value) => (value as num).toInt()) ??
        defaultTrainingWeekdays;
    final sanitized = values.where((day) => day >= 1 && day <= 7).toSet();
    if (sanitized.isEmpty || sanitized.length == 7) {
      return defaultTrainingWeekdays;
    }
    return sanitized;
  }
}
