import 'body_goal_models.dart';

class WeightEntry {
  const WeightEntry({
    required this.weightKg,
    required this.loggedAt,
    this.goalAtTime,
  });

  final double weightKg;
  final DateTime loggedAt;
  final BodyGoal? goalAtTime;

  Map<String, dynamic> toJson() => {
    'weightKg': weightKg,
    'loggedAt': loggedAt.toIso8601String(),
    if (goalAtTime != null) 'goalAtTime': goalAtTime!.name,
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    weightKg: (json['weightKg'] as num).toDouble(),
    loggedAt: DateTime.parse(json['loggedAt'] as String),
    goalAtTime: json['goalAtTime'] != null
        ? BodyGoal.values.firstWhere(
            (g) => g.name == json['goalAtTime'],
            orElse: () => BodyGoal.recomp,
          )
        : null,
  );
}
