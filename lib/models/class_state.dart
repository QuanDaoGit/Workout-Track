import 'character_class.dart';

/// A class the user previously held, recorded on each respec.
class FormerClass {
  const FormerClass({required this.clazz, required this.changedAt});

  final CharacterClass clazz;
  final DateTime changedAt;

  Map<String, dynamic> toJson() => {
    'clazz': clazz.name,
    'changedAt': changedAt.toIso8601String(),
  };

  factory FormerClass.fromJson(Map<String, dynamic> json) => FormerClass(
    clazz: CharacterClass.values.firstWhere(
      (c) => c.name == json['clazz'],
      orElse: () => CharacterClass.bruiser,
    ),
    changedAt:
        DateTime.tryParse(json['changedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class ClassState {
  const ClassState({
    required this.currentClass,
    required this.selectedAt,
    required this.volumeSnapshot,
    this.nextRespecAt,
    this.formerClasses = const [],
  });

  final CharacterClass currentClass;
  final DateTime selectedAt;
  final double volumeSnapshot;

  /// When the next respec becomes available (null until the first respec, then
  /// `respec_time + 30 days`).
  final DateTime? nextRespecAt;

  /// Every class held before the current one, oldest first.
  final List<FormerClass> formerClasses;

  FormerClass? get mostRecentFormerClass =>
      formerClasses.isEmpty ? null : formerClasses.last;

  ClassState copyWith({
    CharacterClass? currentClass,
    DateTime? selectedAt,
    double? volumeSnapshot,
    DateTime? nextRespecAt,
    List<FormerClass>? formerClasses,
  }) => ClassState(
    currentClass: currentClass ?? this.currentClass,
    selectedAt: selectedAt ?? this.selectedAt,
    volumeSnapshot: volumeSnapshot ?? this.volumeSnapshot,
    nextRespecAt: nextRespecAt ?? this.nextRespecAt,
    formerClasses: formerClasses ?? this.formerClasses,
  );

  Map<String, dynamic> toJson() => {
    'currentClass': currentClass.name,
    'selectedAt': selectedAt.toIso8601String(),
    'volumeSnapshot': volumeSnapshot,
    if (nextRespecAt != null) 'nextRespecAt': nextRespecAt!.toIso8601String(),
    if (formerClasses.isNotEmpty)
      'formerClasses': formerClasses.map((f) => f.toJson()).toList(),
  };

  factory ClassState.fromJson(Map<String, dynamic> json) => ClassState(
    currentClass: CharacterClass.values.firstWhere(
      (c) => c.name == json['currentClass'],
      orElse: () => CharacterClass.bruiser,
    ),
    selectedAt: DateTime.parse(json['selectedAt'] as String),
    volumeSnapshot: (json['volumeSnapshot'] as num).toDouble(),
    nextRespecAt: json['nextRespecAt'] == null
        ? null
        : DateTime.tryParse(json['nextRespecAt'] as String),
    formerClasses: [
      for (final f in (json['formerClasses'] as List<dynamic>? ?? []))
        FormerClass.fromJson(f as Map<String, dynamic>),
    ],
  );
}
