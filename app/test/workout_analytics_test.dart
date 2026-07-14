import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/analytics_consent_service.dart';
import 'package:workout_track/services/analytics_service.dart';
import 'package:workout_track/services/workout_storage_service.dart';

/// Captures what the facade forwards so we can assert the funnel wiring at the
/// real persistence chokepoint (WorkoutStorageService.saveSession).
class _RecordingSink implements AnalyticsSink {
  final List<(String, Map<String, Object>?)> events = [];
  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    events.add((name, parameters));
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

WorkoutSession _completed(String id) => WorkoutSession(
  id: id,
  date: DateTime(2026, 6, 1, 18),
  muscleGroup: 'Chest',
  targetDurationMinutes: 45,
  actualDurationSeconds: 1800,
  exercises: [
    ExerciseLog(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      sets: [SetEntry(weight: 60, reps: 8), SetEntry(weight: 60, reps: 8)],
    ),
  ],
  estimatedCalories: 200,
  selectedExerciseIds: const ['bench'],
  classAtSave: 'bruiser',
);

List<(String, Map<String, Object>?)> _named(_RecordingSink s, String name) =>
    s.events.where((e) => e.$1 == name).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('first completed save logs workout_saved (params) + first_workout_saved', () async {
    final sink = _RecordingSink();
    await AnalyticsService.bootstrap(sink: sink);

    await WorkoutStorageService().saveSession(_completed('w1'));

    expect(_named(sink, 'workout_saved'), hasLength(1));
    expect(_named(sink, 'workout_saved').single.$2, {
      'exercise_count': 1,
      'set_count': 2,
      'duration_seconds': 1800,
    });
    expect(_named(sink, 'first_workout_saved'), hasLength(1));
  });

  test('re-saving the same session does not double-count (Codex F2)', () async {
    final sink = _RecordingSink();
    await AnalyticsService.bootstrap(sink: sink);

    final s = _completed('w1');
    await WorkoutStorageService().saveSession(s);
    await WorkoutStorageService().saveSession(s); // same id → re-save

    expect(_named(sink, 'workout_saved'), hasLength(1));
    expect(_named(sink, 'first_workout_saved'), hasLength(1));
  });

  test('first_workout_saved never re-fires after delete + new save (Codex F1)', () async {
    final sink = _RecordingSink();
    await AnalyticsService.bootstrap(sink: sink);

    await WorkoutStorageService().saveSession(_completed('w1'));
    await WorkoutStorageService().deleteSession('w1');
    await WorkoutStorageService().saveSession(_completed('w2')); // history back to 1

    expect(_named(sink, 'first_workout_saved'), hasLength(1)); // still lifetime-once
    expect(_named(sink, 'workout_saved'), hasLength(2)); // both real workouts count
  });

  test('opted out: a completed save logs nothing', () async {
    await AnalyticsConsentService().setAnalyticsOptedOut(true);
    final sink = _RecordingSink();
    await AnalyticsService.bootstrap(sink: sink);

    await WorkoutStorageService().saveSession(_completed('w1'));

    expect(sink.events, isEmpty);
  });
}
