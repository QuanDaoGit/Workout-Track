/// Curated split overrides for the two free-exercise-db muscle tokens that lack
/// the head granularity the body map needs:
///
///   'shoulders'  → [muscleFrontDelt] (anterior + lateral — the front cap mask)
///                  and/or [muscleRearDelt] (posterior — the rear-delt mask)
///   'abdominals' → [muscleRectusAbdominis] (the abs mask) and/or [muscleObliques]
///
/// Classification follows the EMG-grounded movement-pattern rule (see the
/// 2026-06-25 "Detailed per-muscle attribution" entry in research/insights.md):
///   press / front-raise / lateral-raise / overhead / pressing-brace → front_delt
///   row / pulldown / reverse-fly / face-pull / high-pull             → rear_delt
///   spinal flexion (crunch / sit-up / leg-raise / plank / rollout)   → rectus
///   rotation / anti-rotation / lateral-flexion (twist / bicycle)     → obliques (+ rectus)
///
/// **Scope:** curated / common lifts only. Any exercise NOT listed here keeps the
/// generic token (a COARSE fallback) — the long tail is never guessed. This feeds
/// **display / coverage analysis only**: no XP / stat / overload path reads it.
library;

const String muscleFrontDelt = 'front_delt';
const String muscleRearDelt = 'rear_delt';
const String muscleRectusAbdominis = 'rectus_abdominis';
const String muscleObliques = 'obliques';

/// The only valid outputs of a split — used by the data-integrity test.
const Set<String> kSplitSubMuscles = {
  muscleFrontDelt,
  muscleRearDelt,
  muscleRectusAbdominis,
  muscleObliques,
};

/// The only tokens a split applies to.
const Set<String> kSplittableTokens = {'shoulders', 'abdominals'};

