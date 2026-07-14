import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/exercise_alternatives.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/workout_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('topExerciseIds (all-targets frequency default seed)', () {
    final catalog = [
      const Exercise(id: 'bench', name: 'Bench', level: 'beginner', images: []),
      const Exercise(id: 'row', name: 'Row', level: 'beginner', images: []),
      const Exercise(id: 'curl', name: 'Curl', level: 'beginner', images: []),
    ];

    test('ranks by frequency across all completed sessions, drops dead ids', () async {
      SharedPreferences.setMockInitialValues({
        'workout_sessions': jsonEncode([
          _session(date: DateTime(2026, 5, 10), logs: const [
            ExerciseLog(exerciseId: 'bench', exerciseName: 'Bench', sets: [SetEntry(weight: 50, reps: 5)]),
            ExerciseLog(exerciseId: 'ghost', exerciseName: 'Ghost', sets: [SetEntry(weight: 1, reps: 1)]),
          ]).toJson(),
          _session(date: DateTime(2026, 5, 11), logs: const [
            ExerciseLog(exerciseId: 'bench', exerciseName: 'Bench', sets: [SetEntry(weight: 50, reps: 5)]),
            ExerciseLog(exerciseId: 'row', exerciseName: 'Row', sets: [SetEntry(weight: 50, reps: 5)]),
          ]).toJson(),
          _session(date: DateTime(2026, 5, 12), logs: const [
            ExerciseLog(exerciseId: 'bench', exerciseName: 'Bench', sets: [SetEntry(weight: 50, reps: 5)]),
            ExerciseLog(exerciseId: 'row', exerciseName: 'Row', sets: [SetEntry(weight: 50, reps: 5)]),
            ExerciseLog(exerciseId: 'curl', exerciseName: 'Curl', sets: [SetEntry(weight: 20, reps: 8)]),
          ]).toJson(),
        ]),
      });

      final top = await WorkoutStorageService().topExerciseIds(catalog, limit: 5);

      // bench(3) > row(2) > curl(1); 'ghost' is not in catalog so it drops.
      expect(top, ['bench', 'row', 'curl']);
    });

    test('skips partial and abandoned sessions', () async {
      SharedPreferences.setMockInitialValues({
        'workout_sessions': jsonEncode([
          _session(date: DateTime(2026, 5, 10), logs: const [
            ExerciseLog(exerciseId: 'curl', exerciseName: 'Curl', sets: [SetEntry(weight: 20, reps: 8)]),
          ]).toJson(),
          _session(date: DateTime(2026, 5, 11), isPartial: true, logs: const [
            ExerciseLog(exerciseId: 'bench', exerciseName: 'Bench', sets: [SetEntry(weight: 50, reps: 5)]),
          ]).toJson(),
          _session(date: DateTime(2026, 5, 12), isPartial: true, isAbandoned: true, logs: const [
            ExerciseLog(exerciseId: 'row', exerciseName: 'Row', sets: [SetEntry(weight: 50, reps: 5)]),
          ]).toJson(),
        ]),
      });

      final top = await WorkoutStorageService().topExerciseIds(catalog, limit: 5);

      expect(top, ['curl']); // only the completed session counts
    });

    test('no completed history returns empty (drives the chip-first fallback)', () async {
      final top = await WorkoutStorageService().topExerciseIds(catalog, limit: 5);
      expect(top, isEmpty);
    });
  });

  group('topExerciseIdsForTargets characterization (refactor regression guard)', () {
    final catalog = [
      const Exercise(id: 'bench', name: 'Bench', level: 'beginner', images: [], primaryMuscle: 'chest'),
      const Exercise(id: 'row', name: 'Row', level: 'beginner', images: [], primaryMuscle: 'lats'),
    ];

    test('empty targets returns empty', () async {
      final top = await WorkoutStorageService().topExerciseIdsForTargets(const [], catalog);
      expect(top, isEmpty);
    });

    test('honors the muscle filter and skips partial sessions', () async {
      SharedPreferences.setMockInitialValues({
        'workout_sessions': jsonEncode([
          _session(date: DateTime(2026, 5, 10), logs: const [
            ExerciseLog(exerciseId: 'bench', exerciseName: 'Bench', sets: [SetEntry(weight: 50, reps: 5)]),
            ExerciseLog(exerciseId: 'row', exerciseName: 'Row', sets: [SetEntry(weight: 50, reps: 5)]),
          ]).toJson(),
          _session(date: DateTime(2026, 5, 11), isPartial: true, logs: const [
            ExerciseLog(exerciseId: 'bench', exerciseName: 'Bench', sets: [SetEntry(weight: 50, reps: 5)]),
          ]).toJson(),
        ]),
      });

      final chestOnly = await WorkoutStorageService()
          .topExerciseIdsForTargets(const ['Chest'], catalog, limit: 3);

      expect(chestOnly, ['bench']); // 'row' is lats, partial bench ignored
    });
  });

  group('alternativesFor (pure Replace ranking)', () {
    const bench = Exercise(id: 'bench', name: 'Bench', level: 'beginner', images: [], equipment: 'Barbell', mechanic: 'compound');
    const incline = Exercise(id: 'incline', name: 'Incline', level: 'beginner', images: [], equipment: 'Barbell', mechanic: 'compound');
    const dbPress = Exercise(id: 'db', name: 'DB Press', level: 'beginner', images: [], equipment: 'Dumbbell', mechanic: 'compound');
    const fly = Exercise(id: 'fly', name: 'Fly', level: 'beginner', images: [], equipment: 'Cable', mechanic: 'isolation');
    const unknown = Exercise(id: 'unk', name: 'Unknown', level: 'beginner', images: []);

    test('strong = shared equipment/mechanic ranked first; weak ones in more', () {
      final result = alternativesFor(bench, const [incline, dbPress, fly], <String>{});

      // incline (equip+mech = 3) before db (mech only = 1); fly (0) -> more.
      expect(result.strong.map((e) => e.id), ['incline', 'db']);
      expect(result.more.map((e) => e.id), ['fly']);
    });

    test('excludes already-selected and the replaced lift itself', () {
      final result = alternativesFor(bench, const [bench, incline, dbPress], {'db'});
      expect(result.strong.map((e) => e.id), ['incline']);
      expect(result.more, isEmpty);
    });

    test('all-excluded pool returns empty (sheet shows See All only)', () {
      final result = alternativesFor(bench, const [incline, dbPress], {'incline', 'db'});
      expect(result.isEmpty, isTrue);
    });

    test('null equipment/mechanic score 0 and never crash', () {
      final result = alternativesFor(unknown, const [incline, unknown, fly], <String>{});
      expect(result.strong, isEmpty); // replaced has null fields -> nothing scores
      expect(result.more.map((e) => e.id), ['incline', 'fly']);
    });

    test('caps the combined result at limit, strong first', () {
      final result = alternativesFor(bench, const [incline, dbPress, fly], <String>{}, limit: 1);
      expect(result.strong.map((e) => e.id), ['incline']);
      expect(result.more, isEmpty); // limit consumed by the strong match
    });
  });
}

WorkoutSession _session({
  DateTime? date,
  String muscleGroup = 'Chest',
  List<String> targetMuscleGroups = const ['Chest'],
  List<ExerciseLog>? logs,
  bool isPartial = false,
  bool isAbandoned = false,
}) {
  return WorkoutSession(
    id: (date ?? DateTime(2026, 5, 13)).microsecondsSinceEpoch.toString(),
    date: date ?? DateTime(2026, 5, 13),
    muscleGroup: muscleGroup,
    targetMuscleGroups: targetMuscleGroups,
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: logs ??
        const [
          ExerciseLog(exerciseId: 'bench', exerciseName: 'Bench Press', sets: [SetEntry(weight: 50, reps: 5)]),
        ],
    estimatedCalories: 100,
    isPartial: isPartial,
    isAbandoned: isAbandoned,
  );
}
