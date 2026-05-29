import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/character_class.dart';

void main() {
  test('class portrait and sigil assets exist with expected dimensions', () {
    for (final characterClass in CharacterClass.values) {
      // Vanguard art is not authored yet; ClassSprite renders an errorBuilder
      // placeholder until the assets land. Skip its asset-dimension checks.
      if (characterClass == CharacterClass.vanguard) continue;
      final name = characterClass.name;

      _expectPngSize('assets/classes/icons/$name.png', 64, 64);
      _expectPngSize('assets/classes/icons/2.0x/$name.png', 128, 128);
      _expectPngSize('assets/classes/icons/3.0x/$name.png', 192, 192);
      _expectPngSize('assets/classes/sigils/$name.png', 32, 32);
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
