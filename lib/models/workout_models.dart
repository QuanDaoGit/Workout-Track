import '../data/muscle_groups.dart';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.level,
    required this.images,
    this.instructions = const [],
    this.isCustom = false,
    this.createdAt,
    this.userNote,
    this.muscleGroup,
    this.exerciseType,
    this.primaryMuscle,
    this.mechanic,
    this.equipment,
  });

  final String id;
  final String name;
  final String level;
  final List<String> images;
  final List<String> instructions;
  final bool isCustom;
  final DateTime? createdAt;
  final String? userNote;
  final String? muscleGroup;
  final String? exerciseType;
  final String? primaryMuscle;
  final String? mechanic;
  final String? equipment;

  String get imageAssetPath {
    if (images.isEmpty) return '';
    return 'assets/exercises/exercises/${images.first}';
  }

  String get levelLabel {
    if (level.isEmpty) return 'Unknown';
    return '${level[0].toUpperCase()}${level.substring(1)}';
  }

  int get levelRank => switch (level) {
    'beginner' => 0,
    'intermediate' => 1,
    'expert' => 2,
    _ => 3,
  };

  Exercise copyWith({
    String? id,
    String? name,
    String? level,
    List<String>? images,
    List<String>? instructions,
    bool? isCustom,
    DateTime? createdAt,
    String? userNote,
    String? muscleGroup,
    String? exerciseType,
    String? primaryMuscle,
    String? mechanic,
    String? equipment,
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    level: level ?? this.level,
    images: images ?? this.images,
    instructions: instructions ?? this.instructions,
    isCustom: isCustom ?? this.isCustom,
    createdAt: createdAt ?? this.createdAt,
    userNote: userNote ?? this.userNote,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    exerciseType: exerciseType ?? this.exerciseType,
    primaryMuscle: primaryMuscle ?? this.primaryMuscle,
    mechanic: mechanic ?? this.mechanic,
    equipment: equipment ?? this.equipment,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'level': level,
    'images': images,
    'instructions': instructions,
    if (isCustom) 'isCustom': true,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (userNote != null) 'userNote': userNote,
    if (muscleGroup != null) 'muscleGroup': muscleGroup,
    if (exerciseType != null) 'exerciseType': exerciseType,
    if (primaryMuscle != null) 'primaryMuscle': primaryMuscle,
    if (mechanic != null) 'mechanic': mechanic,
    if (equipment != null) 'equipment': equipment,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Unnamed exercise',
    level: json['level'] as String? ?? '',
    images: [
      for (final img in json['images'] as List<dynamic>? ?? const [])
        img as String,
    ],
    instructions: [
      for (final s in json['instructions'] as List<dynamic>? ?? const [])
        s as String,
    ],
    isCustom: json['isCustom'] as bool? ?? false,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
    userNote: json['userNote'] as String?,
    muscleGroup: _normalizeOrNull(json['muscleGroup'] as String?),
    exerciseType: json['exerciseType'] as String?,
    primaryMuscle:
        json['primaryMuscle'] as String? ??
        _firstString(json['primaryMuscles']),
    mechanic: json['mechanic'] as String?,
    equipment: json['equipment'] as String?,
  );

  static String? _normalizeOrNull(String? raw) {
    if (raw == null) return null;
    return normalizeMuscleGroup(raw) ?? raw;
  }

  static String? _firstString(Object? raw) {
    if (raw is List && raw.isNotEmpty && raw.first is String) {
      return raw.first as String;
    }
    return null;
  }
}

class SetEntry {
  const SetEntry({required this.weight, required this.reps});

  final double weight;
  final int reps;

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps};

  factory SetEntry.fromJson(Map<String, dynamic> j) =>
      SetEntry(weight: (j['weight'] as num).toDouble(), reps: j['reps'] as int);
}

class ExerciseLog {
  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  final String exerciseId;
  final String exerciseName;
  final List<SetEntry> sets;

  double get totalVolume => sets.fold(0, (sum, s) => sum + s.weight * s.reps);

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'sets': sets.map((s) => s.toJson()).toList(),
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
    exerciseId: j['exerciseId'] as String,
    exerciseName: j['exerciseName'] as String,
    sets: [
      for (final s in j['sets'] as List<dynamic>)
        SetEntry.fromJson(s as Map<String, dynamic>),
    ],
  );
}

