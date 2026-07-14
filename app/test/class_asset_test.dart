import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/widgets/radar_stat_icon.dart';

void main() {
  test('class portrait and sigil assets exist with expected dimensions', () {
    for (final characterClass in CharacterClass.values) {
      final name = characterClass.name;

      _expectPngSize('assets/classes/icons/$name.png', 64, 64);
      _expectPngSize('assets/classes/icons/2.0x/$name.png', 128, 128);
      _expectPngSize('assets/classes/icons/3.0x/$name.png', 192, 192);
      _expectPngSize('assets/classes/sigils/$name.png', 32, 32);
    }
  });

  test('radar stat assets exist and are registered', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/icons/radar/'));

    for (final path in RadarStatIcons.all) {
      _expectPngSize(path, 384, 384);
    }
  });
}

void _expectPngSize(String path, int width, int height) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path should exist');

  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24), reason: '$path is too small');
  expect(bytes.sublist(0, 8), [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ], reason: '$path should be a PNG');

  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  expect(data.getUint32(16), width, reason: '$path width');
  expect(data.getUint32(20), height, reason: '$path height');
}
