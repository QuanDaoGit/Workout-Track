import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/theme/tokens.dart';

void main() {
  test('class roster is exactly the three first-selectable classes', () {
    expect(CharacterClass.values, [
      CharacterClass.assassin,
      CharacterClass.bruiser,
      CharacterClass.tank,
    ]);
  });

  test('class theme colors match their icon art', () {
    // Daggers = violet, helmet = red, shield = blue.
    expect(CharacterClass.assassin.themeColor, const Color(0xFFB14DFF));
    expect(CharacterClass.bruiser.themeColor, kDanger);
    expect(CharacterClass.tank.themeColor, kCyan);
  });
}
