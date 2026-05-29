import 'dart:ui';

import 'body_goal_models.dart';

// Vanguard is the balanced all-rounder unlocked at Level 10 (respec only —
// never offered at first class-select).
enum CharacterClass { assassin, bruiser, tank, vanguard }

extension CharacterClassX on CharacterClass {
  String get displayName => switch (this) {
    CharacterClass.assassin => 'ASSASSIN',
    CharacterClass.bruiser => 'BRUISER',
    CharacterClass.tank => 'TANK',
    CharacterClass.vanguard => 'VANGUARD',
  };

  Color get themeColor => switch (this) {
    CharacterClass.assassin => const Color(0xFF4DE5FF),
    CharacterClass.bruiser => const Color(0xFFFFD700),
    CharacterClass.tank => const Color(0xFFFF2D55),
    CharacterClass.vanguard => const Color(0xFFB14DFF), // violet
  };

  BodyGoal get associatedBodyGoal => switch (this) {
    CharacterClass.assassin => BodyGoal.cut,
    CharacterClass.bruiser => BodyGoal.recomp,
    CharacterClass.tank => BodyGoal.bulk,
    CharacterClass.vanguard => BodyGoal.recomp, // balanced ≈ recomp
  };

  String get bodyGoalLabel => switch (this) {
    CharacterClass.assassin => 'CUT',
    CharacterClass.bruiser => 'RECOMP',
    CharacterClass.tank => 'BULK',
    CharacterClass.vanguard => 'ALL-ROUNDER',
  };

  /// Vanguard unlocks at this level; other classes are always available.
  int get unlockLevel => this == CharacterClass.vanguard ? 10 : 1;
}
