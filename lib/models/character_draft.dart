import 'calibration_quiz_models.dart';
import 'resolve_models.dart';

class CharacterDraft {
  const CharacterDraft({
    required this.calibration,
    required this.classConfirmedAt,
    this.characterName,
    this.selectedProgramId,
    this.winningVision = const <WinningVision>{},
    this.obstacle = const <Obstacle>{},
    this.trainingWhy = const <TrainingWhy>{},
  });

  final CalibrationResult calibration;
  final DateTime classConfirmedAt;
  final String? characterName;
  final String? selectedProgramId;

  // "Forge Your Resolve" answers — multi-select identity beats from the quiz.
  final Set<WinningVision> winningVision;
  final Set<Obstacle> obstacle;
  final Set<TrainingWhy> trainingWhy;

  CharacterDraft copyWith({
    CalibrationResult? calibration,
    DateTime? classConfirmedAt,
    String? characterName,
    String? selectedProgramId,
    Set<WinningVision>? winningVision,
    Set<Obstacle>? obstacle,
    Set<TrainingWhy>? trainingWhy,
  }) {
    return CharacterDraft(
      calibration: calibration ?? this.calibration,
      classConfirmedAt: classConfirmedAt ?? this.classConfirmedAt,
      characterName: characterName ?? this.characterName,
      selectedProgramId: selectedProgramId ?? this.selectedProgramId,
      winningVision: winningVision ?? this.winningVision,
      obstacle: obstacle ?? this.obstacle,
      trainingWhy: trainingWhy ?? this.trainingWhy,
    );
  }
}