class WorkoutSession {
  WorkoutSession({
    required this.id,
    required this.date,
    required this.muscleGroup,
    required this.targetDurationMinutes,
    required this.actualDurationSeconds,
    required this.exercises,
    required this.estimatedCalories,
    DateTime? startedAt,
    this.pausedAt,
    this.autoDiscardAt,
    this.isPartial = false,
    this.isAbandoned = false,
    this.isPausedForResume = false,
    this.selectedExerciseIds = const [],
    List<String>? targetMuscleGroups,
    this.baseXP,
    this.lckMultiplier,
    this.potionMultiplier,
    this.lootBonusXP,
    this.awardedXP,
    this.classAtSave,
    this.bodyweightKgAtSave,
    this.statDelta = const {},
  }) : startedAt = startedAt ?? date,
       targetMuscleGroups = _normalizedTargets(muscleGroup, targetMuscleGroups);

  final String id;
  final DateTime date;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final DateTime? autoDiscardAt;
  final String muscleGroup;
  final int targetDurationMinutes;
  final int actualDurationSeconds;
  final List<ExerciseLog> exercises;
  final int estimatedCalories;
  final bool isPartial;
  final bool isAbandoned;
  final bool isPausedForResume;
  final List<String> selectedExerciseIds;
  final List<String> targetMuscleGroups;
  final int? baseXP;
  final double? lckMultiplier;
  final double? potionMultiplier;
  final int? lootBonusXP;
  final int? awardedXP;
  final String? classAtSave;

  /// Bodyweight (kg) snapshotted when the session was saved, like
  /// [classAtSave]. Frozen on the session so later profile edits never rewrite
  /// the strength credit of past workouts. Null on history that predates the
  /// snapshot (StatEngine carries the last-known value forward).
  final double? bodyweightKgAtSave;
  final Map<String, int> statDelta;

  bool get isOngoing => isPartial && !isAbandoned;

  /// Copy with replaced exercise logs and/or stat delta. Deliberately narrow:
  /// identity, timing, and XP fields are immutable once a session is saved.
  WorkoutSession copyWith({
    List<ExerciseLog>? exercises,
    Map<String, int>? statDelta,
  }) => WorkoutSession(
    id: id,
    date: date,
    startedAt: startedAt,
    pausedAt: pausedAt,
    autoDiscardAt: autoDiscardAt,
    muscleGroup: muscleGroup,
    targetMuscleGroups: targetMuscleGroups,
    targetDurationMinutes: targetDurationMinutes,
    actualDurationSeconds: actualDurationSeconds,
    exercises: exercises ?? this.exercises,
    estimatedCalories: estimatedCalories,
    isPartial: isPartial,
    isAbandoned: isAbandoned,
    isPausedForResume: isPausedForResume,
    selectedExerciseIds: selectedExerciseIds,
    baseXP: baseXP,
    lckMultiplier: lckMultiplier,
    potionMultiplier: potionMultiplier,
    lootBonusXP: lootBonusXP,
    awardedXP: awardedXP,
    classAtSave: classAtSave,
    bodyweightKgAtSave: bodyweightKgAtSave,
    statDelta: statDelta ?? this.statDelta,
  );

  String get targetMuscleLabel =>
      targetMuscleGroupsLabel(targetMuscleGroups, fallback: muscleGroup);

  bool targetsMuscle(String muscleGroup) =>
      hasTargetMuscle(targetMuscleGroups, muscleGroup);

  int elapsedSecondsForDisplay(DateTime now) {
    if (!isOngoing || isPausedForResume) return actualDurationSeconds;
    final live = now.difference(startedAt).inSeconds;
    return live > actualDurationSeconds ? live : actualDurationSeconds;
  }

