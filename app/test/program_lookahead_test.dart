import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';

/// Pins the weekday-anchored "NEXT ▸" teaser: which workout it names (from the
/// workout-only index, +1 when today's workout is still pending) and how many
/// days away it lands (the next training weekday strictly after today).
void main() {
  final fullBody = programById('full_body_3x')!; // workouts A,B,C
  final ppl = programById('ppl')!; // workouts P,U,L,P,U,L

  // 2026-06-15 is a Monday; d(1)=Mon .. d(7)=Sun.
  DateTime d(int weekday) => DateTime(2026, 6, 14 + weekday);

  group('which workout the teaser names', () {
    test('rest/consumed panel (not pending) names workouts[workoutIndex]', () {
      final la = nextWorkoutLookahead(
        fullBody,
        0,
        trainingWeekdays: {1, 3, 5},
        today: d(1),
        todayWorkoutPending: false,
      )!;
      expect(la.workout.label, 'FULL BODY A');
    });

    test('active-workout panel (pending) names the FOLLOWING workout', () {
      final la = nextWorkoutLookahead(
        fullBody,
        0,
        trainingWeekdays: {1, 3, 5},
        today: d(1),
        todayWorkoutPending: true,
      )!;
      expect(la.workout.label, 'FULL BODY B');
    });

    test('the label index wraps modulo the workout count', () {
      final consumed = nextWorkoutLookahead(
        fullBody,
        2,
        trainingWeekdays: {1, 3, 5},
        today: d(1),
        todayWorkoutPending: false,
      )!;
      expect(consumed.workout.label, 'FULL BODY C');
      final pending = nextWorkoutLookahead(
        fullBody,
        2,
        trainingWeekdays: {1, 3, 5},
        today: d(1),
        todayWorkoutPending: true,
      )!;
      expect(pending.workout.label, 'FULL BODY A'); // (2+1)%3 == 0
    });
  });

  group('days away = next training weekday strictly after today', () {
    test('Monday with Mon/Wed/Fri -> Wednesday is 2 days out', () {
      final la = nextWorkoutLookahead(
        fullBody,
        0,
        trainingWeekdays: {1, 3, 5},
        today: d(1),
        todayWorkoutPending: false,
      )!;
      expect(la.daysAway, 2);
    });

    test('Friday with Mon/Wed/Fri wraps to Monday, 3 days out', () {
      final la = nextWorkoutLookahead(
        fullBody,
        0,
        trainingWeekdays: {1, 3, 5},
        today: d(5),
        todayWorkoutPending: false,
      )!;
      expect(la.daysAway, 3);
    });

    test('Saturday with a 6-day week (Mon..Sat) -> Monday, 2 days out', () {
      final la = nextWorkoutLookahead(
        ppl,
        0,
        trainingWeekdays: {1, 2, 3, 4, 5, 6},
        today: d(6),
        todayWorkoutPending: false,
      )!;
      expect(la.daysAway, 2); // Sun rest, Mon training
    });
  });

  group('null guards', () {
    test('no training weekdays -> null', () {
      expect(
        nextWorkoutLookahead(
          fullBody,
          0,
          trainingWeekdays: const {},
          today: d(1),
          todayWorkoutPending: false,
        ),
        isNull,
      );
    });
  });

  group('relativeWhen', () {
    test('1 day → tomorrow', () => expect(relativeWhen(1), 'tomorrow'));
    test('2 days → in 2 days', () => expect(relativeWhen(2), 'in 2 days'));
    test('3 days → in 3 days', () => expect(relativeWhen(3), 'in 3 days'));
    test('defensive 0 → tomorrow', () => expect(relativeWhen(0), 'tomorrow'));
  });
}
