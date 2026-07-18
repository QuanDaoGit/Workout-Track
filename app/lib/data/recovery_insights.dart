/// BIT's rest-day recovery briefings. One insight surfaces per rest day on the
/// Home recovery mission cards (RECOVERY BRIEFING button), rotated by
/// [RecoveryInsightService] so a user sees each once before the pool wraps.
///
/// Content rules (enforced in part by recovery_insights_content_test.dart):
/// accurate mainstream recovery science, body-neutral (no weight/calorie
/// framing), BIT's voice (short, warm, a little wry), never a training nudge
/// and never guilt. 1-3 sentences.
///
/// Review checklist for every new/edited line (Codex F7 — the test can only
/// catch markers, a human catches meaning):
/// - No universal medical claims ("X cures/prevents Y"); describe, don't
///   prescribe (no "you should/must" — mechanically banned).
/// - No supplement recommendations; conditional framing only (see
///   `creatine_everyday`: "If you take creatine...").
/// - Hedge mixed-evidence topics explicitly (see `foam_rolling`: "the
///   science is mixed on why").
/// - Body-neutral: no body-composition, appearance, or weight framing.
class RecoveryInsight {
  const RecoveryInsight({
    required this.id,
    required this.category,
    required this.text,
  });

  /// Stable snake_case identity; the seen-set persists these.
  final String id;

  /// One of [kRecoveryInsightCategories]; drives the sheet's category icon.
  final String category;

  /// The BIT-voiced insight line(s).
  final String text;
}

/// The allowed category tags and each one's pixel icon (existing
/// `assets/icons/control/` art, tinted at render; `icon_bed.png` was
/// extracted from the bed-frame sheet in `design/icons/`).
const kRecoveryInsightCategories = ['sleep', 'fuel', 'adaptation', 'mobility', 'mind'];

const Map<String, String> kRecoveryInsightCategoryIcons = {
  'sleep': 'assets/icons/control/icon_bed.png',
  'fuel': 'assets/icons/control/icon_meat.png',
  'adaptation': 'assets/icons/control/icon_stat.png',
  'mobility': 'assets/icons/control/icon_boots.png',
  'mind': 'assets/icons/control/icon_brain.png',
};

