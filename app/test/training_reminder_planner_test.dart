import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/training_reminder_planner.dart';

void main() {
  group('trainingReminderSlots', () {
    test('no training days → no slots', () {
      expect(trainingReminderSlots(weekdays: const {}, minutes: 480), isEmpty);
    });

    test('maps each weekday to a stable id (2000 + weekday), weekday-sorted', () {
      final slots = trainingReminderSlots(weekdays: const {5, 1, 3}, minutes: 480);
      expect(slots.map((s) => s.weekday).toList(), [1, 3, 5]);
      expect(slots.map((s) => s.id).toList(), [2001, 2003, 2005]);
    });

    test('ids never collide with the Tier A rest alert (1001)', () {
      final slots = trainingReminderSlots(weekdays: const {1, 2, 3, 4, 5, 6, 7}, minutes: 0);
      expect(slots.map((s) => s.id), isNot(contains(1001)));
      expect(slots.map((s) => s.id).toList(), [2001, 2002, 2003, 2004, 2005, 2006, 2007]);
    });

    test('decomposes minutes-since-midnight into hour/minute', () {
      final slots = trainingReminderSlots(weekdays: const {1}, minutes: 8 * 60 + 10);
      expect(slots.single.hour, 8);
      expect(slots.single.minute, 10);
    });

    test('sanitizes out-of-range weekdays and de-duplicates', () {
      final slots = trainingReminderSlots(weekdays: const {0, 1, 8, 3, -2}, minutes: 480);
      expect(slots.map((s) => s.weekday).toList(), [1, 3]);
    });

    test('clamps an out-of-range time into a valid time-of-day', () {
      final tooLate = trainingReminderSlots(weekdays: const {1}, minutes: 99999).single;
      expect(tooLate.hour, 23);
      expect(tooLate.minute, 59);
      final negative = trainingReminderSlots(weekdays: const {1}, minutes: -30).single;
      expect(negative.hour, 0);
      expect(negative.minute, 0);
    });
  });

  test('allTrainingReminderIds covers exactly the weekly range 2001..2007', () {
    expect(allTrainingReminderIds, [2001, 2002, 2003, 2004, 2005, 2006, 2007]);
  });
}
