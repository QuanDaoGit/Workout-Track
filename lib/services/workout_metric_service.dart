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

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
