import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/exercise_demos.dart';
import 'package:workout_track/models/workout_models.dart';

void main() {
  Map<String, Map<String, dynamic>> loadCatalog() {
    final raw = File('assets/exercises.json').readAsStringSync();
    final decoded = jsonDecode(raw) as List<dynamic>;
    return {
      for (final item in decoded.cast<Map<String, dynamic>>())
        item['id'] as String: item,
    };
  }

  // Every source clip filed under animated-videos/, by catalog id (= filename).
  List<String> sourceClipIds() {
    final dir = Directory('assets/exercises/animated-videos');
    if (!dir.existsSync()) return const [];
    return [
      for (final f in dir.listSync(recursive: true).whereType<File>())
        if (f.path.toLowerCase().endsWith('.mp4'))
          f.uri.pathSegments.last.replaceFirst(RegExp(r'\.mp4$'), ''),
    ];
  }

  test('every demo exercise id exists in the catalog', () {
    final catalog = loadCatalog();
    final ids = demoExerciseIds().toList();
    expect(ids, isNotEmpty);
    final missing = ids.where((id) => !catalog.containsKey(id)).toList();
    expect(missing, isEmpty, reason: 'demo ids not in catalog: $missing');
  });

  test('every demo video + poster asset exists on disk', () {
    final missing =
        allDemoAssetPaths().where((p) => !File(p).existsSync()).toList();
    expect(missing, isEmpty, reason: 'missing demo asset files: $missing');
  });

  test('the demos asset folder is declared in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('assets/exercises/demos/'),
      isTrue,
      reason: 'declare assets/exercises/demos/ in pubspec.yaml',
    );
  });

  test('exerciseThumbAsset returns the poster for a demo exercise', () {
    final catalog = loadCatalog();
    final id = demoExerciseIds().first;
    final exercise = Exercise.fromJson(catalog[id]!);
    final demo = exerciseDemoFor(id)!;
    expect(exerciseThumbAsset(exercise), demo.poster);
  });

  test('exerciseThumbAsset falls back to the catalog photo otherwise', () {
    final catalog = loadCatalog();
    final nonDemoId =
        catalog.keys.firstWhere((id) => !hasExerciseDemo(id));
    final exercise = Exercise.fromJson(catalog[nonDemoId]!);
    expect(exerciseThumbAsset(exercise), exercise.imageAssetPath);
  });

  // The drop-a-file-and-go contract: a source clip whose name isn't a real
  // catalog id (the Lying_Leg_Curl vs Lying_Leg_Curls trap) or that was never
  // run through the generator must fail loudly, not become a dead demo.
  test('every source clip is named by a catalog id and is registered', () {
    final catalog = loadCatalog();
    final registered = demoExerciseIds().toSet();
    final ids = sourceClipIds();
    expect(ids, isNotEmpty, reason: 'no source clips discovered');

    final notInCatalog = ids.where((id) => !catalog.containsKey(id)).toList();
    expect(
      notInCatalog,
      isEmpty,
      reason: 'source clip names must equal an exercise catalog id: '
          '$notInCatalog',
    );

    final unregistered = ids
        .where((id) => catalog.containsKey(id) && !registered.contains(id))
        .toList();
    expect(
      unregistered,
      isEmpty,
      reason: 'sources not in kDemoExerciseIds — run '
          'python ops/generate_exercise_demos.py: $unregistered',
    );
  });
}
