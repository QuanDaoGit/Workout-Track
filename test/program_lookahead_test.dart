import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';

void main() {
  final fullBody = programById('full_body_3x')!; // [W A, R, W B, R, W C, R, R]
  final upperLower = programById('upper_lower')!; // [W U, W L, R, W U, W L, R, R]
  final ppl = programById('ppl')!; // [W P, W U, W L, W P, W U, W L, R]

  group('nextWorkoutLookahead — pending workout today (todayConsumed: false)', () {
    test('full body day A → next workout is B, two days out (rest between)', () {
      final la = nextWorkoutLookahead(fullBody, 0, todayConsumed: false)!;
      expect(la.workout.label, 'FULL BODY B');
      expect(la.daysAway, 2);
    });

    test('ppl push → next workout is pull, tomorrow (back-to-back)', () {
      final la = nextWorkoutLookahead(ppl, 0, todayConsumed: false)!;
      expect(la.workout.label, 'PULL');
      expect(la.daysAway, 1);
    });

    test('upper/lower last lower wraps past two rests to next UPPER', () {
      // index 4 = LOWER; 5,6 = REST; wraps to index 0 = UPPER → 3 days.
      final la = nextWorkoutLookahead(upperLower, 4, todayConsumed: false)!;
      expect(la.workout.label, 'UPPER');
      expect(la.daysAway, 3);
    });
  });

  group('nextWorkoutLookahead — rest day today (todayConsumed: false)', () {
    test('full body rest (index 1) → next workout B, tomorrow', () {
      final la = nextWorkoutLookahead(fullBody, 1, todayConsumed: false)!;
      expect(la.workout.label, 'FULL BODY B');
      expect(la.daysAway, 1);
    });

    test('wrap-around: full body final rest (index 6) → A, tomorrow', () {
      final la = nextWorkoutLookahead(fullBody, 6, todayConsumed: false)!;
      expect(la.workout.label, 'FULL BODY A');
      expect(la.daysAway, 1);
    });
  });

  group('nextWorkoutLookahead — completed today (todayConsumed: true)', () {
    test('after finishing A, advanceDay sat on rest (index 1) → B in 2 days', () {
      final la = nextWorkoutLookahead(fullBody, 1, todayConsumed: true)!;
      expect(la.workout.label, 'FULL BODY B');
      expect(la.daysAway, 2);
    });

    test('after finishing ppl push, index sits on PULL → tomorrow', () {
      final la = nextWorkoutLookahead(ppl, 1, todayConsumed: true)!;
      expect(la.workout.label, 'PULL');
      expect(la.daysAway, 1);
    });
  });

  group('relativeWhen', () {
    test('1 day → tomorrow', () => expect(relativeWhen(1), 'tomorrow'));
    test('2 days → in 2 days', () => expect(relativeWhen(2), 'in 2 days'));
    test('3 days → in 3 days', () => expect(relativeWhen(3), 'in 3 days'));
    test('defensive 0 → tomorrow', () => expect(relativeWhen(0), 'tomorrow'));
  });
}
