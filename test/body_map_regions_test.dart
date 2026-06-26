import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/body_map_regions.dart';

void main() {
  group('bodyMuscleValues — coverage roll-up', () {
    test('sums a muscle that gathers several tokens', () {
      final v = bodyMuscleValues({
        'traps': 3.0,
        'middle back': 1.0,
        'neck': 0.5,
        'adductors': 2.0,
        'abductors': 1.0,
      });
      expect(v['traps'], 4.5); // traps + middle back + neck
      expect(v['adductors'], 3.0); // adductors + abductors
    });

    test('F1: coarse shoulders folds to FRONT delt only, never rear', () {
      final v = bodyMuscleValues({'shoulders': 4.0});
      expect(v['front_delt'], 4.0);
      expect(v['rear_delt'], 0.0); // rear is earned only from curated posterior work
    });

    test('F1: coarse abdominals folds to RECTUS only, never obliques', () {
      final v = bodyMuscleValues({'abdominals': 3.0});
      expect(v['rectus'], 3.0);
      expect(v['obliques'], 0.0);
    });

    test('curated split keys still credit their specific region, additive', () {
      final v = bodyMuscleValues({
        'front_delt': 2.0,
        'shoulders': 1.0, // un-curated remainder
        'rear_delt': 1.5,
      });
      expect(v['front_delt'], 3.0); // 2 specific + 1 coarse
      expect(v['rear_delt'], 1.5);
    });
  });

  group('mask → muscle integrity', () {
    test('every mask maps to a real muscle', () {
      final ids = {for (final m in bodyMuscles) m.id};
      for (final muscleId in [...frontMaskMuscle.values, ...backMaskMuscle.values]) {
        expect(ids.contains(muscleId), isTrue, reason: '$muscleId has no BodyMuscle');
      }
    });

    test('every analyzer-producible key is consumed by some muscle (none dropped)', () {
      final consumed = <String>{};
      for (final m in bodyMuscles) {
        consumed.addAll(m.sourceKeys);
        if (m.coarseKey != null) consumed.add(m.coarseKey!);
      }
      // The full set of keys weeklySetsByMuscle can emit.
      const producible = {
        'chest', 'biceps', 'triceps', 'forearms', 'quadriceps', 'hamstrings',
        'glutes', 'calves', 'adductors', 'abductors', 'lats', 'traps',
        'middle back', 'lower back', 'neck', 'front_delt', 'rear_delt',
        'rectus_abdominis', 'obliques', 'shoulders', 'abdominals',
      };
      final dropped = producible.difference(consumed);
      expect(dropped, isEmpty, reason: 'keys with no muscle: $dropped');
    });

    test('muscle ids are unique', () {
      final ids = bodyMuscles.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('zoneFor', () {
    test('boundaries', () {
      expect(zoneFor(0, 8, 18), BodyZone.rest);
      expect(zoneFor(4, 8, 18), BodyZone.building);
      expect(zoneFor(8, 8, 18), BodyZone.optimal); // == MEV is optimal
      expect(zoneFor(18, 8, 18), BodyZone.optimal); // == MAV is optimal
      expect(zoneFor(19, 8, 18), BodyZone.high);
    });
  });

  group('maskOpacityFor — the ramp (Codex F2: monotonic + capped)', () {
    test('0 at rest, capped at 1.0 past MAV', () {
      expect(maskOpacityFor(0, 8, 18), 0.0);
      expect(maskOpacityFor(18, 8, 18), 1.0);
      expect(maskOpacityFor(30, 8, 18), 1.0); // capped, no brighter
    });

    test('non-decreasing across the whole range', () {
      double prev = -1;
      for (double s = 0; s <= 30; s += 0.5) {
        final o = maskOpacityFor(s, 8, 18);
        expect(o, greaterThanOrEqualTo(prev), reason: 'dipped at sets=$s');
        expect(o, inInclusiveRange(0.0, 1.0));
        prev = o;
      }
    });

    test('building band stays clearly below optimal (a visible jump at MEV)', () {
      final belowMev = maskOpacityFor(7.9, 8, 18);
      final atMev = maskOpacityFor(8, 8, 18);
      expect(belowMev, lessThan(0.45));
      expect(atMev, greaterThanOrEqualTo(0.78));
    });
  });
}
