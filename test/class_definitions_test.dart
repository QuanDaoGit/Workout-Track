import 'package:flutter_test/flutter_test.dart';

import 'package:workout_track/data/class_definitions.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/class_ability.dart';

void main() {
  group('class definitions', () {
    test('6 abilities total, 2 per class', () {
      expect(classAbilities.length, 6);
      for (final cls in CharacterClass.values) {
        final abilities = abilitiesForClass(cls);
        expect(abilities.length, 2, reason: '${cls.displayName} should have 2');
      }
    });

    test('each class has one primary and one ultimate', () {
      for (final cls in CharacterClass.values) {
        final abilities = abilitiesForClass(cls);
        expect(abilities.where((a) => a.slot == AbilitySlot.primary).length, 1);
        expect(
            abilities.where((a) => a.slot == AbilitySlot.ultimate).length, 1);
      }
    });

    test('primaryAbility returns primary slot', () {
      for (final cls in CharacterClass.values) {
        expect(primaryAbility(cls).slot, AbilitySlot.primary);
        expect(primaryAbility(cls).owner, cls);
      }
    });

    test('ultimateAbility returns ultimate slot', () {
      for (final cls in CharacterClass.values) {
        expect(ultimateAbility(cls).slot, AbilitySlot.ultimate);
        expect(ultimateAbility(cls).owner, cls);
      }
    });

    test('musclesForClass returns non-empty sets', () {
      for (final cls in CharacterClass.values) {
        expect(musclesForClass(cls).isNotEmpty, true);
      }
    });

    test('assassin muscles are AGI muscles', () {
      final muscles = musclesForClass(CharacterClass.assassin);
      expect(muscles.contains('shoulders'), true);
      expect(muscles.contains('abdominals'), true);
    });

    test('bruiser muscles are STR+DEF muscles', () {
      final muscles = musclesForClass(CharacterClass.bruiser);
      expect(muscles.contains('chest'), true);
      expect(muscles.contains('lats'), true);
      expect(muscles.contains('biceps'), true);
    });

    test('tank muscles are VIT muscles', () {
      final muscles = musclesForClass(CharacterClass.tank);
      expect(muscles.contains('quadriceps'), true);
      expect(muscles.contains('hamstrings'), true);
      expect(muscles.contains('glutes'), true);
    });

    test('muscle sets do not overlap between classes', () {
      final assassin = musclesForClass(CharacterClass.assassin);
      final bruiser = musclesForClass(CharacterClass.bruiser);
      final tank = musclesForClass(CharacterClass.tank);
      expect(assassin.intersection(bruiser).isEmpty, true);
      expect(assassin.intersection(tank).isEmpty, true);
      expect(bruiser.intersection(tank).isEmpty, true);
    });

    test('focusMusclesLabel returns non-empty string', () {
      for (final cls in CharacterClass.values) {
        expect(focusMusclesLabel(cls).isNotEmpty, true);
      }
    });
  });

  group('CharacterClass extension', () {
    test('displayName returns uppercase names', () {
      expect(CharacterClass.assassin.displayName, 'ASSASSIN');
      expect(CharacterClass.bruiser.displayName, 'BRUISER');
      expect(CharacterClass.tank.displayName, 'TANK');
    });

    test('themeColor is distinct for each class', () {
      final colors = CharacterClass.values.map((c) => c.themeColor).toSet();
      expect(colors.length, 3);
    });

    test('bodyGoalLabel maps correctly', () {
      expect(CharacterClass.assassin.bodyGoalLabel, 'CUT');
      expect(CharacterClass.bruiser.bodyGoalLabel, 'RECOMP');
      expect(CharacterClass.tank.bodyGoalLabel, 'BULK');
    });
  });
}
