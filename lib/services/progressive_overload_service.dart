import '../models/overload_models.dart';
import '../models/workout_models.dart';
import 'workout_storage_service.dart';

class ProgressiveOverloadService {
  ProgressiveOverloadService();

  ProgressiveOverloadService.fromSessions(List<WorkoutSession> sessions)
      : _sessions = List.of(sessions)
          ..sort((a, b) => b.date.compareTo(a.date));

  List<WorkoutSession> _sessions = [];

  Future<void> load() async {
    _sessions = await WorkoutStorageService().getSessions();
    _sessions.sort((a, b) => b.date.compareTo(a.date));
  }

  /// Most recent session's sets for [exerciseId], or null.
  List<SetEntry>? getLastSessionSets(String exerciseId) {
    for (final session in _sessions) {
      for (final log in session.exercises) {
        if (log.exerciseId == exerciseId && log.sets.isNotEmpty) {
          return log.sets;
        }
      }
    }
    return null;
  }

  /// Suggest +5% weight (rounded to nearest 2.5 kg) or +1 rep for bodyweight.
  /// Returns null if no history at [setIndex].
  OverloadSuggestion? getSuggestion(
    String exerciseId,
    int setIndex,
    bool isBodyweight,
  ) {
    final lastSets = getLastSessionSets(exerciseId);
    if (lastSets == null || setIndex >= lastSets.length) return null;

    final lastSet = lastSets[setIndex];

    if (isBodyweight) {
      return OverloadSuggestion(weight: lastSet.weight, reps: lastSet.reps + 1);
    }

    // If reps dropped from the set before (user failed mid-session),
    // suggest same weight instead of +5%.
    if (setIndex > 0) {
      final prevSetInSession = lastSets[setIndex - 1];
      if (lastSet.reps < prevSetInSession.reps) {
        return OverloadSuggestion(
          weight: lastSet.weight,
          reps: lastSet.reps,
        );
      }
    }

    final suggestedWeight = (lastSet.weight * 1.05 / 2.5).round() * 2.5;
    return OverloadSuggestion(weight: suggestedWeight, reps: lastSet.reps);
  }

  /// Highest estimated 1RM (Epley) ever logged for [exerciseId].
  double getPersonalBest(String exerciseId) {
    double best = 0.0;
    for (final session in _sessions) {
      for (final log in session.exercises) {
        if (log.exerciseId == exerciseId) {
          for (final s in log.sets) {
            final rm = epley1RM(s.weight, s.reps, s.weight == 0);
            if (rm > best) best = rm;
          }
        }
      }
    }
    return best;
  }

  /// True if this set's estimated 1RM strictly exceeds the all-time best.
  bool checkPR(
    String exerciseId,
    double weight,
    int reps,
    bool isBodyweight,
  ) {
    if (reps <= 0) return false;
    final rm = epley1RM(weight, reps, isBodyweight);
    if (rm <= 0) return false;
    final best = getPersonalBest(exerciseId);
    return rm > best;
  }

  /// Weight and reps difference vs last session's same set index.
  OverloadDelta? getDelta(
    String exerciseId,
    int setIndex,
    double weight,
    int reps,
  ) {
    final lastSets = getLastSessionSets(exerciseId);
    if (lastSets == null || setIndex >= lastSets.length) return null;
    final lastSet = lastSets[setIndex];
    return OverloadDelta(
      weightDiff: weight - lastSet.weight,
      repsDiff: reps - lastSet.reps,
    );
  }

  /// Epley formula: weight * (1 + reps / 30.0).
  /// For bodyweight sets, uses 40.0 as the base weight.
  static double epley1RM(double weight, int reps, bool isBodyweight) {
    final w = isBodyweight ? 40.0 : weight;
    if (reps <= 0 || w <= 0) return 0.0;
    return w * (1 + reps / 30.0);
  }
}