  DateTime resumeStartTime(DateTime now) {
    if (!isPausedForResume) return startedAt;
    return now.subtract(Duration(seconds: actualDurationSeconds));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'startedAt': startedAt.toIso8601String(),
    'pausedAt': pausedAt?.toIso8601String(),
    'autoDiscardAt': autoDiscardAt?.toIso8601String(),
    'muscleGroup': muscleGroup,
    'targetDurationMinutes': targetDurationMinutes,
    'actualDurationSeconds': actualDurationSeconds,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'estimatedCalories': estimatedCalories,
    'isPartial': isPartial,
    'isAbandoned': isAbandoned,
    'isPausedForResume': isPausedForResume,
    'selectedExerciseIds': selectedExerciseIds,
    'targetMuscleGroups': targetMuscleGroups,
    if (baseXP != null) 'baseXP': baseXP,
    if (lckMultiplier != null) 'lckMultiplier': lckMultiplier,
    if (potionMultiplier != null) 'potionMultiplier': potionMultiplier,
    if (lootBonusXP != null) 'lootBonusXP': lootBonusXP,
    if (awardedXP != null) 'awardedXP': awardedXP,
    if (classAtSave != null) 'classAtSave': classAtSave,
    if (bodyweightKgAtSave != null) 'bodyweightKgAtSave': bodyweightKgAtSave,
    if (statDelta.isNotEmpty) 'statDelta': statDelta,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) {
    final date = DateTime.parse(j['date'] as String);
    final startedAtRaw = j['startedAt'] as String?;
    final startedAt = startedAtRaw == null
        ? date
        : DateTime.tryParse(startedAtRaw) ?? date;
    final pausedAtRaw = j['pausedAt'] as String?;
    final autoDiscardAtRaw = j['autoDiscardAt'] as String?;
    final rawMuscleGroup = j['muscleGroup'] as String;

    return WorkoutSession(
      id: j['id'] as String,
      date: date,
      startedAt: startedAt,
      pausedAt: pausedAtRaw == null ? null : DateTime.tryParse(pausedAtRaw),
      autoDiscardAt: autoDiscardAtRaw == null
          ? null
          : DateTime.tryParse(autoDiscardAtRaw),
      muscleGroup: normalizeMuscleGroup(rawMuscleGroup) ?? rawMuscleGroup,
      targetDurationMinutes: j['targetDurationMinutes'] as int,
      actualDurationSeconds: j['actualDurationSeconds'] as int,
      exercises: [
        for (final e in j['exercises'] as List<dynamic>)
          ExerciseLog.fromJson(e as Map<String, dynamic>),
      ],
      estimatedCalories: (j['estimatedCalories'] as num?)?.toInt() ?? 0,
      isPartial: j['isPartial'] as bool? ?? false,
      isAbandoned: j['isAbandoned'] as bool? ?? false,
      isPausedForResume: j['isPausedForResume'] as bool? ?? false,
      selectedExerciseIds:
          (j['selectedExerciseIds'] as List<dynamic>?)?.cast<String>() ?? [],
      targetMuscleGroups:
          (j['targetMuscleGroups'] as List<dynamic>?)?.cast<String>() ??
          [rawMuscleGroup],
      baseXP: (j['baseXP'] as num?)?.toInt(),
      lckMultiplier: (j['lckMultiplier'] as num?)?.toDouble(),
      potionMultiplier: (j['potionMultiplier'] as num?)?.toDouble(),
      lootBonusXP: (j['lootBonusXP'] as num?)?.toInt(),
      awardedXP: (j['awardedXP'] as num?)?.toInt(),
      classAtSave: j['classAtSave'] as String?,
      bodyweightKgAtSave: (j['bodyweightKgAtSave'] as num?)?.toDouble(),
      statDelta: _decodeStatDelta(j['statDelta']),
    );
  }

  static Map<String, int> _decodeStatDelta(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toInt(),
    };
  }

  static List<String> _normalizedTargets(
    String muscleGroup,
    List<String>? targetGroups,
  ) {
    final normalized = normalizeTargetMuscleGroups(
      targetGroups == null || targetGroups.isEmpty
          ? [muscleGroup]
          : targetGroups,
    );
    if (normalized.isNotEmpty) return normalized;
    return [normalizeMuscleGroup(muscleGroup) ?? muscleGroup];
  }
}