const List<RecoveryInsight> recoveryInsights = [
  // -- adaptation: what rest actually does ---------------------------------
  RecoveryInsight(
    id: 'rest_is_recovery',
    category: 'adaptation',
    text:
        'Training breaks you down. Rest is when the recovery happens.',
  ),
  RecoveryInsight(
    id: 'doms_is_adaptation',
    category: 'adaptation',
    text:
        "Sore two days after a session? That's DOMS, delayed onset muscle soreness. It's adaptation working, not damage.",
  ),
  RecoveryInsight(
    id: 'supercompensation',
    category: 'adaptation',
    text:
        'Muscle grows back slightly stronger than before. Scientists call it supercompensation. I call it leveling up.',
  ),
  RecoveryInsight(
    id: 'nervous_system_rest',
    category: 'adaptation',
    text:
        'Rest repairs more than muscle. Your nervous system recovers too, and it controls how hard you can push next time.',
  ),
  RecoveryInsight(
    id: 'tendons_slower',
    category: 'adaptation',
    text:
        'Tendons adapt slower than muscles. Rest days give the connectors time to catch up with the engine.',
  ),
  RecoveryInsight(
    id: 'immune_boost',
    category: 'adaptation',
    text:
        'Hard training briefly dips your immune defenses. Recovery days are when they climb back stronger.',
  ),
  RecoveryInsight(
    id: 'deload_science',
    category: 'adaptation',
    text:
        'Even elite lifters schedule easy weeks. Backing off on purpose is a strategy, not a setback.',
  ),
  RecoveryInsight(
    id: 'growth_between',
    category: 'adaptation',
    text:
        'The gym sends the signal to your muscle. The actual growth happens when you rest properly. Make the most of your rest.',
  ),
  // -- sleep ----------------------------------------------------------------
  RecoveryInsight(
    id: 'sleep_growth_window',
    category: 'sleep',
    text:
        "Most muscle repair runs during deep sleep. Tonight's sleep is part of the program.",
  ),
  RecoveryInsight(
    id: 'growth_hormone_sleep',
    category: 'sleep',
    text:
        'Your body releases most of its growth hormone in the first hours of deep sleep. Absolutely free gains.',
  ),
  RecoveryInsight(
    id: 'sleep_strength_link',
    category: 'sleep',
    text:
        'Short sleep measurably drops next-day strength and focus. A full night is quiet training.',
  ),
  RecoveryInsight(
    id: 'consistent_schedule',
    category: 'sleep',
    text:
        'A steady sleep schedule beats occasional long nights. Your recovery systems love a routine.',
  ),
  RecoveryInsight(
    id: 'screens_before_bed',
    category: 'sleep',
    text:
        'Bright screens late push your sleep clock back. Dimming things an hour before bed helps the repair shift start on time.',
  ),
  RecoveryInsight(
    id: 'naps_count',
    category: 'sleep',
    text: 'A 20-minute nap genuinely helps recovery.',
  ),
  RecoveryInsight(
    id: 'sleep_debt',
    category: 'sleep',
    text:
        "One rough night won't undo your work. Sleep pressure builds and your body catches up. Just don't make it a habit.",
  ),
  // -- fuel -----------------------------------------------------------------
  RecoveryInsight(
    id: 'protein_rest_days',
    category: 'fuel',
    text: 'Protein still matters on rest days. The recovery still needs fuel.',
  ),
  RecoveryInsight(
    id: 'protein_spread',
    category: 'fuel',
    text:
        'Spreading protein across the day works better than one giant serving. Your muscle loves steady deliveries.',
  ),
  RecoveryInsight(
    id: 'hydration_repair',
    category: 'fuel',
    text:
        'Muscle tissue is mostly water. Staying hydrated today literally supplies the repair work.',
  ),
  RecoveryInsight(
    id: 'carbs_refill',
    category: 'fuel',
    text:
        'Carbs on rest days refill the fuel tanks your last session emptied. Glycogen restocks over about a day.',
  ),
  RecoveryInsight(
    id: 'no_perfect_meal',
    category: 'fuel',
    text:
        "There's no magic recovery meal. Regular food, enough protein, enough water. Just same old works.",
  ),
  RecoveryInsight(
    id: 'creatine_everyday',
    category: 'fuel',
    text:
        'If you take creatine, rest days count too. It works by staying topped up, not by timing.',
  ),
  RecoveryInsight(
    id: 'alcohol_repair',
    category: 'fuel',
    text:
        'Alcohol slows muscle repair and shallows your sleep. A light hand tonight keeps the recovery on schedule.',
  ),
  // -- mobility & light movement -------------------------------------------
  RecoveryInsight(
    id: 'walk_bloodflow',
    category: 'mobility',
    text:
        'A short walk today speeds recovery. Blood flow carries the repair supplies.',
  ),
  RecoveryInsight(
    id: 'active_vs_couch',
    category: 'mobility',
    text:
        'Gentle movement on rest days often beats full couch mode. Staying active is the key.',
  ),
  RecoveryInsight(
    id: 'stretching_when',
    category: 'mobility',
    text:
        'Great time for some relaxed stretching. No time and target, just you and your mind.',
  ),
  RecoveryInsight(
    id: 'stiffness_morning',
    category: 'mobility',
    text:
        'Morning stiffness after training is normal. Joints wake up with movement, like old machines warming up.',
  ),
  RecoveryInsight(
    id: 'posture_breaks',
    category: 'mobility',
    text:
        'Sitting all day makes recovery feel worse than it is. Standing up every hour keeps things flowing.',
  ),
  RecoveryInsight(
    id: 'easy_cardio_ok',
    category: 'mobility',
    text:
        'An easy bike ride or swim can aid recovery, as long as it stays at conversational pace. Pushing yourself too hard may inhibit recovery.',
  ),
  RecoveryInsight(
    id: 'foam_rolling',
    category: 'mobility',
    text:
        'Foam rolling may ease soreness for a while. The science is mixed on why, but if it feels good, it works.',
  ),
  // -- mind -----------------------------------------------------------------
  RecoveryInsight(
    id: 'rest_is_training',
    category: 'mind',
    text:
        "Recovery isn't the absence of training. It's the half of training you can't see.",
  ),
  RecoveryInsight(
    id: 'stress_budget',
    category: 'mind',
    text:
        'Your body has one stress budget. Life stress and training stress draw from the same account. Rest days pay it back.',
  ),
  RecoveryInsight(
    id: 'boredom_normal',
    category: 'mind',
    text:
        'Feeling restless on a rest day is a good sign. It means the habit is forming.',
  ),
  RecoveryInsight(
    id: 'long_game',
    category: 'mind',
    text:
        'Nobody is built in a week. Everyone is built in months. Rest days are how months happen.',
  ),
  RecoveryInsight(
    id: 'sleep_mood_link',
    category: 'mind',
    text:
        'Recovery lifts mood as much as muscle. A rested brain enjoys the next session more.',
  ),
  RecoveryInsight(
    id: 'breathing_switch',
    category: 'mind',
    text:
        'A few slow breaths flip your nervous system into repair mode. Inhale deeply, exhale slowly.',
  ),
];
