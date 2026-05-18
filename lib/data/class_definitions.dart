import '../models/character_class.dart';

/// Muscle groups relevant to each class for volume tracking.
/// These map directly to StatEngine's _statForPrimaryMuscle groupings.
Set<String> musclesForClass(CharacterClass cls) => switch (cls) {
  CharacterClass.assassin => const {'shoulders', 'abdominals'},
  CharacterClass.bruiser => const {
    'chest',
    'triceps',
    'forearms',
    'lats',
    'middle back',
    'lower back',
    'biceps',
    'traps',
    'neck',
  },
  CharacterClass.tank => const {
    'quadriceps',
    'hamstrings',
    'glutes',
    'calves',
    'adductors',
    'abductors',
  },
};

/// Human-readable focus muscle label for display.
String focusMusclesLabel(CharacterClass cls) => switch (cls) {
  CharacterClass.assassin => 'SHOULDERS + CORE',
  CharacterClass.bruiser => 'CHEST + BACK + ARMS',
  CharacterClass.tank => 'LEGS',
};