/// Exercise id → { generic token → resolved detailed sub-region(s) }.
const Map<String, Map<String, List<String>>> curatedMuscleSplits = {
  // ── Shoulders → FRONT cap (presses, flyes, pullovers, overhead, braces) ──
  'Barbell_Bench_Press_-_Medium_Grip': {'shoulders': [muscleFrontDelt]},
  'Barbell_Incline_Bench_Press_-_Medium_Grip': {'shoulders': [muscleFrontDelt]},
  'Dumbbell_Bench_Press': {'shoulders': [muscleFrontDelt]},
  'Incline_Dumbbell_Press': {'shoulders': [muscleFrontDelt]},
  'Incline_Dumbbell_Flyes': {'shoulders': [muscleFrontDelt]},
  'Cable_Crossover': {'shoulders': [muscleFrontDelt]},
  'Cable_Chest_Press': {'shoulders': [muscleFrontDelt]},
  'Machine_Bench_Press': {'shoulders': [muscleFrontDelt]},
  'Leverage_Chest_Press': {'shoulders': [muscleFrontDelt]},
  'Smith_Machine_Bench_Press': {'shoulders': [muscleFrontDelt]},
  'Wide-Grip_Barbell_Bench_Press': {'shoulders': [muscleFrontDelt]},
  'Incline_Cable_Flye': {'shoulders': [muscleFrontDelt]},
  'Bent-Arm_Dumbbell_Pullover': {'shoulders': [muscleFrontDelt]},
  'Straight-Arm_Dumbbell_Pullover': {'shoulders': [muscleFrontDelt]},
  'Around_The_Worlds': {'shoulders': [muscleFrontDelt]},
  'Neck_Press': {'shoulders': [muscleFrontDelt]},
  'Wide-Grip_Decline_Barbell_Bench_Press': {'shoulders': [muscleFrontDelt]},
  'Barbell_Guillotine_Bench_Press': {'shoulders': [muscleFrontDelt]},
  'Behind_Head_Chest_Stretch': {'shoulders': [muscleFrontDelt]},
  'Handstand_Push-Ups': {'shoulders': [muscleFrontDelt]},
  'Seated_Front_Deltoid': {'shoulders': [muscleFrontDelt]},
  'Push_Press': {'shoulders': [muscleFrontDelt]},
  'Close-Grip_Barbell_Bench_Press': {'shoulders': [muscleFrontDelt]},
  'Lying_Dumbbell_Tricep_Extension': {'shoulders': [muscleFrontDelt]},
  'Seated_Biceps': {'shoulders': [muscleFrontDelt]},
  'One-Arm_Kettlebell_Snatch': {'shoulders': [muscleFrontDelt]},
  'Goblet_Squat': {'shoulders': [muscleFrontDelt]},
  'Kettlebell_Pistol_Squat': {'shoulders': [muscleFrontDelt]},
  'Upright_Cable_Row': {'shoulders': [muscleFrontDelt]},
  'Standing_Military_Press': {'shoulders': [muscleFrontDelt]},
  'Dumbbell_Shoulder_Press': {'shoulders': [muscleFrontDelt]},
  'Arnold_Dumbbell_Press': {'shoulders': [muscleFrontDelt]},
  'Side_Lateral_Raise': {'shoulders': [muscleFrontDelt]},
  'Leg-Over_Floor_Press': {'shoulders': [muscleFrontDelt]},
  'Mountain_Climbers': {'shoulders': [muscleFrontDelt]},

  // ── Shoulders → REAR (rows, pulldowns, reverse-fly, face-pull, high-pull) ──
  'Wide-Grip_Lat_Pulldown': {'shoulders': [muscleRearDelt]},
  'Seated_Cable_Rows': {'shoulders': [muscleRearDelt]},
  'One-Arm_Dumbbell_Row': {'shoulders': [muscleRearDelt]},
  'Bent_Over_Barbell_Row': {'shoulders': [muscleRearDelt]},
  'Bent_Over_Two-Dumbbell_Row': {'shoulders': [muscleRearDelt]},
  'Close-Grip_Front_Lat_Pulldown': {'shoulders': [muscleRearDelt]},
  'Reverse_Grip_Bent-Over_Rows': {'shoulders': [muscleRearDelt]},
  'V-Bar_Pulldown': {'shoulders': [muscleRearDelt]},
  'Full_Range-Of-Motion_Lat_Pulldown': {'shoulders': [muscleRearDelt]},
  'Kettlebell_Sumo_High_Pull': {'shoulders': [muscleRearDelt]},
  'Face_Pull': {'shoulders': [muscleRearDelt]},

  // ── Abdominals → RECTUS (spinal flexion / anti-extension brace) ──
  'Atlas_Stones': {'abdominals': [muscleRectusAbdominis]},
  'Front_Squat_Clean_Grip': {'abdominals': [muscleRectusAbdominis]},
  'Plank': {'abdominals': [muscleRectusAbdominis]},
  'Hanging_Leg_Raise': {'abdominals': [muscleRectusAbdominis]},
  'Crunches': {'abdominals': [muscleRectusAbdominis]},
  'Dead_Bug': {'abdominals': [muscleRectusAbdominis]},

  // ── Abdominals → BOTH (rotation / anti-rotation also hits obliques) ──
  'Russian_Twist': {
    'abdominals': [muscleObliques, muscleRectusAbdominis],
  },
  'Air_Bike': {
    'abdominals': [muscleRectusAbdominis, muscleObliques],
  },
  'Alternating_Renegade_Row': {
    'abdominals': [muscleObliques, muscleRectusAbdominis],
  },

  // ── Dual-token exercises (split BOTH shoulders and abdominals) ──
  'Bodyweight_Flyes': {
    'shoulders': [muscleFrontDelt],
    'abdominals': [muscleRectusAbdominis],
  },
  'Press_Sit-Up': {
    'shoulders': [muscleFrontDelt],
    'abdominals': [muscleRectusAbdominis],
  },
  'Clean_and_Jerk': {
    'shoulders': [muscleFrontDelt],
    'abdominals': [muscleRectusAbdominis],
  },
  'Overhead_Squat': {
    'shoulders': [muscleFrontDelt],
    'abdominals': [muscleRectusAbdominis],
  },
  'Barbell_Ab_Rollout_-_On_Knees': {
    'shoulders': [muscleFrontDelt],
    'abdominals': [muscleRectusAbdominis],
  },
};

/// Resolve a raw free-exercise-db muscle [token] for [exerciseId] to its detailed
/// sub-region(s). Splittable tokens (`shoulders`/`abdominals`) resolve via the
/// curated overrides; everything else (and any un-curated splittable token) is
/// returned unchanged — the coarse fallback, never guessed.
List<String> splitDetailedMuscle(String exerciseId, String token) {
  if (kSplittableTokens.contains(token)) {
    final sub = curatedMuscleSplits[exerciseId]?[token];
    if (sub != null && sub.isNotEmpty) return sub;
  }
  return [token];
}
