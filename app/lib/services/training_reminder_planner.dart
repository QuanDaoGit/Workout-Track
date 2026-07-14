/// Pure planning for Tier B training-day reminders — no plugin, no I/O, so it is
/// fully unit-testable. [NotificationService] turns each [TrainingReminderSlot]
/// into a weekly-repeating local notification.
library;

/// Base notification id for training-day reminders. Each weekday gets a stable
/// id of `base + weekday` (2001=Mon .. 2007=Sun), disjoint from the Tier A rest
/// alert (id 1001) so the two never collide.
const int trainingReminderBaseId = 2000;

/// The full id range a reconcile must clear, so a removed weekday can never
/// leave a stale weekly alarm firing (Codex review finding #3).
List<int> get allTrainingReminderIds =>
    [for (var d = 1; d <= 7; d++) trainingReminderBaseId + d];

/// One weekday's reminder: a stable id + the weekday (1=Mon..7=Sun) and the
/// local wall-clock time it should fire at.
class TrainingReminderSlot {
  const TrainingReminderSlot({
    required this.id,
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  final int id;
  final int weekday;
  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is TrainingReminderSlot &&
      other.id == id &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(id, weekday, hour, minute);

  @override
  String toString() =>
      'TrainingReminderSlot(id: $id, weekday: $weekday, $hour:$minute)';
}

/// Map the user's chosen training [weekdays] + a fire time ([minutes] since
/// local midnight) to the reminder slots to schedule. Sanitizes weekdays to the
/// valid 1..7 range and clamps the time, and returns them weekday-sorted so the
/// output is deterministic (stable id order).
List<TrainingReminderSlot> trainingReminderSlots({
  required Set<int> weekdays,
  required int minutes,
}) {
  final clamped = minutes.clamp(0, 24 * 60 - 1);
  final hour = clamped ~/ 60;
  final minute = clamped % 60;
  final days = weekdays.where((d) => d >= 1 && d <= 7).toList()..sort();
  return [
    for (final d in days)
      TrainingReminderSlot(
        id: trainingReminderBaseId + d,
        weekday: d,
        hour: hour,
        minute: minute,
      ),
  ];
}
