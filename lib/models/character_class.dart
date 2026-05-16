import 'dart:ui';

import 'body_goal_models.dart';

enum CharacterClass { assassin, bruiser, tank }

extension CharacterClassX on CharacterClass {
  String get displayName => switch (this) {
    CharacterClass.assassin => 'ASSASSIN',
    CharacterClass.bruiser => 'BRUISER',
    CharacterClass.tank => 'TANK',
  };

  Color get themeColor => switch (this) {
    CharacterClass.assassin => const Color(0xFF4DE5FF),
    CharacterClass.bruiser => const Color(0xFFFFD700),
    CharacterClass.tank => const Color(0xFFFF2D55),
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
}
