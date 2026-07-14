import '../models/program_models.dart';
import 'muscle_groups.dart';

// Shared per-exercise prescriptions, authored once and referenced per day.
const _l8 = SetRepScheme(sets: 3, repMin: 8); // linear compound
const _l10 = SetRepScheme(sets: 3, repMin: 10); // linear isolation
const _dp812 = SetRepScheme(sets: 3, repMin: 8, repMax: 12); // double-prog compound
const _dp1015 = SetRepScheme(sets: 3, repMin: 10, repMax: 15); // double-prog isolation
const _dp1215 = SetRepScheme(sets: 3, repMin: 12, repMax: 15); // double-prog calves

const programsLibrary = [
  Program(
    id: 'full_body_3x',
    progression: ProgressionScheme.linear,
    name: 'FULL BODY 3X',
    description: 'Three balanced training days with recovery between runs.',
    tier: 'BEGINNER',
    daysPerWeek: 3,
    recommendedWeeks: 8,
    weekSchedule: [
      ProgramDay(
        dayNumber: 1,
        type: ProgramDayType.workout,
        focus: MuscleFocus.fullBody,
        label: 'FULL BODY A',
        suggestedExerciseIds: [
          'Barbell_Bench_Press_-_Medium_Grip',
          'Wide-Grip_Lat_Pulldown',
          'Barbell_Squat',
          'Dumbbell_Bicep_Curl',
          'Triceps_Pushdown',
        ],
        prescription: {
          'Barbell_Bench_Press_-_Medium_Grip': _l8,
          'Wide-Grip_Lat_Pulldown': _l8,
          'Barbell_Squat': _l8,
          'Dumbbell_Bicep_Curl': _l10,
          'Triceps_Pushdown': _l10,
        },
      ),
      ProgramDay(dayNumber: 2, type: ProgramDayType.rest, label: 'REST'),
      ProgramDay(
        dayNumber: 3,
        type: ProgramDayType.workout,
        focus: MuscleFocus.fullBody,
        label: 'FULL BODY B',
        suggestedExerciseIds: [
          'Dumbbell_Bench_Press',
          'Seated_Cable_Rows',
          'Leg_Press',
          'Hammer_Curls',
          'EZ-Bar_Skullcrusher',
        ],
        prescription: {
          'Dumbbell_Bench_Press': _l8,
          'Seated_Cable_Rows': _l8,
          'Leg_Press': _l8,
          'Hammer_Curls': _l10,
          'EZ-Bar_Skullcrusher': _l10,
        },
      ),
      ProgramDay(dayNumber: 4, type: ProgramDayType.rest, label: 'REST'),
      ProgramDay(
        dayNumber: 5,
        type: ProgramDayType.workout,
        focus: MuscleFocus.fullBody,
        label: 'FULL BODY C',
        suggestedExerciseIds: [
          'Incline_Dumbbell_Press',
          'One-Arm_Dumbbell_Row',
          'Dumbbell_Lunges',
          'Cable_Hammer_Curls_-_Rope_Attachment',
          'Triceps_Pushdown_-_Rope_Attachment',
        ],
        prescription: {
          'Incline_Dumbbell_Press': _l8,
          'One-Arm_Dumbbell_Row': _l8,
          'Dumbbell_Lunges': _l8,
          'Cable_Hammer_Curls_-_Rope_Attachment': _l10,
          'Triceps_Pushdown_-_Rope_Attachment': _l10,
        },
      ),
      ProgramDay(dayNumber: 6, type: ProgramDayType.rest, label: 'REST'),
      ProgramDay(dayNumber: 7, type: ProgramDayType.rest, label: 'REST'),
    ],
  ),
  Program(
    id: 'upper_lower',
    progression: ProgressionScheme.doubleProgression,
    name: 'UPPER LOWER',
    description: 'Four focused sessions split between upper and lower body.',
    tier: 'INTERMEDIATE',
    daysPerWeek: 4,
    recommendedWeeks: 8,
    weekSchedule: [
      ProgramDay(
        dayNumber: 1,
        type: ProgramDayType.workout,
        focus: MuscleFocus.upper,
        label: 'UPPER',
        suggestedExerciseIds: [
          'Barbell_Bench_Press_-_Medium_Grip',
          'Wide-Grip_Lat_Pulldown',
          'Seated_Cable_Rows',
          'Dumbbell_Bicep_Curl',
          'Triceps_Pushdown',
        ],
        prescription: {
          'Barbell_Bench_Press_-_Medium_Grip': _dp812,
          'Wide-Grip_Lat_Pulldown': _dp812,
          'Seated_Cable_Rows': _dp812,
          'Dumbbell_Bicep_Curl': _dp1015,
          'Triceps_Pushdown': _dp1015,
        },
      ),
      ProgramDay(
        dayNumber: 2,
        type: ProgramDayType.workout,
        focus: MuscleFocus.lower,
        label: 'LOWER',
        suggestedExerciseIds: [
          'Barbell_Squat',
          'Leg_Press',
          'Dumbbell_Lunges',
          'Lying_Leg_Curls',
          'Standing_Calf_Raises',
        ],
        prescription: {
          'Barbell_Squat': _dp812,
          'Leg_Press': _dp812,
          'Dumbbell_Lunges': _dp812,
          'Lying_Leg_Curls': _dp1015,
          'Standing_Calf_Raises': _dp1215,
        },
      ),
      ProgramDay(dayNumber: 3, type: ProgramDayType.rest, label: 'REST'),
      ProgramDay(
        dayNumber: 4,
        type: ProgramDayType.workout,
        focus: MuscleFocus.upper,
        label: 'UPPER',
        suggestedExerciseIds: [
          'Dumbbell_Bench_Press',
          'One-Arm_Dumbbell_Row',
          'Close-Grip_Front_Lat_Pulldown',
          'Hammer_Curls',
          'EZ-Bar_Skullcrusher',
        ],
        prescription: {
          'Dumbbell_Bench_Press': _dp812,
          'One-Arm_Dumbbell_Row': _dp812,
          'Close-Grip_Front_Lat_Pulldown': _dp812,
          'Hammer_Curls': _dp1015,
          'EZ-Bar_Skullcrusher': _dp1015,
        },
      ),
      ProgramDay(
        dayNumber: 5,
        type: ProgramDayType.workout,
        focus: MuscleFocus.lower,
        label: 'LOWER',
        suggestedExerciseIds: [
          'Hack_Squat',
          'Front_Squat_Clean_Grip',
          'Romanian_Deadlift',
          'Seated_Leg_Curl',
          'Seated_Calf_Raise',
        ],
        prescription: {
          'Hack_Squat': _dp812,
          'Front_Squat_Clean_Grip': _dp812,
          'Romanian_Deadlift': _dp812,
          'Seated_Leg_Curl': _dp1015,
          'Seated_Calf_Raise': _dp1215,
        },
      ),
      ProgramDay(dayNumber: 6, type: ProgramDayType.rest, label: 'REST'),
      ProgramDay(dayNumber: 7, type: ProgramDayType.rest, label: 'REST'),
    ],
  ),
  Program(
    id: 'ppl',
    progression: ProgressionScheme.doubleProgression,
    name: 'PUSH PULL LEGS',
    description: 'Six-day gym split for repeatable strength practice.',
    tier: 'INTERMEDIATE/ADVANCED',
    daysPerWeek: 6,
    recommendedWeeks: 8,
    weekSchedule: [
      ProgramDay(
        dayNumber: 1,
        type: ProgramDayType.workout,
        focus: MuscleFocus.push,
        label: 'PUSH',
        suggestedExerciseIds: [
          'Barbell_Bench_Press_-_Medium_Grip',
          'Barbell_Incline_Bench_Press_-_Medium_Grip',
          'Dumbbell_Flyes',
          'Triceps_Pushdown',
          'Dumbbell_One-Arm_Triceps_Extension',
        ],
        prescription: {
          'Barbell_Bench_Press_-_Medium_Grip': _dp812,
          'Barbell_Incline_Bench_Press_-_Medium_Grip': _dp812,
          'Dumbbell_Flyes': _dp1015,
          'Triceps_Pushdown': _dp1015,
          'Dumbbell_One-Arm_Triceps_Extension': _dp1015,
        },
      ),
      ProgramDay(
        dayNumber: 2,
        type: ProgramDayType.workout,
        focus: MuscleFocus.pull,
        label: 'PULL',
        suggestedExerciseIds: [
          'Wide-Grip_Lat_Pulldown',
          'Seated_Cable_Rows',
          'One-Arm_Dumbbell_Row',
          'Barbell_Curl',
          'Hammer_Curls',
        ],
        prescription: {
          'Wide-Grip_Lat_Pulldown': _dp812,
          'Seated_Cable_Rows': _dp812,
          'One-Arm_Dumbbell_Row': _dp812,
          'Barbell_Curl': _dp1015,
          'Hammer_Curls': _dp1015,
        },
      ),
      ProgramDay(
        dayNumber: 3,
        type: ProgramDayType.workout,
        focus: MuscleFocus.legs,
        label: 'LEGS',
        suggestedExerciseIds: [
          'Barbell_Squat',
          'Leg_Press',
          'Romanian_Deadlift',
          'Lying_Leg_Curls',
          'Standing_Calf_Raises',
        ],
        prescription: {
          'Barbell_Squat': _dp812,
          'Leg_Press': _dp812,
          'Romanian_Deadlift': _dp812,
          'Lying_Leg_Curls': _dp1015,
          'Standing_Calf_Raises': _dp1215,
        },
      ),
      ProgramDay(
        dayNumber: 4,
        type: ProgramDayType.workout,
        focus: MuscleFocus.push,
        label: 'PUSH',
        suggestedExerciseIds: [
          'Dumbbell_Bench_Press',
          'Incline_Dumbbell_Press',
          'Cable_Crossover',
          'EZ-Bar_Skullcrusher',
          'Triceps_Pushdown_-_Rope_Attachment',
        ],
        prescription: {
          'Dumbbell_Bench_Press': _dp812,
          'Incline_Dumbbell_Press': _dp812,
          'Cable_Crossover': _dp1015,
          'EZ-Bar_Skullcrusher': _dp1015,
          'Triceps_Pushdown_-_Rope_Attachment': _dp1015,
        },
      ),
      ProgramDay(
        dayNumber: 5,
        type: ProgramDayType.workout,
        focus: MuscleFocus.pull,
        label: 'PULL',
        suggestedExerciseIds: [
          'Bent_Over_Barbell_Row',
          'Close-Grip_Front_Lat_Pulldown',
          'Straight-Arm_Pulldown',
          'EZ-Bar_Curl',
          'Preacher_Curl',
        ],
        prescription: {
          'Bent_Over_Barbell_Row': _dp812,
          'Close-Grip_Front_Lat_Pulldown': _dp812,
          'Straight-Arm_Pulldown': _dp1015,
          'EZ-Bar_Curl': _dp1015,
          'Preacher_Curl': _dp1015,
        },
      ),
      ProgramDay(
        dayNumber: 6,
        type: ProgramDayType.workout,
        focus: MuscleFocus.legs,
        label: 'LEGS',
        suggestedExerciseIds: [
          'Hack_Squat',
          'Dumbbell_Lunges',
          'Leg_Extensions',
          'Seated_Leg_Curl',
          'Seated_Calf_Raise',
        ],
        prescription: {
          'Hack_Squat': _dp812,
          'Dumbbell_Lunges': _dp812,
          'Leg_Extensions': _dp1015,
          'Seated_Leg_Curl': _dp1015,
          'Seated_Calf_Raise': _dp1215,
        },
      ),
      ProgramDay(dayNumber: 7, type: ProgramDayType.rest, label: 'REST'),
    ],
  ),
];

