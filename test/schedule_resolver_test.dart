import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/services/schedule_resolver.dart';

/// Pins the pure projection of a program's workout-only sequence onto chosen
/// training weekdays. Forgiveness (a missed anchored day rolls the same index to
/// the next training weekday) and "rest is calendar-derived" live here.
void main() {
  const resolver = ScheduleResolver();
  final ppl = programById('ppl')!; // workouts: P,U,L,P,U,L (6); 1 rest slot dropped
  final fullBody = programById('full_body_3x')!; // workouts: A,B,C (3)

  // A fixed week: Mon 2026-06-15 .. Sun 2026-06-21.
  DateTime d(int weekday) => DateTime(2026, 6, 14 + weekday); // 15=Mon..21=Sun

  group('rest is calendar-derived', () {
    test('a non-training weekday resolves to rest with no workout', () {
      final r = resolver.resolve(
        date: d(2), // Tue
        program: fullBody,
        workoutIndex: 0,
        effectiveWeekdays: {1, 3, 5}, // Mon/Wed/Fri
      );
      expect(r.isRest, isTrue);
      expect(r.isTrainingDay, isFalse);
      expect(r.displayedWorkout, isNull);
      expect(r.workoutIndexToComplete, isNull);
    });
  });

  group('training weekday surfaces the next-up workout', () {
    test('index 0 on the first training weekday shows the first workout', () {
      final r = resolver.resolve(
        date: d(1), // Mon
        program: fullBody,
        workoutIndex: 0,
        effectiveWeekdays: {1, 3, 5},
      );
      expect(r.isTrainingDay, isTrue);
      expect(r.displayedWorkout!.label, 'FULL BODY A');
      expect(r.workoutIndexToComplete, 0);
    });

    test('the SAME index shows the SAME workout on a later training weekday '
        '(forgiveness: a missed Mon rolls A to Wed, order intact)', () {
      final mon = resolver.resolve(
        date: d(1),
        program: fullBody,
        workoutIndex: 0,
        effectiveWeekdays: {1, 3, 5},
      );
      final wed = resolver.resolve(
        date: d(3),
        program: fullBody,
        workoutIndex: 0, // index did NOT advance (Mon was missed, not completed)
        effectiveWeekdays: {1, 3, 5},
      );
      expect(mon.displayedWorkout!.label, wed.displayedWorkout!.label);
      expect(wed.displayedWorkout!.label, 'FULL BODY A');
    });

    test('workoutIndex wraps modulo the workout count', () {
      final r = resolver.resolve(
        date: d(1),
        program: ppl,
        workoutIndex: 7, // 7 % 6 == 1 -> second workout (UPPER/PULL)
        effectiveWeekdays: {1, 2, 3, 4, 5, 6},
      );
      expect(r.workoutIndexToComplete, 1);
      expect(r.displayedWorkout!.label, ppl.workouts[1].label);
    });

    test('completing today advances by exactly one slot (no fast-forward)', () {
      // Even when several rest days sit between training weekdays, the index to
      // complete is exactly the displayed one — advance is +1, never skipping.
      final r = resolver.resolve(
        date: d(6), // Sat, with only Sat training this week
        program: ppl,
        workoutIndex: 2,
        effectiveWeekdays: {6},
      );
      expect(r.workoutIndexToComplete, 2);
      expect(r.displayedWorkout!.label, ppl.workouts[2].label);
    });
  });

  group('no active program', () {
    test('a chosen weekday is a generic training day with no workout', () {
      final r = resolver.resolve(
        date: d(1),
        program: null,
        workoutIndex: 0,
        effectiveWeekdays: {1, 3, 5},
      );
      expect(r.isTrainingDay, isTrue);
      expect(r.displayedWorkout, isNull);
      expect(r.workoutIndexToComplete, isNull);
    });
  });

  group('Program.workouts drops rest slots', () {
    test('full body 3x exposes exactly its 3 workouts in order', () {
      expect(fullBody.workouts.map((w) => w.label).toList(),
          ['FULL BODY A', 'FULL BODY B', 'FULL BODY C']);
    });

    test('ppl exposes 6 workouts (the single rest slot is dropped)', () {
      expect(ppl.workouts.length, 6);
      expect(ppl.workouts.every((w) => w.isWorkout), isTrue);
    });
  });
}
