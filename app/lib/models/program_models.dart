enum ProgramDayType { workout, rest }

enum MuscleFocus {
  push,
  pull,
  legs,
  upper,
  lower,
  fullBody,
  chestTriceps,
  backBiceps,
  shouldersCore,
}

/// How a program escalates load over time. [linear] adds weight whenever the
/// fixed rep target is met (the novice effect); [doubleProgression] climbs a
/// rep range first, then adds weight and drops back to the bottom of the range.
enum ProgressionScheme { linear, doubleProgression }

/// A per-exercise prescription: how many sets, and the rep target/range.
/// Fixed reps when [repMin] == [repMax].
class SetRepScheme {
  const SetRepScheme({required this.sets, required this.repMin, int? repMax})
    : repMax = repMax ?? repMin;

  final int sets;
  final int repMin;
  final int repMax;

  bool get isFixed => repMin == repMax;

  String label() => isFixed ? '$sets × $repMin' : '$sets × $repMin–$repMax';

  /// Spelled-out form for the in-session target banner, e.g. `'3 sets × 8 reps'`.
  String verboseLabel() => isFixed
      ? '$sets sets × $repMin reps'
      : '$sets sets × $repMin–$repMax reps';
}

class ProgramDay {
  const ProgramDay({
    required this.dayNumber,
    required this.type,
    required this.label,
    this.focus,
    this.suggestedExerciseIds = const [],
    this.prescription = const {},
  });

  final int dayNumber;
  final ProgramDayType type;
  final MuscleFocus? focus;
  final String label;
  final List<String> suggestedExerciseIds;

  /// Per-exercise sets × reps prescription, keyed by exercise id. Empty for
  /// rest days and any exercise without an authored target.
  final Map<String, SetRepScheme> prescription;

  bool get isWorkout => type == ProgramDayType.workout;
}

class Program {
  const Program({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.daysPerWeek,
    required this.recommendedWeeks,
    required this.weekSchedule,
    this.progression = ProgressionScheme.linear,
  });

  final String id;
  final String name;
  final String description;
  final String tier;
  final int daysPerWeek;
  final int recommendedWeeks;
  final List<ProgramDay> weekSchedule;

  /// How this program escalates load week to week.
  final ProgressionScheme progression;

  /// The finite completion target for one arc through this program: every
  /// scheduled workout day across the recommended span. Powers the goal-gradient
  /// finish line (e.g. 3x8 = 24, 4x8 = 32, 6x8 = 48).
  int get targetSessions => daysPerWeek * recommendedWeeks;

  /// The workout-only sublist of [weekSchedule], in cycle order. This is the
  /// progression spine under the weekday-anchored schedule: rest slots leave the
  /// progression entirely (rest is calendar-derived from training weekdays), so
  /// `ProgramProgress.workoutIndex` indexes into THIS list, never [weekSchedule].
  List<ProgramDay> get workouts =>
      weekSchedule.where((d) => d.isWorkout).toList(growable: false);
}

class ProgramProgress {
  const ProgramProgress({
    required this.programId,
    required this.currentWeek,
    required this.currentDayIndex,
    required this.startedAt,
    required this.completedSessions,
    this.workoutIndex = 0,
    this.arcStartSessions = 0,
    this.completedArc = false,
  });

  final String programId;
  final int currentWeek;

  /// Legacy 7-slot cycle index (workout+rest). Deprecated under the
  /// weekday-anchored schedule — frozen at its migration value and no longer
  /// advanced. Kept serialized one release for migration input / rollback.
  /// Read [workoutIndex] instead.
  final int currentDayIndex;
  final DateTime startedAt;
  final int completedSessions;

  /// Index into the program's workout-only sublist ([Program.workouts]). The
  /// authoritative progression cursor under the weekday-anchored schedule:
  /// advances by exactly 1 (mod workout count) on each completed workout. Rest
  /// is calendar-derived (a non-training weekday), never a slot here. Seeded by
  /// the `weekdayAnchoredScheduleV1` migration from [currentDayIndex].
  final int workoutIndex;

