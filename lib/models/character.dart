import 'body_goal_models.dart';
import 'calibration_quiz_models.dart';
import 'character_class.dart';
import 'user_profile_sex.dart';

class Character {
  const Character({
    required this.name,
    required this.calibration,
    required this.classConfirmedAt,
    required this.selectedAvatarId,
    required this.characterName,
    required this.createdAt,
  });

  final String name;
  final CalibrationResult calibration;
  final DateTime classConfirmedAt;
  final String selectedAvatarId;
  final String characterName;
  final DateTime createdAt;

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
    'selectedAvatarId': selectedAvatarId,
    'characterName': characterName,
    'createdAt': createdAt.toIso8601String(),
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
      selectedAvatarId: json['selectedAvatarId'] as String? ?? '',
      characterName: json['characterName'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
