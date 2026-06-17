import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/curated_exercises.dart';
import 'package:workout_track/data/muscle_groups.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/calorie_service.dart';
import 'package:workout_track/services/loot_service.dart';
import 'package:workout_track/services/quest_service.dart';
import 'package:workout_track/services/workout_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'WorkoutSession JSON defaults legacy targets and persists new targets',
    () {
      final legacy = _session(
        muscleGroup: 'Back',
        targetMuscleGroups: const ['Back', 'Arms'],
      ).toJson()..remove('targetMuscleGroups');

      final parsedLegacy = WorkoutSession.fromJson(legacy);
      expect(parsedLegacy.targetMuscleGroups, ['Back']);
      expect(parsedLegacy.targetMuscleLabel, 'Back');

      final mixed = _session(
        muscleGroup: 'Chest',
        targetMuscleGroups: const ['legs', 'Chest', 'LEGS', 'Core'],
      );
      final parsedMixed = WorkoutSession.fromJson(mixed.toJson());

      expect(parsedMixed.targetMuscleGroups, ['Chest', 'Legs', 'Core']);
      expect(parsedMixed.targetMuscleLabel, 'Chest + 2');
      expect(parsedMixed.targetsMuscle('core'), isTrue);
    },
  );

  test('target helpers normalize, dedupe, label, and ignore All', () {
    expect(
      normalizeTargetMuscleGroups(['All', 'legs', 'Chest', 'LEGS', 'unknown']),
      ['Chest', 'Legs'],
    );
    expect(targetMuscleGroupsLabel(['Back', 'Chest']), 'Chest + Back');
    expect(targetMuscleGroupsLabel(canonicalMuscleGroups), 'All Targets');
  });

  test('curated ids union and dedupe across selected groups', () {
    final ids = curatedExerciseIdsForMuscleGroups([
      'Chest',
      'Back',
      'Full Body',
    ]);

    expect(ids.first, curatedExerciseIdsByMuscleGroup['Chest']!.first);
    expect(ids, contains(curatedExerciseIdsByMuscleGroup['Back']!.first));
    expect(ids, contains(curatedExerciseIdsByMuscleGroup['Full Body']!.first));
    expect(ids.where((id) => id == 'Alternating_Renegade_Row').length, 1);
  });

  test('calories average MET values across target groups', () {
    expect(CalorieService.estimateCaloriesForGroups(['Chest'], 3600), 350);
    expect(
      CalorieService.estimateCaloriesForGroups(['Chest', 'Legs'], 3600),
      385,
    );
  });

  test('quest group mechanics credit every selected target', () async {
    final now = DateTime(2026, 5, 13, 10);
    final sideSummary = await QuestService().getSummary([
      _session(
        date: now,
        muscleGroup: 'Chest',
        targetMuscleGroups: const ['Chest', 'Back', 'Arms', 'Legs'],
      ),
    ], now: now);
    expect(
      sideSummary.sideQuests
          .firstWhere((quest) => quest.id == 'side_all_muscles')
          .completed,
      isTrue,
    );
  });

  test('loot muscle session rules credit selected targets', () async {
    final sessions = [
      for (var i = 0; i < 10; i++)
        _session(
          date: DateTime(2026, 5, 1 + i),
          muscleGroup: 'Back',
          targetMuscleGroups: const ['Back', 'Chest'],
        ),
    ];

    final unlocked = await LootService().evaluateUnlocks(
      stats: const {},
      sessions: sessions,
    );

    expect(unlocked, contains('title_shadow_slayer'));
  });

  test('loot muscle volume uses exercise-attributed volume', () async {
    final unlocked = await LootService().evaluateUnlocks(
      stats: const {},
      sessions: [
        _session(
          muscleGroup: 'Back',
          targetMuscleGroups: const ['Back', 'Chest'],
          logs: const [
            ExerciseLog(
              exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
              exerciseName: 'Bench Press',
              sets: [SetEntry(weight: 100, reps: 50)],
            ),
          ],
        ),
      ],
    );

    expect(unlocked, contains('title_golem_breaker'));
    expect(unlocked, isNot(contains('title_wraith_hunter')));
  });

  test('program day focus maps to stored target groups', () {
    final ppl = programById('ppl')!;
    final upperLower = programById('upper_lower')!;
    final fullBody = programById('full_body_3x')!;

    expect(programDayTargetMuscleGroups(ppl.weekSchedule.first), [
      'Chest',
      'Shoulders',
      'Arms',
    ]);
    expect(programDayTargetMuscleGroups(ppl.weekSchedule[1]), ['Back', 'Arms']);
    expect(programDayTargetMuscleGroups(upperLower.weekSchedule.first), [
      'Chest',
      'Back',
      'Shoulders',
      'Arms',
    ]);
    expect(programDayTargetMuscleGroups(fullBody.weekSchedule.first), [
      'Full Body',
    ]);
  });

  test(
    'lastCompletedSession ignores partial and ended-early sessions',
    () async {
      final completed = _session(
        date: DateTime(2026, 5, 13),
        muscleGroup: 'Back',
      );
      final partial = _session(
        date: DateTime(2026, 5, 14),
        muscleGroup: 'Chest',
      ).copyForTest(isPartial: true);
      final abandoned = _session(
        date: DateTime(2026, 5, 15),
        muscleGroup: 'Legs',
      ).copyForTest(isPartial: true, isAbandoned: true);
      SharedPreferences.setMockInitialValues({
        'workout_sessions': jsonEncode([
          completed.toJson(),
          partial.toJson(),
          abandoned.toJson(),
        ]),
      });

      final last = await WorkoutStorageService().lastCompletedSession();

      expect(last?.id, completed.id);
    },
  );

  test(
    'top exercise ids for targets use completed history frequency',
    () async {
      final catalog = [
        const Exercise(
          id: 'bench',
          name: 'Bench',
          level: 'beginner',
          images: [],
          primaryMuscle: 'chest',
        ),
        const Exercise(
          id: 'row',
          name: 'Row',
          level: 'beginner',
          images: [],
          primaryMuscle: 'lats',
        ),
        const Exercise(
          id: 'curl',
          name: 'Curl',
          level: 'beginner',
          images: [],
          primaryMuscle: 'biceps',
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'workout_sessions': jsonEncode([
          _session(
            date: DateTime(2026, 5, 10),
            logs: const [
              ExerciseLog(
                exerciseId: 'bench',
                exerciseName: 'Bench',
                sets: [SetEntry(weight: 50, reps: 5)],
              ),
              ExerciseLog(
                exerciseId: 'row',
                exerciseName: 'Row',
                sets: [SetEntry(weight: 50, reps: 5)],
              ),
            ],
          ).toJson(),
          _session(
            date: DateTime(2026, 5, 11),
            logs: const [
              ExerciseLog(
                exerciseId: 'bench',
                exerciseName: 'Bench',
                sets: [SetEntry(weight: 50, reps: 5)],
              ),
            ],
          ).toJson(),
          _session(
            date: DateTime(2026, 5, 12),
            logs: const [
              ExerciseLog(
                exerciseId: 'curl',
                exerciseName: 'Curl',
                sets: [SetEntry(weight: 20, reps: 8)],
              ),
            ],
          ).toJson(),
        ]),
      });

      final top = await WorkoutStorageService().topExerciseIdsForTargets(
        const ['Chest', 'Back'],
        catalog,
        limit: 3,
      );

      expect(top, ['bench', 'row']);
    },
  );
}