  /// Baseline of [completedSessions] at the start of the current arc. Each new
  /// cycle (a fresh finish line) rolls this forward instead of wiping history.
  final int arcStartSessions;

  /// True once this arc has reached its target and is awaiting the user's
  /// next-path choice (BEGIN NEXT PATH / STAY WITH THIS PROGRAM).
  final bool completedArc;

  /// Sessions completed within the current arc (never negative).
  int get arcSessions {
    final v = completedSessions - arcStartSessions;
    return v < 0 ? 0 : v;
  }

  ProgramProgress copyWith({
    String? programId,
    int? currentWeek,
    int? currentDayIndex,
    DateTime? startedAt,
    int? completedSessions,
    int? workoutIndex,
    int? arcStartSessions,
    bool? completedArc,
  }) {
    return ProgramProgress(
      programId: programId ?? this.programId,
      currentWeek: currentWeek ?? this.currentWeek,
      currentDayIndex: currentDayIndex ?? this.currentDayIndex,
      startedAt: startedAt ?? this.startedAt,
      completedSessions: completedSessions ?? this.completedSessions,
      workoutIndex: workoutIndex ?? this.workoutIndex,
      arcStartSessions: arcStartSessions ?? this.arcStartSessions,
      completedArc: completedArc ?? this.completedArc,
    );
  }

  Map<String, dynamic> toJson() => {
    'programId': programId,
    'currentWeek': currentWeek,
    'currentDayIndex': currentDayIndex,
    'startedAt': startedAt.toIso8601String(),
    'completedSessions': completedSessions,
    'workoutIndex': workoutIndex,
    'arcStartSessions': arcStartSessions,
    'completedArc': completedArc,
  };

  factory ProgramProgress.fromJson(Map<String, dynamic> json) {
    return ProgramProgress(
      programId: json['programId'] as String? ?? '',
      currentWeek: (json['currentWeek'] as num?)?.toInt() ?? 1,
      currentDayIndex: (json['currentDayIndex'] as num?)?.toInt() ?? 0,
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      workoutIndex: (json['workoutIndex'] as num?)?.toInt() ?? 0,
      arcStartSessions: (json['arcStartSessions'] as num?)?.toInt() ?? 0,
      completedArc: json['completedArc'] as bool? ?? false,
    );
  }
}

class ProgramDaySnapshot {
  const ProgramDaySnapshot({
    required this.programId,
    required this.week,
    required this.dayIndex,
    required this.dateKey,
  });

  final String programId;
  final int week;
  final int dayIndex;
  final String dateKey;

  Map<String, dynamic> toJson() => {
    'programId': programId,
    'week': week,
    'dayIndex': dayIndex,
    'dateKey': dateKey,
  };

  factory ProgramDaySnapshot.fromJson(Map<String, dynamic> json) {
    return ProgramDaySnapshot(
      programId: json['programId'] as String? ?? '',
      week: (json['week'] as num?)?.toInt() ?? 1,
      dayIndex: (json['dayIndex'] as num?)?.toInt() ?? 0,
      dateKey: json['dateKey'] as String? ?? '',
    );
  }
}

/// A finished program arc: recorded once when [ProgramProgress.arcSessions]
/// reaches the program's `targetSessions`. Drives the completion reveal and the
/// Guild Card's "paths forged" list.
class ProgramCompletion {
  const ProgramCompletion({
    required this.programId,
    required this.titleId,
    required this.sessions,
    required this.completedAt,
  });

  final String programId;
  final String titleId;
  final int sessions;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
    'programId': programId,
    'titleId': titleId,
    'sessions': sessions,
    'completedAt': completedAt.toIso8601String(),
  };

  factory ProgramCompletion.fromJson(Map<String, dynamic> json) {
    return ProgramCompletion(
      programId: json['programId'] as String? ?? '',
      titleId: json['titleId'] as String? ?? '',
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      completedAt:
          DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
