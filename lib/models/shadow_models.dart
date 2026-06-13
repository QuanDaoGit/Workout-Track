/// Models for "The Shadow" — the nemesis built from the user's own steady
/// training. The Shadow is a *live mirror*: every evaluation recomputes it
/// from session history (acute window vs chronic baseline). Only three things
/// persist across evaluations: the per-axis chronic high-water (anti
/// under-training floor), the week-over-week mean ratio (gap-closing signal),
/// and the one-time defeat/title marker.
library;

/// Overall Shadow surface state, in display precedence order.
enum ShadowStatus {
  /// Fewer than the minimum completed sessions — teaser only
  /// ("Something is forming.").
  locked,

  /// Enough sessions overall but the chronic window can't support a baseline
  /// yet (or no axis clears the sufficiency floor).
  forming,

  /// Live contest: at least one sufficient axis, not currently defeated.
  contest,

  /// Every sufficient axis held at full strength — the Shadow is defeated.
  defeated,

  /// The chronic baseline has decayed well below its high-water: the Shadow
  /// has faded. Out-pacing a faded Shadow reads as rebuilding and never
  /// awards the title (anti under-training rule).
  faded,
}

/// Per-axis contest state.
enum ShadowAxisState {
  /// Acute pace matches or exceeds the chronic baseline (r >= ahead
  /// threshold).
  ahead,

  /// Neck-and-neck band — within normal week-to-week quantization noise.
  close,

  /// Shadow leads: recent pace genuinely below the month baseline.
  behind,

  /// Axis has no scoreable chronic baseline — never scored as a loss.
  forming,
}

/// One axis of the dual radar: state + acute:chronic ratio + the reason the
/// Shadow leads (only set when [state] is [ShadowAxisState.behind]).
class ShadowAxisRead {
  const ShadowAxisRead({
    required this.axis,
    required this.state,
    this.ratio,
    this.reason,
  });

  final String axis;
  final ShadowAxisState state;

  /// Acute rate / chronic rate. Null when the axis is forming.
  final double? ratio;

  /// Plain-language driver for a behind axis (legibility rule: the Shadow must
  /// never feel arbitrary).
  final String? reason;
}

/// The result of one Shadow evaluation — everything the Home callout and the
/// Guild detail view need. Pure value object; owning service does the math.
class ShadowEvaluation {
  const ShadowEvaluation({
    required this.status,
    required this.completedSessions,
    this.axes = const [],
    this.provisional = false,
    this.gapClosing = false,
    this.titleEarnedNow = false,
    this.titleEarned = false,
    this.headline,
  });

  final ShadowStatus status;
  final int completedSessions;
  final List<ShadowAxisRead> axes;

  /// True while the Shadow is live but the baseline is still young
  /// (sessions < maturity bar). Labeled "forming — experimental"; defeat in
  /// this phase never awards the permanent title.
  final bool provisional;

  /// Behind overall, but this week's mean ratio improved on last week's —
  /// surfaced as encouragement, never as "you lost".
  final bool gapClosing;

  /// The permanent title + frame were granted during *this* evaluation.
  final bool titleEarnedNow;

  /// The permanent title has been earned (now or previously).
  final bool titleEarned;

  /// One-line driver for the weakest behind axis, e.g.
  /// "SHADOW LEADS END — STAMINA PACE BELOW YOUR MONTH". Null when nothing is
  /// behind.
  final String? headline;
}

/// Persisted Shadow state (`shadow_state_v1`). Decode is defensive per-field:
/// malformed or missing values fall back to an empty state ("forming"), and a
/// decode failure can never touch real stats or XP.
class ShadowState {
  ShadowState({
    this.version = currentVersion,
    this.lastEvalWeekIso,
    this.lastWeekMeanRatio,
    this.currentWeekMeanRatio,
    Map<String, double>? highWater,
    Map<String, String>? highWaterSetAtIso,
    this.firstDefeatAtIso,
    this.lastDefeatWeekIso,
  }) : highWater = highWater ?? {},
       highWaterSetAtIso = highWaterSetAtIso ?? {};

  static const currentVersion = 1;

  final int version;

  /// ISO week of the most recent evaluation (gap-closing rollover anchor).
  final String? lastEvalWeekIso;

  /// Mean sufficient-axis ratio frozen at the last week rollover.
  final double? lastWeekMeanRatio;

  /// Latest mean sufficient-axis ratio observed within the current week.
  final double? currentWeekMeanRatio;

  /// Per-axis chronic-rate high-water — the anti under-training floor. Decays
  /// gently per week (see service) so the distant past is forgiven, but a
  /// recently rested-away baseline still blocks the reward.
  final Map<String, double> highWater;

  /// Per-axis ISO date the high-water was last raised (decay anchor).
  final Map<String, String> highWaterSetAtIso;

  /// Set once, on the first genuine (mature, non-faded) defeat — the
  /// permanent title/frame grant marker. Never cleared.
  final String? firstDefeatAtIso;

  /// ISO week of the most recent genuine defeat.
  final String? lastDefeatWeekIso;

  Map<String, dynamic> toJson() => {
    'version': version,
    'lastEvalWeekIso': lastEvalWeekIso,
    'lastWeekMeanRatio': lastWeekMeanRatio,
    'currentWeekMeanRatio': currentWeekMeanRatio,
    'highWater': highWater,
    'highWaterSetAtIso': highWaterSetAtIso,
    'firstDefeatAtIso': firstDefeatAtIso,
    'lastDefeatWeekIso': lastDefeatWeekIso,
  };

  /// Defensive decode: any malformed field falls back individually; a null or
  /// non-map payload yields a fresh empty state.
  factory ShadowState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ShadowState();
    double? asDouble(dynamic v) => v is num ? v.toDouble() : null;
    String? asString(dynamic v) => v is String ? v : null;
    Map<String, double> doubleMap(dynamic v) {
      if (v is! Map) return {};
      return {
        for (final e in v.entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toDouble(),
      };
    }

    Map<String, String> stringMap(dynamic v) {
      if (v is! Map) return {};
      return {
        for (final e in v.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    }

    return ShadowState(
      version: (json['version'] is num)
          ? (json['version'] as num).toInt()
          : currentVersion,
      lastEvalWeekIso: asString(json['lastEvalWeekIso']),
      lastWeekMeanRatio: asDouble(json['lastWeekMeanRatio']),
      currentWeekMeanRatio: asDouble(json['currentWeekMeanRatio']),
      highWater: doubleMap(json['highWater']),
      highWaterSetAtIso: stringMap(json['highWaterSetAtIso']),
      firstDefeatAtIso: asString(json['firstDefeatAtIso']),
      lastDefeatWeekIso: asString(json['lastDefeatWeekIso']),
    );
  }
}