Program? programById(String id) {
  for (final program in programsLibrary) {
    if (program.id == id) return program;
  }
  return null;
}

/// Maps a legacy 7-slot [currentDayIndex] (the pre-weekday-anchor cursor over
/// the full workout+rest cycle) to the workout-only [Program.workouts] index the
/// user should resume at: the next workout slot at or after [currentDayIndex],
/// wrapping. A legacy cursor parked on a rest slot resolves to the upcoming
/// workout; one already on a workout slot resolves to that workout. Pure +
/// deterministic so the `weekdayAnchoredScheduleV1` migration is unit-testable.
int workoutIndexForLegacyDayIndex(Program program, int currentDayIndex) {
  final schedule = program.weekSchedule;
  if (schedule.isEmpty) return 0;
  final len = schedule.length;
  final start = ((currentDayIndex % len) + len) % len; // normalize negatives
  for (var offset = 0; offset < len; offset++) {
    final i = (start + offset) % len;
    if (schedule[i].isWorkout) {
      // Position of slot i among workout-only slots = workouts before it.
      var pos = 0;
      for (var j = 0; j < i; j++) {
        if (schedule[j].isWorkout) pos++;
      }
      return pos;
    }
  }
  return 0; // schedule has no workout slots (not expected)
}

/// Deterministic next program offered when an arc completes (BEGIN NEXT PATH).
/// Push Pull Legs chains to itself — a fresh, harder-earned cycle.
const Map<String, String> programChainNext = {
  'full_body_3x': 'upper_lower',
  'upper_lower': 'ppl',
  'ppl': 'ppl',
};

