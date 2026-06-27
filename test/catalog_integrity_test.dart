import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/curated_exercises.dart';
import 'package:workout_track/data/exercise_demos.dart';
import 'package:workout_track/data/muscle_splits.dart';
import 'package:workout_track/data/programs_library.dart';

/// The umbrella guard for exercise-id references: every place a built-in id is
/// wired (curated picker, preset programs, muscle-split overrides, demo
/// manifest) must resolve to a live entry in assets/exercises.json. This makes
/// an *incomplete* removal fail loudly in ONE place instead of being scattered
/// across four registry-specific tests. Image existence is asserted for curated
/// ids (the picker renders them); the other layers are resolve-only (an id that
/// is curated already gets its image checked, and program/demo ids are curated).
void main() {
  final raw = File('assets/exercises.json').readAsStringSync();
  final catalog = {
    for (final item in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
      item['id'] as String: item,
  };

  List<String> dangling(Iterable<String> ids) =>
      ids.where((id) => !catalog.containsKey(id)).toList();

  test('every curated id resolves and has a first image', () {
    final curated = curatedExerciseIdsByMuscleGroup.values
        .expand((ids) => ids)
        .toSet();
    expect(curated, isNotEmpty);
    expect(dangling(curated), isEmpty,
        reason: 'curated ids not in the catalog (incomplete removal?)');

    final missingImage = <String>[];
    for (final id in curated) {
      final images = (catalog[id]!['images'] as List<dynamic>? ?? const []);
      if (images.isEmpty ||
          !File('assets/exercises/exercises/${images.first}').existsSync()) {
        missingImage.add(id);
      }
    }
    expect(missingImage, isEmpty, reason: 'curated ids missing a first photo');
  });

  test('every program id (suggested + prescription) resolves', () {
    final ids = <String>{};
    for (final program in programsLibrary) {
      for (final day in program.weekSchedule.where((d) => d.isWorkout)) {
        ids.addAll(day.suggestedExerciseIds);
        ids.addAll(day.prescription.keys);
      }
    }
    expect(dangling(ids), isEmpty,
        reason: 'program references a removed exercise — replace it, do not '
            'leave the day short');
  });

  test('every curatedMuscleSplits id resolves', () {
    expect(dangling(curatedMuscleSplits.keys), isEmpty,
        reason: 'a split override points at a removed exercise');
  });

  test('every demo-manifest id resolves', () {
    expect(dangling(demoExerciseIds()), isEmpty,
        reason: 'the demo manifest lists a removed exercise');
  });

  // Exercise image folders are declared individually in pubspec (Flutter asset
  // dirs are non-recursive). A removal that deletes a folder but leaves its
  // declaration breaks `flutter build` on the missing directory — assert every
  // declared exercise folder still exists on disk.
  test('every pubspec-declared exercise image folder exists on disk', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'assets/exercises/exercises/([^/\s]+)/')
        .allMatches(pubspec)
        .map((m) => m.group(1)!)
        .toList();
    expect(declared, isNotEmpty);
    final missing = declared
        .where((f) => !Directory('assets/exercises/exercises/$f').existsSync())
        .toList();
    expect(missing, isEmpty,
        reason: 'pubspec declares image folders that no longer exist '
            '(flutter build would fail): $missing');
  });

  // F8 (Codex): the replacement-specific regressions a resolve check misses —
  // a botched swap that duplicates an id in a day or orphans a prescription key.
  test('each workout day has unique suggested ids matching its prescription', () {
    for (final program in programsLibrary) {
      for (final day in program.weekSchedule.where((d) => d.isWorkout)) {
        final ids = day.suggestedExerciseIds;
        expect(ids.toSet().length, ids.length,
            reason: '${program.id} / ${day.label} has duplicate suggested ids: '
                '$ids');
        expect(day.prescription.keys.toSet(), ids.toSet(),
            reason: '${program.id} / ${day.label}: prescription keys diverge '
                'from suggested ids');
      }
    }
  });
}
