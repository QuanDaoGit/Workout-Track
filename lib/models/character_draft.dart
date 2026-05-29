import 'calibration_quiz_models.dart';

class CharacterDraft {
  const CharacterDraft({
    required this.calibration,
    required this.classConfirmedAt,
    this.selectedAvatarId,
    this.characterName,
  });

  final CalibrationResult calibration;
  final DateTime classConfirmedAt;
  final String? selectedAvatarId;
  final String? characterName;

  CharacterDraft copyWith({
    CalibrationResult? calibration,
    DateTime? classConfirmedAt,
    String? selectedAvatarId,
    String? characterName,
  }) {
    return CharacterDraft(
      calibration: calibration ?? this.calibration,
      classConfirmedAt: classConfirmedAt ?? this.classConfirmedAt,
      selectedAvatarId: selectedAvatarId ?? this.selectedAvatarId,
      characterName: characterName ?? this.characterName,
    );
  }
}