/// The identity Title granted when a program arc is completed.
const Map<String, String> programTitleId = {
  'full_body_3x': 'title_foundation_forged',
  'upper_lower': 'title_iron_rhythm',
  'ppl': 'title_split_discipline',
};

/// The next program in the completion chain, or null if the id is unknown.
Program? nextProgramInChain(String programId) {
  final nextId = programChainNext[programId];
  return nextId == null ? null : programById(nextId);
}

/// The Title id earned by completing [programId], or null if none is mapped.
String? titleIdForProgram(String programId) => programTitleId[programId];

String programDayFocusSummary(ProgramDay day) {
  if (day.type == ProgramDayType.rest) return 'recovery scheduled';
  return switch (day.focus) {
    MuscleFocus.push ||
    MuscleFocus.chestTriceps => 'chest - shoulders - triceps',
    MuscleFocus.pull || MuscleFocus.backBiceps => 'back - biceps',
    MuscleFocus.legs || MuscleFocus.lower => 'legs',
    MuscleFocus.upper => 'chest - back - arms',
    MuscleFocus.fullBody => 'chest - back - legs - arms',
    MuscleFocus.shouldersCore => 'shoulders - core',
    null => 'program workout',
  };
}

String programDayPrimaryMuscleGroup(ProgramDay day) {
  final targets = programDayTargetMuscleGroups(day);
  if (targets.isEmpty) return 'Chest';
  return targets.first;
}

