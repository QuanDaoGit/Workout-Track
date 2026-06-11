import '../models/workout_models.dart';
import 'progressive_overload_service.dart';

class WorkoutMetricService {
  const WorkoutMetricService._();

  /// Per-session count of exercises whose best estimated 1RM beat that
  /// exercise's best across all *earlier* sessions. The first-ever log of an
  /// exercise sets the baseline and is intentionally not counted as a PR —
  /// otherwise every new exercise would spam badges.
  static Map<String, int> prCountsBySession(List<WorkoutSession> sessions) {
    final ordered =
        sessions.where((s) => !s.isPartial && !s.isAbandoned).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final bestByExercise = <String, double>{};
    final counts = <String, int>{};
    for (final session in ordered) {
      var prs = 0;
      for (final log in session.exercises) {
        var sessionBest = 0.0;
        for (final set in log.sets) {
          final rm = ProgressiveOverloadService.epley1RM(
            set.weight,
            set.reps,
            set.weight == 0,
          );
          if (rm > sessionBest) sessionBest = rm;
        }
        if (sessionBest <= 0) continue;
        final prior = bestByExercise[log.exerciseId] ?? 0;
        if (sessionBest > prior) {
          if (prior > 0) prs++;
          bestByExercise[log.exerciseId] = sessionBest;
        }
      }
      counts[session.id] = prs;
    }
    return counts;
  }

  static int trainingDaysThisWeek(
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) {
    final currentDay = _dateOnly(now ?? DateTime.now());
    final monday = currentDay.subtract(Duration(days: currentDay.weekday - 1));
    final tomorrow = currentDay.add(const Duration(days: 1));

    final days = sessions
        .where((session) => !session.isPartial)
        .where(
          (session) =>
              !session.date.isBefore(monday) && session.date.isBefore(tomorrow),
        )
        .map((session) => _dateOnly(session.date))
        .toSet();

    return days.length;
  }

  /// Consecutive days ending today (or yesterday if no session today) that
  /// have at least one completed, non-partial session.
  static int currentStreak(List<WorkoutSession> sessions, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final completedDays = sessions
        .where((session) => !session.isPartial)
        .map((session) => _dateOnly(session.date))
        .toSet();

    if (completedDays.isEmpty) return 0;

    DateTime cursor = completedDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    if (!completedDays.contains(cursor)) return 0;

    int streak = 0;
    while (completedDays.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
