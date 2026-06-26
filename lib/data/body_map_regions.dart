import 'dart:math';

import '../models/workout_models.dart';
import '../services/muscle_coverage_service.dart';
import '../services/strength_trend_service.dart';
import 'muscle_splits.dart';

/// Pure model for the muscle-coverage body map: the detailed muscles it renders,
/// how the [MuscleCoverageService.weeklySetsByMuscle] output maps onto them, the
/// mask file each side paints, and the brightness ramp — all ported verbatim from
/// the design handoff (`Body Map.dc.html`). No Flutter, no assets, no I/O →
/// trivially unit-testable (the widget consumes this).
///
/// **Coarse contract (Codex F1):** an un-curated `shoulders` / `abdominals` token
/// folds into the **dominant** region only — `shoulders` → front delt (most
/// un-curated shoulder work is pressing = anterior), `abdominals` → rectus
/// (flexion is the default). Rear delt / obliques light **only** from the curated
/// split layer — earned by real posterior/rotation work, never guessed.

enum BodyMapGroup { shouldersArms, chestCore, back, legs }

enum BodySide { front, back }

enum BodyZone { rest, building, optimal, high }

/// The lookback the body map reads over. `week` is the raw last-7-days count
/// (the shipped default); the longer presets show the **weekly average** over a
/// rolling window — lengths chosen to match periodization units (a ~4-week
/// hypertrophy mesocycle / deload cycle, a ~12-week training block), not
/// borrowed physiology. One consistent **rolling** time model — never calendar
/// weeks — so the cutoff, the divisor, and the copy all agree.
enum CoverageWindow { week, fourWeek, twelveWeek }

extension CoverageWindowX on CoverageWindow {
  /// Rolling lookback this preset reads over.
  Duration get window => switch (this) {
    CoverageWindow.week => const Duration(days: 7),
    CoverageWindow.fourWeek => const Duration(days: 28),
    CoverageWindow.twelveWeek => const Duration(days: 84),
  };

  /// The longer presets divide by their week count → a weekly **average**; the
  /// 7-day preset is a raw count (divide by 1).
  bool get isAverage => this != CoverageWindow.week;

  /// Selector chip label — the longer ones carry `AVG` so the model is legible
  /// (raw 7-day vs averaged) before the user even reads the caption.
  String get chipLabel => switch (this) {
    CoverageWindow.week => '7-DAY',
    CoverageWindow.fourWeek => '4-WK AVG',
    CoverageWindow.twelveWeek => '12-WK AVG',
  };
}

class BodyMuscle {
  const BodyMuscle({
    required this.id,
    required this.label,
    required this.group,
    required this.mev,
    required this.mav,
    required this.sourceKeys,
    this.coarseKey,
  });

  /// Stable id — also the mask→muscle target and the meter-row key.
  final String id;
  final String label;
  final BodyMapGroup group;

  /// Weekly-set landmarks (per the handoff's per-region table).
  final int mev;
  final int mav;

  /// Analyzer keys summed into this muscle (a muscle can gather several detailed
  /// tokens that share no dedicated mask, e.g. traps ← traps + middle back + neck).
  final List<String> sourceKeys;

  /// A coarse generic token folded in **fully** when present (the F1 dominant
  /// fold). Only front_delt and rectus carry one.
  final String? coarseKey;
}

