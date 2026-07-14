/// The user's training goal, captured once in onboarding (after the body-goal
/// question). It **seeds the cold-start** rep target — the suggested reps used
/// while an exercise has too little history to anchor from — replacing the
/// generic per-kind default (8/12/15). Once ≥2 sessions of history exist, the
/// history-anchored engine (kind-banded) takes over; the focus does NOT clamp or
/// override real history (that would re-introduce phantom deloads / runaway load
/// for anyone whose training diverges from their stated goal — Codex plan F1/F2).
/// A null focus (legacy users, or unset) = exactly the pre-feature behavior.
enum TrainingFocus {
  strength,
  muscle,
  endurance;

  /// Cold-start aim reps this goal seeds (the sparse-history fallback target).
  int get defaultReps => switch (this) {
    TrainingFocus.strength => 5,
    TrainingFocus.muscle => 8,
    TrainingFocus.endurance => 15,
  };

  /// Option-card title (PressStart2P, matches the goal question's options).
  String get title => switch (this) {
    TrainingFocus.strength => 'STRENGTH',
    TrainingFocus.muscle => 'BUILD MUSCLE',
    TrainingFocus.endurance => 'ENDURANCE',
  };

  /// Muted second line on the option card.
  String get subtext => switch (this) {
    TrainingFocus.strength => 'heavy lifts. low reps.',
    TrainingFocus.muscle => 'build size. recommended.',
    TrainingFocus.endurance => 'stamina. high reps.',
  };

  /// Pixel-art leading glyph for the option card.
  String get assetIcon => switch (this) {
    TrainingFocus.strength => 'assets/icons/control/ui/strength-barbell.png',
    TrainingFocus.muscle => 'assets/icons/control/ui/muscle-swell.png',
    TrainingFocus.endurance => 'assets/icons/control/ui/endurance-pulse.png',
  };

  /// Decodes a persisted name; null (unknown/unset) means "no focus" → the
  /// engine falls back to the kind default (legacy behavior).
  static TrainingFocus? fromName(String? raw) {
    for (final value in TrainingFocus.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
