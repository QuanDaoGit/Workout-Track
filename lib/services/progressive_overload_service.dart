import '../models/overload_models.dart';
import '../models/training_focus.dart';
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

  /// ACSM novice default rep target — used as the **sparse-history fallback**
  /// aim, no longer imposed as a universal target (see [_deriveRepRange]).
  static const Map<ExerciseKind, int> _repTargetByKind = {
    ExerciseKind.compound: 8,
    ExerciseKind.isolation: 12,
    ExerciseKind.bodyweight: 15,
  };

  // History-anchored rep target (#5). The kind sets the clamp BAND; the user's
  // demonstrated reps set the point within it.
  static const int _repWindowSessions = 5;
  static const int _repAnchorMinSessions = 2;
  static const int _repConsistencyMaxSpread = 5;
  static const Map<ExerciseKind, (int, int)> _repBandByKind = {
    ExerciseKind.compound: (3, 12),
    ExerciseKind.isolation: (6, 20),
    ExerciseKind.bodyweight: (5, 30),
  };

  /// History-anchored target rep range from recent per-session **top-set** reps
  /// (heaviest set → robust to backoff days; warm-ups already excluded). Returns
  /// null when fewer than [_repAnchorMinSessions] clean sessions exist (caller
  /// falls back to the kind default AND suppresses deload — no baseline to judge
  /// against). `confident` is false for high-variance histories (undulating /
  /// AMRAP / goal-shift / mixed prescription) → suppress the deload judgment.
  /// `aim = M+1` (≤1 rep headroom, never pushes the user up); `floor = M-2` (sits
  /// below demonstrated reps so a post-`+load` reset never trips the floor).
  static ({int min, int max, bool confident})? _deriveRepRange(
    List<int> topReps,
    ExerciseKind kind,
  ) {
    if (topReps.length < _repAnchorMinSessions) return null;
    final band = _repBandByKind[kind] ?? const (3, 20);
    final lo = band.$1;
    final hi = band.$2;
    final sorted = [...topReps]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();
    final m = median.clamp(lo, hi).toInt();
    final spread = sorted.last - sorted.first;
    final confident = spread <= _repConsistencyMaxSpread;
    final aim = (m + 1).clamp(lo, hi).toInt();
    var floor = (m - 2).clamp(lo, aim).toInt();
    if (floor >= aim) floor = aim > lo ? aim - 1 : aim; // never degenerate
    return (min: floor, max: aim, confident: confident);
  }

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

  Future<ExerciseProgressionSnapshot?> snapshotFor(
    Exercise exercise, {
    TrainingFocus? focus,
  }) async {
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
    // The sparse-history fallback aim: the onboarding training-goal seed when set
    // (Strength 5 / Muscle 8 / Endurance 15), else the ACSM kind default. Only
    // used while history is too thin to anchor (<2 sessions) — once history
    // exists, the kind-banded derivation below takes over (the focus never
    // clamps real history).
    final targetReps = focus?.defaultReps ?? (_repTargetByKind[kind] ?? 8);

    // History-anchored rep target: the most-recent sessions' top-set reps
    // (matches are session-desc, so this is newest-first). Capped to the window.
    final windowTopReps = <int>[];
    for (final match in matches) {
      if (windowTopReps.length >= _repWindowSessions) break;
      final t = _topSet(match.log.sets);
      if (t != null && t.reps > 0) windowTopReps.add(t.reps);
    }
    final derived = _deriveRepRange(windowTopReps, kind);

    return ExerciseProgressionSnapshot(
      exerciseId: exercise.id,
      totalSetsLogged: totalSets,
      lastSessionAt: latest.session.date,
      lastSets: List<SetEntry>.from(lastSets),
      topSet: topSet,
      targetReps: targetReps,
      isBodyweight: kind == ExerciseKind.bodyweight,
      estimatedOneRepMax: getPersonalBest(exercise.id),
      derivedRepMin: derived?.min,
      derivedRepMax: derived?.max,
      repAnchorConfident: derived?.confident,
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
    TrainingFocus? focus,
    DateTime? now,
  }) async {
    final snapshot = await snapshotFor(exercise, focus: focus);
    if (snapshot == null ||
        snapshot.totalSetsLogged < _minimumSetsForSuggestion) {
      return null;
    }

    // Reps to aim for this session, the reps to reset to after a load bump, and
    // whether a deload (floor) judgment is allowed. Precedence: a program
    // prescription wins; else the history-anchored range; else the kind default
    // with deload suppressed (sparse history has no baseline to call "short").
    final int aimReps;
    final int resetReps;
    final bool deloadAllowed;
    if (targetRepMin != null) {
      aimReps = (targetRepMax != null && targetRepMax > targetRepMin)
          ? targetRepMax
          : targetRepMin;
      resetReps = targetRepMin;
      deloadAllowed = true;
    } else if (snapshot.derivedRepMax != null) {
      // Double progression within the user's demonstrated range.
      aimReps = snapshot.derivedRepMax!;
      resetReps = snapshot.derivedRepMin!;
      // Only judge a deload when the recent pattern is consistent enough.
      deloadAllowed = snapshot.repAnchorConfident == true;
    } else {
      aimReps = snapshot.targetReps;
      resetReps = snapshot.targetReps;
      deloadAllowed = false;
    }

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

    // The shortfall is a cross-set total, so the deload threshold must scale with
    // set count too (≈25% under the floor *on average*) — otherwise more sets
    // makes a deload spuriously more likely for the same per-set quality.
    final deloadThreshold = (resetReps * setCount * 0.25).ceil();
    if (deloadAllowed && floorShortfall > deloadThreshold) {
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
