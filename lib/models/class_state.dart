import 'character_class.dart';

class ClassState {
  const ClassState({
    required this.currentClass,
    required this.selectedAt,
    required this.volumeSnapshot,
  });

  final CharacterClass currentClass;
  final DateTime selectedAt;
  final double volumeSnapshot;

  ClassState copyWith({
    CharacterClass? currentClass,
    DateTime? selectedAt,
    double? volumeSnapshot,
  }) => ClassState(
    currentClass: currentClass ?? this.currentClass,
    selectedAt: selectedAt ?? this.selectedAt,
    volumeSnapshot: volumeSnapshot ?? this.volumeSnapshot,
  );

  Map<String, dynamic> toJson() => {
    'currentClass': currentClass.name,
    'selectedAt': selectedAt.toIso8601String(),
    'volumeSnapshot': volumeSnapshot,
  };

  factory ClassState.fromJson(Map<String, dynamic> json) => ClassState(
    currentClass: CharacterClass.values.firstWhere(
      (c) => c.name == json['currentClass'],
      orElse: () => CharacterClass.bruiser,
    ),
    selectedAt: DateTime.parse(json['selectedAt'] as String),
    volumeSnapshot: (json['volumeSnapshot'] as num).toDouble(),
  );
}
