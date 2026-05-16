import '../models/character_class.dart';
import '../models/class_ability.dart';

/// All class abilities in the game.
const classAbilities = [
  // Assassin
  ClassAbility(
    id: 'assassin_shadow_strike',
    name: 'SHADOW STRIKE',
    description: 'On crit, immediate extra turn this round.',
    slot: AbilitySlot.primary,
    owner: CharacterClass.assassin,
  ),
  ClassAbility(
    id: 'assassin_phantom_edge',
    name: 'PHANTOM EDGE',
    description:
        'On killing blow, recover 25% HP and gain +10% crit next battle.',
    slot: AbilitySlot.ultimate,
    owner: CharacterClass.assassin,
  ),
  // Bruiser
  ClassAbility(
    id: 'bruiser_overpower',
    name: 'OVERPOWER',
    description: 'Every 3rd hit deals 2x damage.',
    slot: AbilitySlot.primary,
    owner: CharacterClass.bruiser,
  ),
  ClassAbility(
    id: 'bruiser_iron_tide',
    name: 'IRON TIDE',
    description: 'Every 5th battle won, next battle deals +50% damage.',
    slot: AbilitySlot.ultimate,
    owner: CharacterClass.bruiser,
  ),
  // Tank
  ClassAbility(
    id: 'tank_iron_will',
    name: 'IRON WILL',
    description:
        'When HP drops below 30%, gain 50% damage reduction for 3 turns.',
    slot: AbilitySlot.primary,
    owner: CharacterClass.tank,
  ),
  ClassAbility(
    id: 'tank_last_stand',
    name: 'LAST STAND',
    description: 'First time HP would hit 0 in a battle, survive at 1 HP.',
    slot: AbilitySlot.ultimate,
    owner: CharacterClass.tank,
  ),
];

/// Returns both abilities for the given class.
List<ClassAbility> abilitiesForClass(CharacterClass cls) =>
    classAbilities.where((a) => a.owner == cls).toList();

/// Returns the primary ability for the class.
ClassAbility primaryAbility(CharacterClass cls) =>
    classAbilities.firstWhere(
      (a) => a.owner == cls && a.slot == AbilitySlot.primary,
    );

/// Returns the ultimate ability for the class.
ClassAbility ultimateAbility(CharacterClass cls) =>
    classAbilities.firstWhere(
      (a) => a.owner == cls && a.slot == AbilitySlot.ultimate,
    );

/// Muscle groups relevant to each class for volume tracking.
/// These map directly to StatEngine's _statForPrimaryMuscle groupings.
Set<String> musclesForClass(CharacterClass cls) => switch (cls) {
  CharacterClass.assassin => const {'shoulders', 'abdominals'},
  CharacterClass.bruiser => const {
    'chest', 'triceps', 'forearms',
    'lats', 'middle back', 'lower back', 'biceps', 'traps', 'neck',
  },
  CharacterClass.tank => const {
    'quadriceps', 'hamstrings', 'glutes', 'calves', 'adductors', 'abductors',
  },
};

/// Human-readable focus muscle label for display.
String focusMusclesLabel(CharacterClass cls) => switch (cls) {
  CharacterClass.assassin => 'SHOULDERS + CORE',
  CharacterClass.bruiser => 'CHEST + BACK + ARMS',
  CharacterClass.tank => 'LEGS',
};
