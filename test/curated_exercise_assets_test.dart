import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/curated_exercises.dart';

void main() {
  test('every curated exercise exists and has a first photo asset', () {
    final raw = File('assets/exercises.json').readAsStringSync();
    final decoded = jsonDecode(raw) as List<dynamic>;
    final catalog = {
      for (final item in decoded.cast<Map<String, dynamic>>())
        item['id'] as String: item,
    };
    final curatedIds = curatedExerciseIdsByMuscleGroup.values
        .expand((ids) => ids)
        .toSet();

    expect(curatedIds, isNotEmpty);

    final missingCatalog = <String>[];
    final missingImages = <String>[];
    for (final id in curatedIds) {
      final item = catalog[id];
      if (item == null) {
        missingCatalog.add(id);
        continue;
      }
      final images = (item['images'] as List<dynamic>? ?? const []);
      if (images.isEmpty ||
          !File('assets/exercises/exercises/${images.first}').existsSync()) {
        missingImages.add(id);
      }
    }

    expect(missingCatalog, isEmpty);
    expect(missingImages, isEmpty);
  });
}
