import '../models/workout_models.dart';

class CalorieService {
  static const _metByMuscleGroup = {
    'Chest': 5.0,
    'Back': 5.0,
    'Arms': 4.0,
    'Legs': 6.0,
  };

  static int estimateCalories(String muscleGroup, int durationSeconds) {
    final met = _metByMuscleGroup[muscleGroup] ?? 5.0;
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
