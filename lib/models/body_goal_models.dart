enum BodyGoal { cut, recomp, bulk }

class BodyGoalState {
  const BodyGoalState({
    required this.goal,
    required this.setAt,
    this.targetWeight,
  });

  final BodyGoal goal;
  final DateTime setAt;
  final double? targetWeight;

  String get futureClassName => switch (goal) {
    BodyGoal.cut => 'ASSASSIN',
    BodyGoal.recomp => 'BRUISER',
    BodyGoal.bulk => 'TANK',
  };

  String get goalLabel => switch (goal) {
    BodyGoal.cut => 'CUT',
    BodyGoal.recomp => 'RECOMP',
    BodyGoal.bulk => 'BULK',
  };

  BodyGoalState copyWith({
    BodyGoal? goal,
    DateTime? setAt,
    double? targetWeight,
  }) =>
      BodyGoalState(
        goal: goal ?? this.goal,
        setAt: setAt ?? this.setAt,
        targetWeight: targetWeight ?? this.targetWeight,
      );

  Map<String, dynamic> toJson() => {
    'goal': goal.name,
    'setAt': setAt.toIso8601String(),
    if (targetWeight != null) 'targetWeight': targetWeight,
  };

  factory BodyGoalState.fromJson(Map<String, dynamic> json) => BodyGoalState(
    goal: BodyGoal.values.firstWhere(
      (g) => g.name == json['goal'],
      orElse: () => BodyGoal.recomp,
    ),
    setAt: DateTime.parse(json['setAt'] as String),
    targetWeight: (json['targetWeight'] as num?)?.toDouble(),
  );
}
