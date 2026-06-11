import '../models/overload_models.dart';
import '../models/workout_models.dart';
import 'exercise_kind_cache.dart';
import 'workout_storage_service.dart';

class ProgressiveOverloadService {
  ProgressiveOverloadService();

  ProgressiveOverloadService.fromSessions(List<WorkoutSession> sessions)
    : _sessions = List.of(sessions)..sort((a, b) => b.date.compareTo(a.date));

  static const double _weightIncrement = 2.5;
  static const int _minimumSetsForSuggestion = 5;
  static const int _returnFromBreakDays = 14;

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

  Future<ExerciseProgressionSnapshot?> snapshotFor(Exercise exercise) async {
    final matches = <({WorkoutSession session, ExerciseLog log})>[];
    var totalSets = 0;
    for (final session in _sessions) {
      if (session.isPartial || session.isAbandoned) continue;
      for (final log in session.exercises) {
        if (log.exerciseId != exercise.id || log.sets.isEmpty) continue;
        matches.add((session: session, log: log));
        totalSets += log.sets.length;
      }
    }
    if (matches.isEmpty) return null;

    final latest = matches.first;
    final lastSets = latest.log.sets;
    final topSet = _topSet(lastSets);
    if (topSet == null) return null;

    final kind = await ExerciseKindCache.instance.classify(
      exercise.id,
      mechanic: exercise.mechanic,
      equipment: exercise.equipment,
      observedSets: lastSets,
    );
    final targetReps = _repTargetByKind[kind] ?? 8;
    return ExerciseProgressionSnapshot(
      exerciseId: exercise.id,
      totalSetsLogged: totalSets,
      lastSessionAt: latest.session.date,
      lastSets: List<SetEntry>.from(lastSets),
      topSet: topSet,
      targetReps: targetReps,
      isBodyweight: kind == ExerciseKind.bodyweight,
      estimatedOneRepMax: getPersonalBest(exercise.id),
    );
  }

  /// Trust-gated progression suggestion for the upcoming Set 1 of [exercise].
  /// Returns null before 5 logged sets so the UI does not guess too early.
  ///
  /// When a program prescription is supplied ([targetRepMin] / [targetRepMax])
  /// it overrides the kind-based rep default. A range (max > min) behaves as
  /// double progression — aim for the top, reset to the bottom on a load bump;
  /// a fixed target (or no override) aims for the single number.
  Future<OverloadSuggestion?> suggestNext(
    Exercise exercise, {
    int? targetRepMin,
    int? targetRepMax,
    DateTime? now,
  }) async {
    final snapshot = await snapshotFor(exercise);
    if (snapshot == null ||
        snapshot.totalSetsLogged < _minimumSetsForSuggestion) {
      return null;
    }

    // Reps to aim for this session, and the reps to reset to after a load bump.
    // A range (max > min) progresses like double progression; a fixed target
    // (or no prescription) aims for a single number.
    final bool prescribed = targetRepMin != null;
    final int aimReps = prescribed
        ? (targetRepMax != null && targetRepMax > targetRepMin
              ? targetRepMax
              : targetRepMin)
        : snapshot.targetReps;
    final int resetReps = prescribed ? targetRepMin : aimReps;

    if (snapshot.isBodyweight) {
      if (_metTargetReps(snapshot, aimReps)) {
        return OverloadSuggestion(
          weight: snapshot.topSet.weight,
          reps: snapshot.topSet.reps + 1,
          reason: OverloadReason.weightIncrease,
          confidenceHigh: true,
          setsLogged: snapshot.totalSetsLogged,
        );
      }
      return OverloadSuggestion(
        weight: snapshot.topSet.weight,
        reps: aimReps,
        reason: OverloadReason.repTarget,
        confidenceHigh: true,
        setsLogged: snapshot.totalSetsLogged,
      );
    }

    final reference = now ?? DateTime.now();
    if (reference.difference(snapshot.lastSessionAt).inDays >=
        _returnFromBreakDays) {
      return OverloadSuggestion(
        weight: _roundToNearestHalf(snapshot.topSet.weight * 0.95),
        reps: resetReps,
        reason: OverloadReason.detrained,
        confidenceHigh: true,
        setsLogged: snapshot.totalSetsLogged,
      );
    }

    final setCount = snapshot.lastSets.length;
    final actualTotal = snapshot.lastSets.fold<int>(
      0,
      (sum, set) => sum + set.reps,
    );
    // Deload is judged against the bottom of the range, load increase against
    // the top. For a fixed target (or the kind default) floor == top, so this
    // collapses to the original single-target behaviour.
    final topShortfall = aimReps * setCount - actualTotal;
    final floorShortfall = resetReps * setCount - actualTotal;

    if (floorShortfall > (aimReps * 0.25).ceil()) {
      final next = _capAtOneRepMax(
        _roundToNearestHalf(snapshot.topSet.weight * 0.95),
        snapshot.estimatedOneRepMax,
      );
      return OverloadSuggestion(
        weight: next,
        reps: aimReps,
        reason: OverloadReason.deload,
        confidenceHigh: true,
        setsLogged: snapshot.totalSetsLogged,
      );
    }

    if (topShortfall <= 0) {
      // Hit the top across the work -> add load, reset to the bottom.
      final next = _capAtOneRepMax(
        snapshot.topSet.weight + _weightIncrement,
        snapshot.estimatedOneRepMax,
      );
      return OverloadSuggestion(
        weight: _roundToNearestHalf(next),
        reps: resetReps,
        reason: OverloadReason.weightIncrease,
        confidenceHigh: true,
        setsLogged: snapshot.totalSetsLogged,
      );
    }

    // Inside the range -> hold the load and keep pushing toward the top.
    return OverloadSuggestion(
      weight: snapshot.topSet.weight,
      reps: aimReps,
      reason: OverloadReason.repTarget,
      confidenceHigh: true,
      setsLogged: snapshot.totalSetsLogged,
    );
  }

  bool _metTargetReps(ExerciseProgressionSnapshot snapshot, int target) {
    if (snapshot.lastSets.isEmpty) return false;
    return snapshot.lastSets.every((set) => set.reps >= target);
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

  double _capAtOneRepMax(double weight, double estimatedOneRepMax) {
    if (estimatedOneRepMax <= 0) return weight;
    return weight.clamp(0, estimatedOneRepMax * 0.9).toDouble();
  }

  double _roundToNearestHalf(double weight) => (weight * 2).round() / 2;

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