List<String> programDayTargetMuscleGroups(ProgramDay day) {
  if (day.type == ProgramDayType.rest) return const [];
  return switch (day.focus) {
    MuscleFocus.push || MuscleFocus.chestTriceps => normalizeTargetMuscleGroups(
      ['Chest', 'Shoulders', 'Arms'],
    ),
    MuscleFocus.pull ||
    MuscleFocus.backBiceps => normalizeTargetMuscleGroups(['Back', 'Arms']),
    MuscleFocus.legs ||
    MuscleFocus.lower => normalizeTargetMuscleGroups(['Legs']),
    MuscleFocus.upper => normalizeTargetMuscleGroups([
      'Chest',
      'Back',
      'Shoulders',
      'Arms',
    ]),
    MuscleFocus.fullBody => normalizeTargetMuscleGroups(['Full Body']),
    MuscleFocus.shouldersCore => normalizeTargetMuscleGroups([
      'Shoulders',
      'Core',
    ]),
    null => const [],
  };
}

String programDayAbbreviation(ProgramDay day) {
  if (day.type == ProgramDayType.rest) return 'R';
  return switch (day.label) {
    'FULL BODY A' => 'A',
    'FULL BODY B' => 'B',
    'FULL BODY C' => 'C',
    'PUSH' => 'P',
    'PULL' => 'U',
    'LEGS' => 'L',
    'UPPER' => 'UP',
    'LOWER' => 'LO',
    _ => day.label.length <= 2 ? day.label : day.label.substring(0, 2),
  };
}

