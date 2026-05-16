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

class ProgramDay {
  const ProgramDay({
    required this.dayNumber,
    required this.type,
    required this.label,
    this.focus,
    this.suggestedExerciseIds = const [],
  });

  final int dayNumber;
  final ProgramDayType type;
  final MuscleFocus? focus;
  final String label;
  final List<String> suggestedExerciseIds;

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
  });

  final String id;
  final String name;
  final String description;
  final String tier;
  final int daysPerWeek;
  final int recommendedWeeks;
  final List<ProgramDay> weekSchedule;
}

class ProgramProgress {
  const ProgramProgress({
    required this.programId,
    required this.currentWeek,
    required this.currentDayIndex,
    required this.startedAt,
    required this.completedSessions,
  });

  final String programId;
  final int currentWeek;
  final int currentDayIndex;
  final DateTime startedAt;
  final int completedSessions;

  ProgramProgress copyWith({
    String? programId,
    int? currentWeek,
    int? currentDayIndex,
    DateTime? startedAt,
    int? completedSessions,
  }) {
    return ProgramProgress(
      programId: programId ?? this.programId,
      currentWeek: currentWeek ?? this.currentWeek,
      currentDayIndex: currentDayIndex ?? this.currentDayIndex,
      startedAt: startedAt ?? this.startedAt,
      completedSessions: completedSessions ?? this.completedSessions,
    );
  }

  Map<String, dynamic> toJson() => {
    'programId': programId,
    'currentWeek': currentWeek,
    'currentDayIndex': currentDayIndex,
    'startedAt': startedAt.toIso8601String(),
    'completedSessions': completedSessions,
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
