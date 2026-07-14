import '../data/muscle_groups.dart';
import '../models/workout_models.dart';

class CalorieService {
  /// The MET model's reference-subject bodyweight (a ~70 kg adult). Used as the
  /// fallback when a session carries no frozen bodyweight snapshot, so callers
  /// that don't pass one keep the historical behaviour exactly.
  static const double referenceBodyweightKg = 70.0;

  static const _metByMuscleGroup = {
    'Chest': 5.0,
    'Back': 5.0,
    'Shoulders': 4.5,
    'Arms': 4.0,
    'Legs': 6.0,
    'Core': 4.0,
    'Full Body': 6.0,
  };

  static int estimateCalories(
    String muscleGroup,
    int durationSeconds, {
    double bodyweightKg = referenceBodyweightKg,
  }) {
    return estimateCaloriesForGroups(
      [muscleGroup],
      durationSeconds,
      bodyweightKg: bodyweightKg,
    );
  }

  /// Kcal ≈ MET × bodyweight(kg) × hours. [bodyweightKg] should be the session's
  /// frozen `bodyweightKgAtSave` so the estimate uses the user's real mass and
  /// stays consistent with the stat engine; a non-positive value (or an omitted
  /// one) falls back to [referenceBodyweightKg].
  static int estimateCaloriesForGroups(
    Iterable<String> muscleGroups,
    int durationSeconds, {
    double bodyweightKg = referenceBodyweightKg,
  }) {
    final groups = normalizeTargetMuscleGroups(muscleGroups);
    final mets = groups.isEmpty
        ? const [5.0]
        : [for (final group in groups) _metByMuscleGroup[group] ?? 5.0];
    final met = mets.fold<double>(0, (sum, value) => sum + value) / mets.length;
    final hours = durationSeconds / 3600;
    final weight = bodyweightKg > 0 ? bodyweightKg : referenceBodyweightKg;
    return (met * weight * hours).round();
  }

  static int exerciseCalories(
    ExerciseLog log,
    int totalCalories,
    List<ExerciseLog> allLogs,
  ) {
    final totalVolume = allLogs.fold(0.0, (sum, l) => sum + l.totalVolume);
    if (totalVolume == 0) return 0;
    return (totalCalories * log.totalVolume / totalVolume).round();
  }
}
