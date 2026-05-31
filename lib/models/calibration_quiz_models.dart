import 'body_goal_models.dart';
import 'character_class.dart';
import 'user_profile_sex.dart';

/// Training cadence captured by the calibration quiz's Q2. Feeds future quest
/// cadence / weekly shield tuning; persisted independently of body-metrics.
enum TrainingFreq {
  low,
  mid,
  high;

  String get label => switch (this) {
    TrainingFreq.low => '2–3 DAYS',
    TrainingFreq.mid => '4–5 DAYS',
    TrainingFreq.high => '6+ DAYS',
  };

  static TrainingFreq fromName(String? raw) {
    for (final value in TrainingFreq.values) {
      if (value.name == raw) return value;
    }
    return TrainingFreq.mid;
  }
}

/// Self-reported training experience captured by Q3. Seeds the character's
/// starting capability stats at class-confirm time via
/// [CalibrationService.seedFromQuiz] (novice→D, beginner→C, intermediate→B,
/// advanced→A; S is earned, not self-reported).
enum Experience {
  novice,
  beginner,
  intermediate,
  advanced;

  String get label => switch (this) {
    Experience.novice => 'NOVICE',
    Experience.beginner => 'BEGINNER',
    Experience.intermediate => 'INTERMEDIATE',
    Experience.advanced => 'ADVANCED',
  };

  static Experience fromName(String? raw) {
    for (final value in Experience.values) {
      if (value.name == raw) return value;
    }
    return Experience.beginner;
  }
}

/// Immutable payload produced when the calibration quiz completes. `goal` is
/// also the character path label (`BodyGoalState.goalLabel` → CUT/RECOMP/BULK),
/// so no separate "path" enum is needed.
class CalibrationResult {
  const CalibrationResult({
    required this.goal,
    required this.freq,
    required this.exp,
    required this.bodyWeightKg,
    required this.sex,
    required this.clazz,
  });

  final BodyGoal goal;
  final TrainingFreq freq;
  final Experience exp;
  final double? bodyWeightKg;
  final UserProfileSex sex;
  final CharacterClass clazz;
}

/// Pure function — keep the goal→class mapping isolated so it can be swapped
/// for a multi-answer triangulation later without touching the quiz UI.
CharacterClass deriveClass(BodyGoal goal) => switch (goal) {
  BodyGoal.cut => CharacterClass.assassin,
  BodyGoal.recomp => CharacterClass.bruiser,
  BodyGoal.bulk => CharacterClass.tank,
};
