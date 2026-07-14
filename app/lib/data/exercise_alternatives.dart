import '../models/workout_models.dart';

/// Result of [alternativesFor]: strong, slot-equivalent swaps kept separate
/// from weak same-muscle top-ups so the Replace sheet never frames a loosely
/// related lift as an equivalent swap (Codex plan-review F5).
class ExerciseAlternatives {
  const ExerciseAlternatives({required this.strong, required this.more});

  /// Share the replaced lift's equipment and/or mechanic — true "replace with".
  final List<Exercise> strong;

  /// Same muscle group but no shared equipment/mechanic — "more for this muscle".
  final List<Exercise> more;

  bool get isEmpty => strong.isEmpty && more.isEmpty;
}

/// Rank [groupPool] (the curated pool for the replaced lift's muscle group, in
/// curated order) as alternatives to [replaced], excluding [excludeIds] and the
/// replaced lift itself. Scored by shared `equipment` (+2) and shared `mechanic`
/// (+1); ties keep curated order. Null `equipment`/`mechanic` simply score 0 and
/// fall to [ExerciseAlternatives.more] — never a crash. The combined result is
/// capped at [limit] (strong first); callers always offer a "See All" escape, so
/// an all-excluded pool legitimately returns empty.
ExerciseAlternatives alternativesFor(
  Exercise replaced,
  List<Exercise> groupPool,
  Set<String> excludeIds, {
  int limit = 4,
}) {
  final exclude = {...excludeIds, replaced.id};
  final seen = <String>{};
  final candidates = <Exercise>[];
  for (final exercise in groupPool) {
    if (exclude.contains(exercise.id)) continue;
    if (!seen.add(exercise.id)) continue; // dedupe by id
    candidates.add(exercise);
  }

  int score(Exercise e) {
    var s = 0;
    if (replaced.equipment != null && e.equipment == replaced.equipment) s += 2;
    if (replaced.mechanic != null && e.mechanic == replaced.mechanic) s += 1;
    return s;
  }

  final indexed = [
    for (var i = 0; i < candidates.length; i++)
      (exercise: candidates[i], score: score(candidates[i]), order: i),
  ]..sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.order.compareTo(b.order); // List.sort is not stable — pin order
  });

  final strong = <Exercise>[];
  final more = <Exercise>[];
  for (final entry in indexed) {
    (entry.score > 0 ? strong : more).add(entry.exercise);
  }

  final cappedStrong = strong.take(limit).toList();
  final remaining = limit - cappedStrong.length;
  return ExerciseAlternatives(
    strong: cappedStrong,
    more: remaining > 0 ? more.take(remaining).toList() : const [],
  );
}
