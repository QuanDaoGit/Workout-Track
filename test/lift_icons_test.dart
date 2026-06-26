import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/lift_icons.dart';

/// The name→movement-pattern icon classifier. Focus on the ORDER-sensitive
/// overlaps (a wrong rule order silently mis-icons a whole family) + the
/// generic fallback.
void main() {
  String key(String name) => liftIconKeyFor(name);

  test('horizontal vs vertical press disambiguate', () {
    expect(key('Barbell Bench Press'), 'press');
    expect(key('Incline Dumbbell Press'), 'press');
    expect(key('Push-Up'), 'press');
    expect(key('Overhead Press'), 'overhead_press');
    expect(key('Seated Dumbbell Shoulder Press'), 'overhead_press');
    expect(key('Arnold Press'), 'overhead_press');
  });

  test('"leg press" is a squat, not a press (order matters)', () {
    expect(key('Leg Press'), 'squat');
    expect(key('Barbell Squat'), 'squat');
    expect(key('Hack Squat'), 'squat');
    expect(key('Leg Extension'), 'squat');
  });

  test('"leg curl" is a hinge, not a curl (order matters)', () {
    expect(key('Lying Leg Curl'), 'hinge');
    expect(key('Romanian Deadlift'), 'hinge');
    expect(key('Conventional Deadlift'), 'hinge');
    expect(key('Hip Thrust'), 'hinge');
    expect(key('Barbell Curl'), 'curl');
    expect(key('Hammer Curl'), 'curl');
  });

  test('pulls disambiguate vertical vs horizontal', () {
    expect(key('Lat Pulldown'), 'pulldown');
    expect(key('Pull-Up'), 'pulldown');
    expect(key('Chin-Up'), 'pulldown');
    expect(key('Barbell Row'), 'row');
    expect(key('Seated Cable Row'), 'row');
    expect(key('Face Pull'), 'row');
  });

  test('isolation patterns', () {
    expect(key('Triceps Pushdown'), 'pushdown');
    expect(key('Skullcrusher'), 'pushdown');
    expect(key('Dumbbell Lateral Raise'), 'lateral_raise');
    expect(key('Rear Delt Fly'), 'lateral_raise');
    expect(key('Standing Calf Raise'), 'calf'); // calf before the raise rule
    expect(key('Hanging Leg Raise'), 'core'); // leg raise → core, not lateral
    expect(key('Cable Crunch'), 'core');
    expect(key('Walking Lunge'), 'lunge');
    expect(key('Bulgarian Split Squat'), 'lunge'); // single-leg before squat
  });

  test('unmatched lifts fall back to the generic barbell', () {
    expect(key('Some Made-Up Lift'), 'generic');
    expect(key(''), 'generic');
    expect(key('Farmer Carry'), 'generic');
  });

  test('every key resolves to a declared asset path', () {
    expect(liftIconAssetFor('Barbell Bench Press'),
        'assets/icons/lift-icons/press.png');
    for (final name in [
      'Bench Press',
      'Overhead Press',
      'Deadlift',
      'Squat',
      'Lunge',
      'Row',
      'Pull-Up',
      'Curl',
      'Pushdown',
      'Lateral Raise',
      'Plank',
      'Calf Raise',
      'Mystery',
    ]) {
      expect(liftIconAssetFor(name), startsWith('assets/icons/lift-icons/'));
      expect(liftIconAssetFor(name), endsWith('.png'));
    }
    // The mapped key is always one of the known icon files.
    expect(kLiftIconKeys, contains(liftIconKeyFor('Mystery')));
  });
}