/// The 16 detailed muscles the map distinguishes (meter rows, grouped).
const List<BodyMuscle> bodyMuscles = [
  // ── Shoulders · Arms ──
  BodyMuscle(id: 'front_delt', label: 'FRONT DELT', group: BodyMapGroup.shouldersArms, mev: 8, mav: 18, sourceKeys: ['front_delt'], coarseKey: 'shoulders'),
  BodyMuscle(id: 'rear_delt', label: 'REAR DELT', group: BodyMapGroup.shouldersArms, mev: 8, mav: 18, sourceKeys: ['rear_delt']),
  BodyMuscle(id: 'biceps', label: 'BICEPS', group: BodyMapGroup.shouldersArms, mev: 8, mav: 18, sourceKeys: ['biceps']),
  BodyMuscle(id: 'triceps', label: 'TRICEPS', group: BodyMapGroup.shouldersArms, mev: 8, mav: 18, sourceKeys: ['triceps']),
  BodyMuscle(id: 'forearms', label: 'FOREARMS', group: BodyMapGroup.shouldersArms, mev: 8, mav: 18, sourceKeys: ['forearms']),
  // ── Chest · Core ──
  BodyMuscle(id: 'chest', label: 'CHEST', group: BodyMapGroup.chestCore, mev: 10, mav: 20, sourceKeys: ['chest']),
  BodyMuscle(id: 'rectus', label: 'ABS', group: BodyMapGroup.chestCore, mev: 6, mav: 16, sourceKeys: ['rectus_abdominis'], coarseKey: 'abdominals'),
  BodyMuscle(id: 'obliques', label: 'OBLIQUES', group: BodyMapGroup.chestCore, mev: 6, mav: 16, sourceKeys: ['obliques']),
  // ── Back ──
  BodyMuscle(id: 'traps', label: 'TRAPS', group: BodyMapGroup.back, mev: 10, mav: 20, sourceKeys: ['traps', 'middle back', 'neck']),
  BodyMuscle(id: 'lats', label: 'LATS', group: BodyMapGroup.back, mev: 10, mav: 20, sourceKeys: ['lats']),
  BodyMuscle(id: 'lower_back', label: 'LOWER BACK', group: BodyMapGroup.back, mev: 10, mav: 20, sourceKeys: ['lower back']),
  // ── Legs ──
  BodyMuscle(id: 'quads', label: 'QUADS', group: BodyMapGroup.legs, mev: 8, mav: 18, sourceKeys: ['quadriceps']),
  BodyMuscle(id: 'hamstrings', label: 'HAMSTRINGS', group: BodyMapGroup.legs, mev: 8, mav: 18, sourceKeys: ['hamstrings']),
  BodyMuscle(id: 'glutes', label: 'GLUTES', group: BodyMapGroup.legs, mev: 8, mav: 18, sourceKeys: ['glutes']),
  BodyMuscle(id: 'calves', label: 'CALVES', group: BodyMapGroup.legs, mev: 8, mav: 18, sourceKeys: ['calves']),
  BodyMuscle(id: 'adductors', label: 'ADDUCTORS', group: BodyMapGroup.legs, mev: 8, mav: 18, sourceKeys: ['adductors', 'abductors']),
];

/// Mask file stem (under `assets/body_diagram/render/<side>/`) → muscle id, per
/// side. `forearms` and `calves` paint on **both** sides (visible front and back),
/// driven by the same muscle value — not a double-count (one side renders at a time).
const Map<String, String> frontMaskMuscle = {
  'delts': 'front_delt',
  'biceps': 'biceps',
  'forearms': 'forearms',
  'chest': 'chest',
  'abs': 'rectus',
  'obliques': 'obliques',
  'quads': 'quads',
  'adductors': 'adductors',
  'calves': 'calves',
};

const Map<String, String> backMaskMuscle = {
  'rear_delts': 'rear_delt',
  'triceps': 'triceps',
  'forearms': 'forearms',
  'traps': 'traps',
  'lats': 'lats',
  'lower_back': 'lower_back',
  'glutes': 'glutes',
  'hamstrings': 'hamstrings',
  'calves': 'calves',
};

final Map<String, BodyMuscle> _muscleById = {
  for (final m in bodyMuscles) m.id: m,
};

BodyMuscle muscleById(String id) => _muscleById[id]!;

/// Roll the analyzer's per-detailed-muscle output up into the body map's muscles
/// (sums each muscle's [BodyMuscle.sourceKeys] + its full coarse fold).
Map<String, double> bodyMuscleValues(Map<String, double> coverage) {
  final out = <String, double>{};
  for (final m in bodyMuscles) {
    var v = 0.0;
    for (final key in m.sourceKeys) {
      v += coverage[key] ?? 0.0;
    }
    if (m.coarseKey != null) v += coverage[m.coarseKey!] ?? 0.0;
    out[m.id] = v;
  }
  return out;
}

/// Zone for a weekly-set count against a muscle's landmarks (handoff `zoneOf`).
BodyZone zoneFor(double sets, int mev, int mav) {
  if (sets <= 0) return BodyZone.rest;
  if (sets < mev) return BodyZone.building;
  if (sets <= mav) return BodyZone.optimal;
  return BodyZone.high;
}

