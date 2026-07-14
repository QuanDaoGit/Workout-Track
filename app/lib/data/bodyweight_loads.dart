/// Fraction of bodyweight actually lifted in common bodyweight movements.
///
/// Replaces the old flat 40 kg proxy: a bodyweight set's load is
/// `bodyweightLoadFraction(name) * bodyweight kg` (per-session snapshot).
/// Anchors: a push-up supports ~65% of bodyweight (force-plate studies);
/// pull-ups/chin-ups/dips/squats move the full bodyweight (ExRx "calculating
/// actual resistance"); lunges/step-ups carry most of it. Matching is by
/// exercise name so built-in and custom exercises both resolve; anything
/// unrecognized uses the push-up fraction as a conservative default.
///
/// Applies only to sets logged with `weight == 0`. Weighted sets always use
/// the logged weight (added load on weighted pull-ups/dips is intentionally
/// not summed with bodyweight — same treatment as strength standards that
/// count added load only, and it keeps weighted logging unambiguous).
library;

const double kDefaultBodyweightLoadFraction = 0.65;

double bodyweightLoadFraction(String exerciseName) {
  final name = exerciseName.toLowerCase();
  bool has(List<String> patterns) => patterns.any(name.contains);

  // Full-bodyweight movements.
  if (has(const [
    'pull-up',
    'pullup',
    'pull up',
    'chin-up',
    'chinup',
    'chin up',
    'muscle-up',
    'muscle up',
    'dip',
    'pistol',
    'rope climb',
  ])) {
    return 1.0;
  }
  // Squat pattern: when logged at weight 0 it is a bodyweight squat variant.
  if (has(const ['squat', 'box jump', 'jump'])) return 1.0;
  // Most of bodyweight on one leg / split stance.
  if (has(const ['lunge', 'step-up', 'step up'])) return 0.85;
  // Horizontal pulls hold roughly half to two-thirds; keep at default tier.
  return kDefaultBodyweightLoadFraction;
}
