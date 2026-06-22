import '../models/calibration_quiz_models.dart';
import '../models/resolve_models.dart';

/// BIT's interview copy for the calibration quiz — the lines BIT *asks* and the
/// "promise" *reactions* it gives on the emotional questions. Centralized so the
/// companion's voice is editable in one place.
///
/// **Conventions:** no dash "`-`" as a separator (reads AI). Text inside square
/// brackets `[like this]` is rendered **amber + a subtle shake** by
/// `BitSpeechBubble` — keep the brackets in the strings. Body-neutral: a reaction
/// is BIT's voice and the system's promise, never a body/performance grade.
class BitInterviewCopy {
  const BitInterviewCopy._();

  /// BIT opens the post-reveal segment with this before the experience question.
  static const String segmentBIntro = "Now, just a few more questions.";

  /// Shown on the calibrating loader (BIT "picks a path") after segment A.
  static const String pickingPath =
      "Now, hang on a bit while I pick a path that fits you most.";

  /// What BIT asks for [q].
  static String ask(QuizQuestion q) => switch (q) {
    QuizQuestion.trainingWhy => "Before anything, why do you train?",
    QuizQuestion.goal => "So, what are we striving for?",
    QuizQuestion.trainingFocus => "And how do you want to train for it?",
    QuizQuestion.weightSex => "Now the numbers. Crucial for my analysis.",
    QuizQuestion.winningVision => "How do you see yourself in 3 months?",
    QuizQuestion.experience => "How far down this road are you?",
    QuizQuestion.frequency => "How often can you show up?",
    QuizQuestion.obstacle => "Last one. What gets in your way most?",
  };

  // ── VOW (multi-select → highest-priority pick) ────────────────────────────
  static const List<TrainingWhy> vowPriority = [
    TrainingWhy.doneQuitting,
    TrainingWhy.futureSelf,
    TrainingWhy.feelAlive,
    TrainingWhy.clearsHead,
  ];

  static TrainingWhy vowPrimary(Set<TrainingWhy> set) =>
      vowPriority.firstWhere(set.contains, orElse: () => vowPriority.first);

  static String vowReaction(TrainingWhy why) => switch (why) {
    TrainingWhy.doneQuitting =>
      "Noted. We will focus on building your foundation first. Your [determined persistence] will be our precious material.",
    TrainingWhy.futureSelf =>
      "This is the mindset. You will wake up every day [feeling better] than yesterday. You won't recognize yourself in 3 months.",
    TrainingWhy.feelAlive =>
      "Toning oneself is one of the best sources of [self love and confidence]. We will bring those out from within you.",
    TrainingWhy.clearsHead =>
      "Your availability will be my priority. It is about [showing up], not perfection.",
  };

  // ── WINNING VISION (multi-select → highest-priority pick) ─────────────────
  static const List<WinningVision> visionPriority = [
    WinningVision.visiblyStronger,
    WinningVision.stillHere,
    WinningVision.strongCapable,
    WinningVision.clearHeaded,
  ];

  static WinningVision visionPrimary(Set<WinningVision> set) =>
      visionPriority.firstWhere(set.contains, orElse: () => visionPriority.first);

  static String visionReaction(WinningVision v) => switch (v) {
    WinningVision.visiblyStronger =>
      "I will keep track of the data carefully. The numbers only speak the truth, after all.",
    WinningVision.stillHere =>
      "You and I will watch the streak grow over time. You showing up is what matters most.",
    WinningVision.strongCapable =>
      "You keep the wins on your spirit. I'll keep the wins on the board and track the progress.",
    WinningVision.clearHeaded =>
      "I'll help make this journey of ours the most enjoyable and valuable, so that it lasts throughout the rest of your life.",
  };

  // ── EXPERIENCE (single-select; novice vs the rest) ────────────────────────
  static String experienceReaction(Experience exp) => exp == Experience.novice
      ? "Perfect. Let's mark today as the day you [step up] for yourself. It's time to shatter the comfort zone that has been constraining your [full potential]."
      : "Amazing. Then you know the drill. I'll make things simple for us.";

  // ── FREQUENCY (single-select) ─────────────────────────────────────────────
  static String frequencyReaction(TrainingFreq freq) => switch (freq) {
    TrainingFreq.low =>
      "That means you will workout for 58.5h over the next 3 months, that's [7,020 reels] or the entire [Breaking Bad series], 74 episodes, AND the film.",
    TrainingFreq.mid =>
      "That means you will workout for 97.5h over the next 3 months, that's [11,700 Reels] or the entire [Breaking Bad series], TWICE.",
    TrainingFreq.high =>
      "That means you will workout for 117.0h over the next 3 months, that's [11,040 Reels] or the entire [Friends series], 236 episodes, AND rewatch half of it again.",
  };

  // ── OBSTACLE (single-select; `time` interpolates the frequency answer) ────
  static String obstacleReaction(Obstacle o, {TrainingFreq? freq}) =>
      switch (o) {
        Obstacle.missedDay =>
          "Don't worry, it is never about perfection. We will not rely on discipline to craft our lifestyle, but on our will to become a better self every day. You miss? You [come back stronger].",
        Obstacle.boredom =>
          "Did you know people given boring tasks generate up to 61% more creative ideas? I'll make our journey enjoyable, but I'll also help you embrace [the depth of boredom].",
        Obstacle.motivation =>
          "Got it. That will be our main focus. You will see [yourself] become your own source of motivation.",
        Obstacle.time =>
          "${_weeklyHours(freq)} hours. You just need to put [all your mind] into these hours. I'll take care of the rest.",
      };

  static String _weeklyHours(TrainingFreq? freq) => switch (freq) {
    TrainingFreq.low => '3',
    TrainingFreq.mid => '5',
    TrainingFreq.high => '6',
    null => '5',
  };
}