/// Mask opacity for a weekly-set count (handoff `opacityOf`): 0 at rest; a dim
/// building band; a rise to full across MEV→MAV; capped at MAV (no brighter for
/// over-volume). Monotonic non-decreasing in [sets].
double maskOpacityFor(double sets, int mev, int mav) {
  if (sets <= 0) return 0.0;
  if (sets < mev) return 0.18 + 0.26 * (sets / mev);
  if (sets <= mav) {
    return 0.78 + 0.22 * ((sets - mev) / max(1, mav - mev));
  }
  return 1.0;
}

/// A display muscle's total weekly sets **and** the exercises that fed it — both
/// from the *same* sourceKeys+coarse-fold path, so the meter bar and the drill
/// sheet can never disagree (Codex F2). [total] == the sum of [contributors].
class MuscleBreakdown {
  const MuscleBreakdown({required this.total, required this.contributors});
  final double total;
  final List<MuscleContributor> contributors;
}

/// Roll the per-detailed-key contributors ([MuscleCoverageService.weeklyContributors])
/// up into the body map's display muscles. Each muscle gathers its
/// [BodyMuscle.sourceKeys] + its coarse fold, merges an exercise that hits
/// several of those keys (summing its credited sets), and sorts by sets desc.
/// `front_delt` thus collects un-curated `shoulders` work; `rear_delt` does not.
Map<String, MuscleBreakdown> muscleBreakdown(
  Map<String, List<MuscleContributor>> byKey,
) {
  final out = <String, MuscleBreakdown>{};
  for (final m in bodyMuscles) {
    final merged = <String, MuscleContributor>{};
    final keys = [...m.sourceKeys, if (m.coarseKey != null) m.coarseKey!];
    for (final key in keys) {
      for (final c in byKey[key] ?? const <MuscleContributor>[]) {
        final existing = merged[c.exerciseId];
        merged[c.exerciseId] = MuscleContributor(
          exerciseId: c.exerciseId,
          exerciseName: c.exerciseName,
          sets: (existing?.sets ?? 0) + c.sets,
        );
      }
    }
    final contributors = merged.values.toList()
      ..sort((a, b) => b.sets.compareTo(a.sets));
    final total = contributors.fold<double>(0, (s, c) => s + c.sets);
    out[m.id] = MuscleBreakdown(total: total, contributors: contributors);
  }
  return out;
}

/// Detailed-muscle token → the display muscle that owns it (sourceKeys + the
/// coarse fold). The reverse of [bodyMuscles]; used to file a lift under a body
/// muscle for the strength roster.
final Map<String, String> _detailedToBodyMuscle = {
  for (final m in bodyMuscles) ...{
    for (final key in m.sourceKeys) key: m.id,
    if (m.coarseKey != null) m.coarseKey!: m.id,
  },
};

/// Group strength trends under the body map's muscles for the "tap a muscle →
/// its lifts' momentum" dossier (Concept #1, the body is the browser).
///
/// Files each lift under its **PRIMARY** muscle only (its anatomical home) — not
/// every muscle it touches — so a bench doesn't clutter the triceps/front-delt
/// rosters with a lift the user thinks of as "chest" (Codex). This is a
/// deliberately *different* grouping from coverage (which credits every
/// synergist, fractionally, for the "did I train it this week" meter): the
/// roster answers "my lifts for this muscle", coverage answers "what worked it".
/// Trends arrive recency-sorted; that order is preserved per muscle.
Map<String, List<StrengthTrend>> strengthByMuscle(
  List<StrengthTrend> trends,
  Map<String, Exercise> exercisesById,
) {
  final out = <String, List<StrengthTrend>>{};
  for (final trend in trends) {
    final exercise = exercisesById[trend.exerciseId];
    final primary = exercise?.primaryMuscle;
    if (primary == null) continue; // can't file a deleted/primary-less lift
    // Dominant sub-region (curated split) → the owning body muscle.
    final dominant = splitDetailedMuscle(exercise!.id, primary).first;
    final muscleId = _detailedToBodyMuscle[dominant];
    if (muscleId == null) continue; // primary maps to no mapped muscle
    out.putIfAbsent(muscleId, () => []).add(trend);
  }
  return out;
}