/// The next workout day after the user's current position, plus an on-track
/// estimate of how many calendar days away it is. See [nextWorkoutLookahead].
class ProgramLookahead {
  const ProgramLookahead(this.workout, this.daysAway);

  final ProgramDay workout;

  /// On-track minimum calendar days until [workout] becomes today. Always >= 1.
  final int daysAway;
}

/// The next WORKOUT under the weekday-anchored schedule, plus how many calendar
/// days away it lands — the first training weekday strictly after [today].
///
/// [workoutIndex] is the user's progression cursor into [Program.workouts].
/// [todayWorkoutPending] is true only on the active-workout panel, where today
/// still shows an undone workout (`workouts[workoutIndex]`), so the teaser points
/// at the FOLLOWING workout (`workoutIndex + 1`). On the rest panel and the
/// completed-today panel (where `advanceDay` already moved the cursor) it points
/// at `workouts[workoutIndex]`. Returns null for a program with no workouts or no
/// training weekdays.
ProgramLookahead? nextWorkoutLookahead(
  Program program,
  int workoutIndex, {
  required Set<int> trainingWeekdays,
  required DateTime today,
  required bool todayWorkoutPending,
}) {
  final workouts = program.workouts;
  if (workouts.isEmpty || trainingWeekdays.isEmpty) return null;

  final labelIndex =
      (workoutIndex + (todayWorkoutPending ? 1 : 0)) % workouts.length;

  // Days until the next training weekday strictly after today (1..7).
  var daysAway = 1;
  while (daysAway <= 7) {
    final weekday = (today.weekday - 1 + daysAway) % 7 + 1;
    if (trainingWeekdays.contains(weekday)) break;
    daysAway++;
  }
  return ProgramLookahead(workouts[labelIndex], daysAway);
}

/// Relative wording for a [ProgramLookahead.daysAway] count. The single swap
/// point if a future optional day/time intention ever sharpens the "when".
String relativeWhen(int daysAway) => switch (daysAway) {
  <= 1 => 'tomorrow',
  _ => 'in $daysAway days',
};

/// Returns [day] with per-program exercise [swaps] applied. Each suggested
/// exercise id is remapped through [swaps] (originalId → replacementId) and the
/// prescription is re-keyed to match, the replacement inheriting the original's
/// [SetRepScheme]. A remapped id that duplicates an earlier one is dropped
/// (first occurrence wins, order preserved). Rest days, empty swaps, and days
/// that no swap touches return [day] unchanged.
ProgramDay applyProgramSwaps(ProgramDay day, Map<String, String> swaps) {
  if (swaps.isEmpty || !day.isWorkout) return day;
  if (!day.suggestedExerciseIds.any(swaps.containsKey)) return day;

  final newIds = <String>[];
  final seen = <String>{};
  for (final id in day.suggestedExerciseIds) {
    final mapped = swaps[id] ?? id;
    if (seen.add(mapped)) newIds.add(mapped);
  }

  final newPrescription = <String, SetRepScheme>{};
  for (final entry in day.prescription.entries) {
    newPrescription[swaps[entry.key] ?? entry.key] = entry.value;
  }

  return ProgramDay(
    dayNumber: day.dayNumber,
    type: day.type,
    label: day.label,
    focus: day.focus,
    suggestedExerciseIds: newIds,
    prescription: newPrescription,
  );
}
