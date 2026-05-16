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
  }) =>
      Exercise(
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
    muscleGroup: json['muscleGroup'] as String?,
    exerciseType: json['exerciseType'] as String?,
    primaryMuscle: json['primaryMuscle'] as String?,
  );
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
    this.isPartial = false,
    this.isAbandoned = false,
    this.selectedExerciseIds = const [],
  }) : startedAt = startedAt ?? date;

  final String id;
  final DateTime date;
  final DateTime startedAt;
  final String muscleGroup;
  final int targetDurationMinutes;
  final int actualDurationSeconds;
  final List<ExerciseLog> exercises;
  final int estimatedCalories;
  final bool isPartial;
  final bool isAbandoned;
  final List<String> selectedExerciseIds;

  bool get isOngoing => isPartial && !isAbandoned;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'startedAt': startedAt.toIso8601String(),
    'muscleGroup': muscleGroup,
    'targetDurationMinutes': targetDurationMinutes,
    'actualDurationSeconds': actualDurationSeconds,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'estimatedCalories': estimatedCalories,
    'isPartial': isPartial,
    'isAbandoned': isAbandoned,
    'selectedExerciseIds': selectedExerciseIds,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) {
    final date = DateTime.parse(j['date'] as String);
    final startedAtRaw = j['startedAt'] as String?;
    final startedAt = startedAtRaw == null
        ? date
        : DateTime.tryParse(startedAtRaw) ?? date;

    return WorkoutSession(
      id: j['id'] as String,
      date: date,
      startedAt: startedAt,
      muscleGroup: j['muscleGroup'] as String,
      targetDurationMinutes: j['targetDurationMinutes'] as int,
      actualDurationSeconds: j['actualDurationSeconds'] as int,
      exercises: [
        for (final e in j['exercises'] as List<dynamic>)
          ExerciseLog.fromJson(e as Map<String, dynamic>),
      ],
      estimatedCalories: (j['estimatedCalories'] as num?)?.toInt() ?? 0,
      isPartial: j['isPartial'] as bool? ?? false,
      isAbandoned: j['isAbandoned'] as bool? ?? false,
      selectedExerciseIds:
          (j['selectedExerciseIds'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
