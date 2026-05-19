import '../models/overload_models.dart';
import '../models/workout_models.dart';
import 'exercise_kind_cache.dart';
import 'workout_storage_service.dart';

class ProgressiveOverloadService {
  ProgressiveOverloadService();

  ProgressiveOverloadService.fromSessions(List<WorkoutSession> sessions)
    : _sessions = List.of(sessions)..sort((a, b) => b.date.compareTo(a.date));

  static const double _weightIncrement = 2.5;
  static const int _detrainedThresholdDays = 21;
  static const int _deloadMissThreshold = 3;

  static const Map<ExerciseKind, int> _repTargetByKind = {
    ExerciseKind.compound: 8,
    ExerciseKind.isolation: 12,
    ExerciseKind.bodyweight: 15,
  };

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

  /// Most recent session date that contains [exerciseId], or null.
  DateTime? _lastSessionDate(String exerciseId) {
    for (final session in _sessions) {
      for (final log in session.exercises) {
        if (log.exerciseId == exerciseId && log.sets.isNotEmpty) {
          return session.date;
        }
      }
    }
    return null;
  }

  /// Linear-progression suggestion for the upcoming Set 1 of [exercise].
  /// Returns null when there is no history.
  ///
  /// Algorithm:
  ///   - Bodyweight: +1 rep if target reps hit, else repeat reps.
  ///   - Weighted, gap > 21d: repeat weight (detrained).
  ///   - Weighted, missed by 4+: weight − 2.5 kg (deload).
  ///   - Weighted, met target: weight + 2.5 kg.
  ///   - Weighted, missed by 1–3: repeat weight at target reps.
  Future<OverloadSuggestion?> suggestNext(
    Exercise exercise, {
    DateTime? now,
  }) async {
    final lastSets = getLastSessionSets(exercise.id);
    if (lastSets == null) return null;

    final topSet = _topSet(lastSets);
    if (topSet == null) return null;

    final kind = await ExerciseKindCache.instance.classify(
      exercise.id,
      mechanic: exercise.mechanic,
      equipment: exercise.equipment,
      observedSets: lastSets,
    );
    final targetReps = _repTargetByKind[kind] ?? 8;

    if (kind == ExerciseKind.bodyweight) {
      if (topSet.reps >= targetReps) {
        return OverloadSuggestion(
          weight: topSet.weight,
          reps: topSet.reps + 1,
          reason: OverloadReason.weightIncrease,
        );
      }
      return OverloadSuggestion(
        weight: topSet.weight,
        reps: targetReps,
        reason: OverloadReason.repTarget,
      );
    }

    final lastDate = _lastSessionDate(exercise.id);
    final reference = now ?? DateTime.now();
    if (lastDate != null &&
        reference.difference(lastDate).inDays > _detrainedThresholdDays) {
      return OverloadSuggestion(
        weight: topSet.weight,
        reps: targetReps,
        reason: OverloadReason.detrained,
      );
    }

    if (topSet.reps < targetReps - _deloadMissThreshold) {
      final next = (topSet.weight - _weightIncrement)
          .clamp(0, double.infinity)
          .toDouble();
      return OverloadSuggestion(
        weight: next,
        reps: targetReps,
        reason: OverloadReason.deload,
      );
    }

    if (topSet.reps >= targetReps) {
      return OverloadSuggestion(
        weight: topSet.weight + _weightIncrement,
        reps: targetReps,
        reason: OverloadReason.weightIncrease,
      );
    }

    return OverloadSuggestion(
      weight: topSet.weight,
      reps: targetReps,
      reason: OverloadReason.repTarget,
    );
  }

  /// Heaviest top set: max by `(weight, reps)`. Bodyweight sets pick max reps.
  SetEntry? _topSet(List<SetEntry> sets) {
    if (sets.isEmpty) return null;
    SetEntry best = sets.first;
    for (final s in sets) {
      if (s.weight > best.weight ||
          (s.weight == best.weight && s.reps > best.reps)) {
        best = s;
      }
    }
    return best;
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

  /// True if this set's estimated 1RM strictly exceeds an existing all-time best.
  bool checkPR(String exerciseId, double weight, int reps, bool isBodyweight) {
    if (reps <= 0) return false;
    final rm = epley1RM(weight, reps, isBodyweight);
    if (rm <= 0) return false;
    final best = getPersonalBest(exerciseId);
    if (best <= 0) return false;
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
