import 'package:flutter/material.dart';

import '../models/program_models.dart';
import '../theme/tokens.dart';
import 'muscle_groups.dart';

const programsLibrary = [
  Program(
    id: 'full_body_3x',
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
      ),
      ProgramDay(dayNumber: 6, type: ProgramDayType.rest, label: 'REST'),
      ProgramDay(dayNumber: 7, type: ProgramDayType.rest, label: 'REST'),
    ],
  ),
  Program(
    id: 'upper_lower',
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
      ),
      ProgramDay(dayNumber: 6, type: ProgramDayType.rest, label: 'REST'),
      ProgramDay(dayNumber: 7, type: ProgramDayType.rest, label: 'REST'),
    ],
  ),
  Program(
    id: 'ppl',
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

Color programTierColor(String tier) {
  if (tier.contains('ADVANCED')) return kDanger;
  if (tier.contains('INTERMEDIATE')) return kAmber;
  return kCyan;
}

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
