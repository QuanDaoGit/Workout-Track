import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/body_map_regions.dart';
import 'package:workout_track/models/workout_models.dart';

/// The selection-screen "today's targets" mapping: selected exercises → the body
/// muscles they train (primary vs synergist), reusing the SAME primary→detailed→
/// body path as the coverage map + strength roster.
void main() {
  Exercise ex(String id, String primary, [List<String> sec = const []]) =>
      Exercise(
        id: id,
        name: id,
        level: 'beginner',
        images: const [],
        primaryMuscle: primary,
        secondaryMuscles: sec,
      );

  test('files primary muscle + secondary synergists onto body muscles', () {
    final t = targetedBodyMuscles([
      ex('Bench', 'chest', ['triceps', 'shoulders']),
    ]);
    expect(t.primary, {'chest'});
    // shoulders → front cap (front_delt) via the coarse fold; triceps → triceps.
    expect(t.secondary, {'triceps', 'front_delt'});
  });

  test('custom lift with no secondaries → primary only', () {
    final t = targetedBodyMuscles([ex('My Press', 'chest')]);
    expect(t.primary, {'chest'});
    expect(t.secondary, isEmpty);
  });

  test('an unmapped token contributes nothing (no crash)', () {
    final t = targetedBodyMuscles([ex('Mystery', 'levitation')]);
    expect(t.primary, isEmpty);
    expect(t.secondary, isEmpty);
  });

  test('primary wins on overlap — never demoted to secondary', () {
    final t = targetedBodyMuscles([
      ex('Bench', 'chest', ['triceps']),
      ex('Pushdown', 'triceps', ['chest']), // chest only assists here
    ]);
    expect(t.primary, {'chest', 'triceps'});
    expect(t.secondary, isEmpty); // both are someone's primary → not secondary
  });

  test('accumulates across the whole loadout', () {
    final t = targetedBodyMuscles([
      ex('Squat', 'quadriceps', ['glutes']),
      ex('Curl', 'biceps'),
    ]);
    expect(t.primary, {'quads', 'biceps'});
    expect(t.secondary, {'glutes'});
  });

  test('empty loadout → no targets', () {
    final t = targetedBodyMuscles(const <Exercise>[]);
    expect(t.primary, isEmpty);
    expect(t.secondary, isEmpty);
  });
}
