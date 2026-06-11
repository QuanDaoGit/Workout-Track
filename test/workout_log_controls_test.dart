import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/weekly_goal_service.dart';
import 'package:workout_track/services/workout_metric_service.dart';
import 'package:workout_track/services/workout_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WeeklyGoalService', () {
    test('defaults to 3 days with no program and no calibration', () async {
      expect(await WeeklyGoalService().getGoalDays(), 3);
    });

    test('seeds from calibration frequency at the lower bound', () async {
      for (final (freq, expected) in [('low', 2), ('mid', 4), ('high', 6)]) {
        SharedPreferences.setMockInitialValues({
          'calibration_freq_v1': freq,
        });
        expect(
          await WeeklyGoalService().getGoalDays(),
          expected,
          reason: 'freq=$freq',
        );
      }
    });

    test('stored value wins over seeding and is clamped', () async {
      SharedPreferences.setMockInitialValues({
        'calibration_freq_v1': 'high',
        WeeklyGoalService.goalKey: 5,
      });
      expect(await WeeklyGoalService().getGoalDays(), 5);

      SharedPreferences.setMockInitialValues({
        WeeklyGoalService.goalKey: 99,
      });
      expect(await WeeklyGoalService().getGoalDays(), 7);
    });

    test('setGoalDays clamps to the 2–7 range', () async {
      final service = WeeklyGoalService();
      await service.setGoalDays(1);
      expect(await service.getGoalDays(), 2);
      await service.setGoalDays(10);
      expect(await service.getGoalDays(), 7);
      await service.setGoalDays(4);
      expect(await service.getGoalDays(), 4);
    });
  });

  group('WorkoutMetricService.prCountsBySession', () {
    test('first-ever log is a baseline, not a PR', () {
      final session = _session(id: 'a', day: 1, weight: 50, reps: 5);
      final counts = WorkoutMetricService.prCountsBySession([session]);
      expect(counts['a'], 0);
    });

    test('beating the prior best e1RM counts one PR per exercise', () {
      final sessions = [
        _session(id: 'a', day: 1, weight: 50, reps: 5),
        _session(id: 'b', day: 2, weight: 55, reps: 5),
        _session(id: 'c', day: 3, weight: 55, reps: 5),
      ];
      final counts = WorkoutMetricService.prCountsBySession(sessions);
      expect(counts['a'], 0);
      expect(counts['b'], 1);
      expect(counts['c'], 0);
    });

    test('order independence: sessions sorted by date before counting', () {
      final sessions = [
        _session(id: 'newer', day: 2, weight: 60, reps: 5),
        _session(id: 'older', day: 1, weight: 50, reps: 5),
      ];
      final counts = WorkoutMetricService.prCountsBySession(sessions);
      expect(counts['older'], 0);
      expect(counts['newer'], 1);
    });

    test('partial and abandoned sessions are excluded', () {
      final sessions = [
        _session(id: 'base', day: 1, weight: 50, reps: 5),
        _session(id: 'gone', day: 2, weight: 90, reps: 5, isAbandoned: true),
        _session(id: 'live', day: 3, weight: 55, reps: 5),
      ];
      final counts = WorkoutMetricService.prCountsBySession(sessions);
      expect(counts.containsKey('gone'), isFalse);
      // The abandoned 90 kg never became the baseline, so 55 kg is still a PR.
      expect(counts['live'], 1);
    });

    test('bodyweight rep improvements count as PRs (matches live badge)', () {
      final sessions = [
        _session(id: 'a', day: 1, weight: 0, reps: 10),
        _session(id: 'b', day: 2, weight: 0, reps: 20),
        _session(id: 'c', day: 3, weight: 0, reps: 20),
      ];
      final counts = WorkoutMetricService.prCountsBySession(sessions);
      expect(counts['a'], 0); // baseline
      expect(counts['b'], 1); // more reps at bodyweight → higher e1RM
      expect(counts['c'], 0); // matching, not beating
    });
  });

  group('WorkoutStorageService.updateSession', () {
    test('replaces the matching session and keeps the rest', () async {
      final storage = WorkoutStorageService();
      final keep = _session(id: 'keep', day: 1, weight: 40, reps: 5);
      final original = _session(id: 'edit', day: 2, weight: 100, reps: 5);
      await storage.saveSession(keep);
      await storage.saveSession(original);

      // Unknown id is a no-op.
      await storage.updateSession(
        _session(id: 'ghost', day: 3, weight: 1, reps: 1),
      );
      expect((await storage.getSessions()).length, 2);

      final edited = original.copyWith(
        exercises: [
          const ExerciseLog(
            exerciseId: 'bench',
            exerciseName: 'Bench Press',
            sets: [SetEntry(weight: 105, reps: 5)],
          ),
        ],
      );
      await storage.updateSession(edited);

      final sessions = await storage.getSessions();
      expect(sessions.length, 2);
      expect(
        sessions
            .singleWhere((s) => s.id == 'keep')
            .exercises
            .single
            .sets
            .single
            .weight,
        40,
      );
      final stored = sessions.singleWhere((s) => s.id == 'edit');
      expect(stored.exercises.single.sets.single.weight, 105);
      expect(stored.awardedXP, original.awardedXP);
    });

    test('cache stays correct when prefs are written externally', () async {
      final storage = WorkoutStorageService();
      await storage.replaceOngoingSession(
        _session(id: 'first', day: 1, weight: 40, reps: 5, isPartial: true),
      );
      // Warm the cache.
      expect((await storage.getSessions()).single.id, 'first');

      // External write (migration/test-style): bypasses _writeSessions.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'workout_sessions',
        jsonEncode([
          _session(id: 'second', day: 2, weight: 50, reps: 5).toJson(),
        ]),
      );

      final sessions = await storage.getSessions();
      expect(sessions.single.id, 'second');
    });
  });
}

WorkoutSession _session({
  required String id,
  required int day,
  required double weight,
  required int reps,
  bool isPartial = false,
  bool isAbandoned = false,
}) {
  return WorkoutSession(
    id: id,
    date: DateTime(2026, 6, day, 9),
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: [
      ExerciseLog(
        exerciseId: 'bench',
        exerciseName: 'Bench Press',
        sets: [SetEntry(weight: weight, reps: reps)],
      ),
    ],
    estimatedCalories: 100,
    isPartial: isPartial || isAbandoned,
    isAbandoned: isAbandoned,
    selectedExerciseIds: const ['bench'],
  );
}
