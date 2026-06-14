import 'muscle_groups.dart';

/// One dynamic warm-up move: a short name + a rep/time hint.
class WarmupDrill {
  const WarmupDrill(this.name, this.detail);

  final String name;
  final String detail;
}

/// A general (whole-session) warm-up plan: a generic "raise" step (light cardio)
/// that's the same every day, plus a dynamic/activation block tailored to the
/// day's muscle groups. Structured on the RAMP model (Raise → Activate/Mobilize)
/// with dynamic — not static — moves, the consensus for pre-lifting warm-ups.
class WarmupPlan {
  const WarmupPlan({required this.raise, required this.drills});

  /// The generic temperature-raise step (same regardless of muscle group).
  final String raise;

  /// Dynamic/activation moves for the day's targets, deduped, order-preserved.
  final List<WarmupDrill> drills;
}

/// Generic raise step — light cardio to lift temperature/heart rate before the
/// dynamic block. Kept conversational and brief on purpose (not pre-fatiguing).
const String _raiseStep =
    '~5 min easy cardio — bike, brisk walk, or rope. Conversational pace, just warm.';

/// Per-bucket dynamic drills (RAMP "activate + mobilize"). Curated, dynamic,
/// and aimed at the joints/muscles each bucket loads.
const Map<String, List<WarmupDrill>> _drillsByGroup = {
  'Chest': [
    WarmupDrill('Arm circles', '15 forward / 15 back'),
    WarmupDrill('Band pull-aparts', '2 × 15'),
    WarmupDrill('Push-up to down-dog', '8 slow reps'),
    WarmupDrill('Scapular push-ups', '2 × 10'),
  ],
  'Back': [
    WarmupDrill('Band pull-aparts', '2 × 15'),
    WarmupDrill('Cat-cow', '8 slow rounds'),
    WarmupDrill('T-spine rotations', '8 each side'),
    WarmupDrill('Scapular pulls / dead hang', '2 × 10s'),
  ],
  'Shoulders': [
    WarmupDrill('Arm circles', '15 forward / 15 back'),
    WarmupDrill('Band pull-aparts', '2 × 15'),
    WarmupDrill('Shoulder dislocates', '10 with band or stick'),
    WarmupDrill('Wall slides', '2 × 10'),
  ],
  'Arms': [
    WarmupDrill('Wrist circles', '10 each way'),
    WarmupDrill('Arm swings', '15 each side'),
    WarmupDrill('Light band curls', '2 × 15'),
    WarmupDrill('Band pushdowns', '2 × 15'),
  ],
  'Legs': [
    WarmupDrill('Leg swings', '10 front + 10 side each leg'),
    WarmupDrill('Hip circles', '8 each direction'),
    WarmupDrill('Bodyweight squats', '2 × 12'),
    WarmupDrill('Walking lunges', '10 each leg'),
    WarmupDrill('Ankle rocks', '10 each ankle'),
  ],
  'Core': [
    WarmupDrill('Cat-cow', '8 slow rounds'),
    WarmupDrill('Dead bug', '2 × 8 each side'),
    WarmupDrill('Bird dog', '2 × 8 each side'),
    WarmupDrill('Plank reach', '2 × 6 each arm'),
  ],
  'Full Body': [
    WarmupDrill('Jumping jacks', '30 reps'),
    WarmupDrill("World's greatest stretch", '5 each side'),
    WarmupDrill('Inchworms', '6 reps'),
    WarmupDrill('Bodyweight squats', '2 × 12'),
    WarmupDrill('Arm circles', '15 forward / 15 back'),
  ],
};

/// Caps the drill block so the sheet stays short even when many groups are
/// targeted (a 15-min warm-up is the ceiling; the list is a menu, not a mandate).
const int _maxDrills = 6;

/// Builds the tailored warm-up plan for the day's [targets] (canonical muscle
/// groups). Drills are aggregated across the targeted buckets, deduped by name
/// (first occurrence wins, order preserved) and capped. Unknown/empty targets
/// fall back to the Full Body block.
WarmupPlan warmupPlanForTargets(List<String> targets) {
  final groups = normalizeTargetMuscleGroups(targets);
  final buckets = groups.isEmpty ? const ['Full Body'] : groups;

  final seen = <String>{};
  final drills = <WarmupDrill>[];
  for (final bucket in buckets) {
    for (final drill in _drillsByGroup[bucket] ?? const <WarmupDrill>[]) {
      if (seen.add(drill.name)) drills.add(drill);
    }
  }
  if (drills.isEmpty) {
    drills.addAll(_drillsByGroup['Full Body']!);
  }

  return WarmupPlan(
    raise: _raiseStep,
    drills: drills.length > _maxDrills ? drills.sublist(0, _maxDrills) : drills,
  );
}
