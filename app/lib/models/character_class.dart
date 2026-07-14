import 'dart:ui';

import '../theme/tokens.dart';
import 'body_goal_models.dart';

enum CharacterClass { assassin, bruiser, tank }

extension CharacterClassX on CharacterClass {
  String get displayName => switch (this) {
    CharacterClass.assassin => 'ASSASSIN',
    CharacterClass.bruiser => 'BRUISER',
    CharacterClass.tank => 'TANK',
  };

  /// Accent color — matches each class's icon art (daggers = violet,
  /// helmet = red, shield = blue).
  Color get themeColor => switch (this) {
    CharacterClass.assassin => const Color(0xFFB14DFF), // violet
    CharacterClass.bruiser => kDanger, // red
    CharacterClass.tank => kCyan, // blue
  };

  BodyGoal get associatedBodyGoal => switch (this) {
    CharacterClass.assassin => BodyGoal.cut,
    CharacterClass.bruiser => BodyGoal.recomp,
    CharacterClass.tank => BodyGoal.bulk,
  };

  String get bodyGoalLabel => switch (this) {
    CharacterClass.assassin => 'CUT',
    CharacterClass.bruiser => 'RECOMP',
    CharacterClass.tank => 'BULK',
  };

  /// All classes are available from level 1.
  int get unlockLevel => 1;
}
