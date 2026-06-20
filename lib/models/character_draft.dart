import 'calibration_quiz_models.dart';
import 'resolve_models.dart';

class CharacterDraft {
  const CharacterDraft({
    required this.calibration,
    required this.classConfirmedAt,
    this.characterName,
    this.selectedProgramId,
    this.trainingWeekdays,
    this.winningVision = const <WinningVision>{},
    this.obstacle,
    this.trainingWhy = const <TrainingWhy>{},
  });

  final CalibrationResult calibration;
  final DateTime classConfirmedAt;
  final String? characterName;
  final String? selectedProgramId;

  /// Optional weekday anchor (1=Mon..7=Sun) chosen alongside the program in
  /// onboarding. Applied immediately at character creation (no next-Monday
  /// pending — there is no history to protect for a brand-new user).
  final Set<int>? trainingWeekdays;

  // "Forge Your Resolve" answers — multi-select identity beats from the quiz.
  final Set<WinningVision> winningVision;
  final Obstacle? obstacle;
  final Set<TrainingWhy> trainingWhy;

  CharacterDraft copyWith({
    CalibrationResult? calibration,
    DateTime? classConfirmedAt,
    String? characterName,
    String? selectedProgramId,
    Set<int>? trainingWeekdays,
    Set<WinningVision>? winningVision,
    Obstacle? obstacle,
    Set<TrainingWhy>? trainingWhy,
  }) {
    return CharacterDraft(
      calibration: calibration ?? this.calibration,
      classConfirmedAt: classConfirmedAt ?? this.classConfirmedAt,
      characterName: characterName ?? this.characterName,
      selectedProgramId: selectedProgramId ?? this.selectedProgramId,
      trainingWeekdays: trainingWeekdays ?? this.trainingWeekdays,
      winningVision: winningVision ?? this.winningVision,
      obstacle: obstacle ?? this.obstacle,
      trainingWhy: trainingWhy ?? this.trainingWhy,
    );
  }
}
