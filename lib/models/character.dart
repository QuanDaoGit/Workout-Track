import 'body_goal_models.dart';
import 'calibration_quiz_models.dart';
import 'character_class.dart';
import 'resolve_models.dart';
import 'user_profile_sex.dart';

class Character {
  const Character({
    required this.name,
    required this.calibration,
    required this.classConfirmedAt,
    required this.characterName,
    required this.createdAt,
    this.winningVision = const <WinningVision>{},
    this.obstacle = const <Obstacle>{},
    this.trainingWhy = const <TrainingWhy>{},
  });

  final String name;
  final CalibrationResult calibration;
  final DateTime classConfirmedAt;
  final String characterName;
  final DateTime createdAt;

  // "Forge Your Resolve" answers — multi-select; empty for characters created
  // before the resolve beat existed.
  final Set<WinningVision> winningVision;
  final Set<Obstacle> obstacle;
  final Set<TrainingWhy> trainingWhy;

  Map<String, dynamic> toJson() => {
    'name': name,
    'calibration': {
      'goal': calibration.goal.name,
      'freq': calibration.freq.name,
      'exp': calibration.exp.name,
      if (calibration.bodyWeightKg != null)
        'bodyWeightKg': calibration.bodyWeightKg,
      'sex': calibration.sex.name,
      'clazz': calibration.clazz.name,
    },
    'classConfirmedAt': classConfirmedAt.toIso8601String(),
    'characterName': characterName,
    'createdAt': createdAt.toIso8601String(),
    if (winningVision.isNotEmpty)
      'winningVision': winningVision.map((e) => e.name).toList(),
    if (obstacle.isNotEmpty) 'obstacle': obstacle.map((e) => e.name).toList(),
    if (trainingWhy.isNotEmpty)
      'trainingWhy': trainingWhy.map((e) => e.name).toList(),
  };

  factory Character.fromJson(Map<String, dynamic> json) {
    final calibrationJson =
        (json['calibration'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return Character(
      name: json['name'] as String? ?? '',
      calibration: CalibrationResult(
        goal: BodyGoal.values.firstWhere(
          (goal) => goal.name == calibrationJson['goal'],
          orElse: () => BodyGoal.recomp,
        ),
        freq: TrainingFreq.fromName(calibrationJson['freq'] as String?),
        exp: Experience.fromName(calibrationJson['exp'] as String?),
        bodyWeightKg: (calibrationJson['bodyWeightKg'] as num?)?.toDouble(),
        sex: UserProfileSex.fromName(calibrationJson['sex'] as String?),
        clazz: CharacterClass.values.firstWhere(
          (clazz) => clazz.name == calibrationJson['clazz'],
          orElse: () => CharacterClass.bruiser,
        ),
      ),
      classConfirmedAt:
          DateTime.tryParse(json['classConfirmedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      // Legacy `selectedAvatarId` (old image picker) is intentionally ignored
      // — the avatar now lives on the profile store as an AvatarSpec.
      characterName: json['characterName'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      winningVision: _decodeResolveSet(
        json['winningVision'],
        WinningVision.fromName,
      ),
      obstacle: _decodeResolveSet(json['obstacle'], Obstacle.fromName),
      trainingWhy: _decodeResolveSet(json['trainingWhy'], TrainingWhy.fromName),
    );
  }
}

/// Decodes a stored resolve answer into a set. Tolerates a `List` (current
/// multi-select format), a single `String` (legacy single-select saves), or
/// null. Unknown names are dropped via the enum's `fromName`.
Set<T> _decodeResolveSet<T>(dynamic raw, T? Function(String?) fromName) {
  final names = switch (raw) {
    final List<dynamic> list => list.map((e) => e?.toString()),
    final String s => [s],
    _ => const <String?>[],
  };
  final out = <T>{};
  for (final name in names) {
    final value = fromName(name);
    if (value != null) out.add(value);
  }
  return out;
}
