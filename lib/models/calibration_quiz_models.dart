import 'body_goal_models.dart';
import 'character_class.dart';
import 'resolve_models.dart';
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

/// Self-reported training experience captured by Q3. This is stored as
/// training context only; it does not grant character stat value.
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
    this.heightCm,
    required this.sex,
    required this.clazz,
  });

  final BodyGoal goal;
  final TrainingFreq freq;
  final Experience exp;
  final double? bodyWeightKg;
  final double? heightCm;
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

/// One question the calibration quiz can render. The onboarding flow runs the
/// quiz in two segments around the class reveal:
/// `[trainingWhy, goal, weightSex, winningVision]` before it (the vow opens, the
/// goal derives the class, then body metrics, then the vision lands right before
/// the reveal) and `[experience, frequency, obstacle]` after it (those tune the
/// program build, with the obstacle just before it). `trainingWhy` /
/// `winningVision` / `obstacle` are identity beats, not calibration — captured
/// here for narrative pacing and persisted on the Character.
enum QuizQuestion {
  goal,
  frequency,
  experience,
  weightSex,
  trainingWhy,
  winningVision,
  obstacle,
}

/// Mutable accumulator the quiz fills in as the user answers. The owning flow
/// reads whichever fields a given segment collected.
class QuizAnswers {
  QuizAnswers({
    this.goal,
    this.freq,
    this.exp,
    this.bodyWeightKg,
    this.heightCm,
    this.sex = UserProfileSex.preferNotToSay,
    this.trainingWhy = const <TrainingWhy>{},
    this.winningVision = const <WinningVision>{},
    this.obstacle,
  });

  BodyGoal? goal;
  TrainingFreq? freq;
  Experience? exp;
  double? bodyWeightKg;
  double? heightCm;
  UserProfileSex sex;

  // Identity beats (Resolve questions) — interleaved into the quiz. Vow + vision
  // are multi-select; obstacle is single-select (one barrier BIT responds to).
  Set<TrainingWhy> trainingWhy;
  Set<WinningVision> winningVision;
  Obstacle? obstacle;

  QuizAnswers copy() => QuizAnswers(
    goal: goal,
    freq: freq,
    exp: exp,
    bodyWeightKg: bodyWeightKg,
    heightCm: heightCm,
    sex: sex,
    trainingWhy: {...trainingWhy},
    winningVision: {...winningVision},
    obstacle: obstacle,
  );
}

/// The answers known before the class is revealed: the goal (which derives the
/// class) plus the optional body metrics. The calibration loader + class reveal
/// take this — frequency/experience aren't collected until after the reveal.
class PreClassAnswers {
  const PreClassAnswers({
    required this.goal,
    required this.bodyWeightKg,
    this.heightCm,
    required this.sex,
  });

  final BodyGoal goal;
  final double? bodyWeightKg;
  final double? heightCm;
  final UserProfileSex sex;

  CharacterClass get clazz => deriveClass(goal);
}
