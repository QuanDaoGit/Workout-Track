/// Maps a logged exercise NAME to one of the movement-pattern lift icons in
/// `assets/icons/lift-icons/`. Name-keyword based (no catalog dependency) so it
/// also works for custom / renamed / since-deleted exercises — a **directional
/// visual identity**, not a precise classification. Unmatched lifts fall back to
/// the generic barbell. Order matters: more specific patterns are checked first
/// (e.g. "leg press" → squat before the generic "press" rule; "leg curl" → hinge
/// before the "curl" rule; "overhead press" → overhead_press before "press").
library;

const String _liftIconDir = 'assets/icons/lift-icons';

/// The 13 movement-pattern icon keys (filenames, sans extension).
const List<String> kLiftIconKeys = [
  'press',
  'overhead_press',
  'hinge',
  'squat',
  'lunge',
  'row',
  'pulldown',
  'curl',
  'pushdown',
  'lateral_raise',
  'core',
  'calf',
  'generic',
];

/// The icon **key** (filename sans extension) for [exerciseName].
String liftIconKeyFor(String exerciseName) {
  final n = exerciseName.toLowerCase();
  bool has(String s) => n.contains(s);

  if (has('calf')) return 'calf';

  // Core / trunk.
  if (has('crunch') ||
      has('sit-up') ||
      has('situp') ||
      has('plank') ||
      has('leg raise') ||
      has('knee raise') ||
      has('oblique') ||
      has('russian twist') ||
      has('woodchop') ||
      has('rollout') ||
      has('ab wheel') ||
      has('dead bug') ||
      has('hanging') ||
      has('pallof')) {
    return 'core';
  }

  // Triceps (elbow extension).
  if (has('pushdown') ||
      has('tricep') ||
      has('skullcrusher') ||
      has('skull crusher') ||
      has('kickback') ||
      has('overhead extension') ||
      has('french press')) {
    return 'pushdown';
  }

  // Hamstrings / posterior chain (hinge) — incl. "leg curl", before the curl rule.
  if (has('deadlift') ||
      has('rdl') ||
      has('romanian') ||
      has('good morning') ||
      has('hip thrust') ||
      has('glute bridge') ||
      has('hyperextension') ||
      has('back extension') ||
      has('leg curl') ||
      has('hamstring') ||
      has('hinge')) {
    return 'hinge';
  }

  // Biceps curl.
  if (has('curl')) return 'curl';

  // Shoulder raises / rear delt.
  if (has('lateral raise') ||
      has('side raise') ||
      has('front raise') ||
      has('rear delt') ||
      has('reverse fly') ||
      has('reverse pec') ||
      has('lateral') ||
      has('delt fly')) {
    return 'lateral_raise';
  }

  // Single-leg.
  if (has('lunge') ||
      has('split squat') ||
      has('step up') ||
      has('step-up') ||
      has('bulgarian')) {
    return 'lunge';
  }

  // Knee-dominant.
  if (has('squat') ||
      has('leg press') ||
      has('hack') ||
      has('leg extension')) {
    return 'squat';
  }

  // Vertical pull.
  if (has('pulldown') ||
      has('pull-up') ||
      has('pull up') ||
      has('pullup') ||
      has('chin-up') ||
      has('chin up') ||
      has('chinup') ||
      has('lat pull')) {
    return 'pulldown';
  }

  // Horizontal pull.
  if (has('row') || has('face pull')) return 'row';

  // Vertical push.
  if (has('overhead press') ||
      has('shoulder press') ||
      has('military') ||
      has('arnold') ||
      has('ohp') ||
      has('push press')) {
    return 'overhead_press';
  }

  // Horizontal push.
  if (has('bench') ||
      has('press') ||
      has('push-up') ||
      has('pushup') ||
      has('push up') ||
      has('chest fly') ||
      has('pec deck') ||
      has('dip')) {
    return 'press';
  }

  return 'generic';
}

/// The asset path for [exerciseName]'s lift icon.
String liftIconAssetFor(String exerciseName) =>
    '$_liftIconDir/${liftIconKeyFor(exerciseName)}.png';