WorkoutSession _session({
  DateTime? date,
  String muscleGroup = 'Chest',
  List<String> targetMuscleGroups = const ['Chest'],
  List<ExerciseLog>? logs,
}) {
  return WorkoutSession(
    id: (date ?? DateTime(2026, 5, 13)).microsecondsSinceEpoch.toString(),
    date: date ?? DateTime(2026, 5, 13),
    muscleGroup: muscleGroup,
    targetMuscleGroups: targetMuscleGroups,
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises:
        logs ??
        const [
          ExerciseLog(
            exerciseId: 'bench',
            exerciseName: 'Bench Press',
            sets: [SetEntry(weight: 50, reps: 5)],
          ),
        ],
    estimatedCalories: 100,
  );
}

extension on WorkoutSession {
  WorkoutSession copyForTest({bool? isPartial, bool? isAbandoned}) {
    return WorkoutSession(
      id: id,
      date: date,
      startedAt: startedAt,
      muscleGroup: muscleGroup,
      targetMuscleGroups: targetMuscleGroups,
      targetDurationMinutes: targetDurationMinutes,
      actualDurationSeconds: actualDurationSeconds,
      exercises: exercises,
      estimatedCalories: estimatedCalories,
      isPartial: isPartial ?? this.isPartial,
      isAbandoned: isAbandoned ?? this.isAbandoned,
      selectedExerciseIds: selectedExerciseIds,
    );
  }
}
