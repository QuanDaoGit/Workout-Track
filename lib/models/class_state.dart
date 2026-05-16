import 'character_class.dart';

class ClassState {
  const ClassState({
    required this.currentClass,
    required this.selectedAt,
    required this.volumeSnapshot,
    required this.unlockedAbilityIds,
  });

  final CharacterClass currentClass;
  final DateTime selectedAt;
  final double volumeSnapshot;
  final Set<String> unlockedAbilityIds;

  ClassState copyWith({
    CharacterClass? currentClass,
    DateTime? selectedAt,
    double? volumeSnapshot,
    Set<String>? unlockedAbilityIds,
  }) =>
      ClassState(
        currentClass: currentClass ?? this.currentClass,
        selectedAt: selectedAt ?? this.selectedAt,
        volumeSnapshot: volumeSnapshot ?? this.volumeSnapshot,
        unlockedAbilityIds: unlockedAbilityIds ?? this.unlockedAbilityIds,
      );

  Map<String, dynamic> toJson() => {
    'currentClass': currentClass.name,
    'selectedAt': selectedAt.toIso8601String(),
    'volumeSnapshot': volumeSnapshot,
    'unlockedAbilityIds': unlockedAbilityIds.toList(),
  };

  factory ClassState.fromJson(Map<String, dynamic> json) => ClassState(
    currentClass: CharacterClass.values.firstWhere(
      (c) => c.name == json['currentClass'],
      orElse: () => CharacterClass.bruiser,
    ),
    selectedAt: DateTime.parse(json['selectedAt'] as String),
    volumeSnapshot: (json['volumeSnapshot'] as num).toDouble(),
    unlockedAbilityIds: {
      for (final id in json['unlockedAbilityIds'] as List<dynamic>)
        id as String,
    },
  );
}
