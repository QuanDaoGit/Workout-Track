import '../data/muscle_groups.dart';
import '../models/workout_models.dart';

class CalorieService {
  static const _metByMuscleGroup = {
    'Chest': 5.0,
    'Back': 5.0,
    'Shoulders': 4.5,
    'Arms': 4.0,
    'Legs': 6.0,
    'Core': 4.0,
    'Full Body': 6.0,
  };

  static int estimateCalories(String muscleGroup, int durationSeconds) {
    return estimateCaloriesForGroups([muscleGroup], durationSeconds);
  }

  static int estimateCaloriesForGroups(
    Iterable<String> muscleGroups,
    int durationSeconds,
  ) {
    final groups = normalizeTargetMuscleGroups(muscleGroups);
    final mets = groups.isEmpty
        ? const [5.0]
        : [for (final group in groups) _metByMuscleGroup[group] ?? 5.0];
    final met = mets.fold<double>(0, (sum, value) => sum + value) / mets.length;
    final hours = durationSeconds / 3600;
    return (met * 70 * hours).round();
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
