import '../models/character_class.dart';

/// Canonical muscle-group buckets each class focuses on. Used by
/// `ClassService.getCurrentVolume` to attribute training to a class.
Set<String> musclesForClass(CharacterClass cls) => switch (cls) {
  CharacterClass.assassin => const {'Shoulders', 'Core'},
  CharacterClass.bruiser => const {'Chest', 'Back', 'Arms'},
  CharacterClass.tank => const {'Legs'},
};

/// Human-readable focus muscle label for display.
String focusMusclesLabel(CharacterClass cls) => switch (cls) {
  CharacterClass.assassin => 'SHOULDERS + CORE',
  CharacterClass.bruiser => 'CHEST + BACK + ARMS',
  CharacterClass.tank => 'LEGS',
};
