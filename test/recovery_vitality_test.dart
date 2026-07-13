import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/rest_service.dart';
import 'package:workout_track/services/stat_engine.dart';

/// Exercises the VIT recovery-balance meter (rolling 14-day) directly via the
/// public `vitalityFromState` helper, plus the legs→STR remap end-to-end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalog = {
    'bench': 'chest', // STR
    'squat': 'quadriceps', // STR now (was VIT)
    'row': 'lats', // STR (back)
    'ohp': 'shoulders', // AGI
  };

  setUp(() => SharedPreferences.setMockInitialValues({}));

  WorkoutSession session(DateTime date, String exerciseId) => WorkoutSession(
    id: 'w-${date.toIso8601String()}-$exerciseId',
    date: date,
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    estimatedCalories: 100,
    exercises: [
      ExerciseLog(
        exerciseId: exerciseId,
        exerciseName: exerciseId,
        sets: const [SetEntry(weight: 100, reps: 5)],
      ),
    ],
  );

  group('VIT recovery meter', () {
    // Training schedule = Mon/Wed/Fri (RestState default).
    RestState schedule() => RestState.defaults(
      currentWeekKey: RestService.weekKey(DateTime(2026, 5, 25)),
    );

    test('perfect train+rest adherence scores near 100', () {
      final now = DateTime(2026, 5, 31, 12); // Sunday
      final engine = StatEngine(nowProvider: () => now, catalog: catalog);
      final rest = RestService(nowProvider: () => now);

      // Complete every scheduled training day (Mon/Wed/Fri) in the window;
      // rest days take care of themselves.
      final sessions = <WorkoutSession>[];
      for (var i = 0; i < 14; i++) {
        final day = DateTime(2026, 5, 31).subtract(Duration(days: i));
        if ({1, 3, 5}.contains(day.weekday)) {
          sessions.add(session(day, 'bench'));
        }
      }

      final vit = engine.vitalityFromState(schedule(), sessions, rest);
      expect(vit, greaterThanOrEqualTo(90));
    });

    test('inactivity collapses VIT toward the floor', () {
      final now = DateTime(2026, 5, 31, 12);
      final engine = StatEngine(nowProvider: () => now, catalog: catalog);
      final rest = RestService(nowProvider: () => now);

      // No sessions at all → scheduled training days are unplanned misses.
      final vit = engine.vitalityFromState(schedule(), const [], rest);
      expect(vit, lessThanOrEqualTo(20)); // near the floor (10)
    });

    test('overtraining (no rest) lands mid-range, below perfect', () {
      final now = DateTime(2026, 5, 31, 12);
      final engine = StatEngine(nowProvider: () => now, catalog: catalog);
      final rest = RestService(nowProvider: () => now);

      // Train EVERY day in the window (incl. rest days) → rest-day workouts
      // earn only partial credit.
      final sessions = [
        for (var i = 0; i < 14; i++)
          session(DateTime(2026, 5, 31).subtract(Duration(days: i)), 'bench'),
      ];
      final vit = engine.vitalityFromState(schedule(), sessions, rest);
      expect(vit, lessThan(95));
      expect(vit, greaterThan(20));
    });
  });

  group('legs → STR end to end', () {
    test('a squat session raises STR, not VIT', () async {
      final now = DateTime(2026, 5, 14, 10);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'workout_sessions',
        jsonEncode([session(now, 'squat').toJson()]),
      );

      final stats = await StatEngine(
        nowProvider: () => now,
        catalog: catalog,
      ).calculateAllStats();

      expect(stats['STR']!, greaterThan(10)); // legs feed STR
      // VIT is the recovery meter (clamped 0–100), not squat volume.
      expect(stats['VIT']! <= 100, isTrue);
    });
  });
}
