import 'character_class.dart';

enum AbilitySlot { primary, ultimate }

class ClassAbility {
  const ClassAbility({
    required this.id,
    required this.name,
    required this.description,
    required this.slot,
    required this.owner,
  });

  final String id;
  final String name;
  final String description;
  final AbilitySlot slot;
  final CharacterClass owner;
}
