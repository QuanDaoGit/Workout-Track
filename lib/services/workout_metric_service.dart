import '../models/workout_models.dart';

class WorkoutMetricService {
  const WorkoutMetricService._();

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
