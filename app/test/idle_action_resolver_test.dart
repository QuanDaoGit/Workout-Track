import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/workout_storage_service.dart';

/// The idle-funnel taxonomy: ONE resolver decides none / ask / autoSave /
/// autoDiscard for both reveal sites (the shell's cold-case check and the
/// active page's own timer), so a forgotten session can never live forever —
/// the 765-hour bug. Spec discussion: deep-feature 2026-07-21.
WorkoutSession _session({
  bool ongoing = true,
  bool paused = false,
  DateTime? startedAt,
  DateTime? lastActivityAt,
  bool withSet = true,
}) {
  final start = startedAt ?? DateTime(2026, 5, 14, 9);
  return WorkoutSession(
    id: 's1',
    date: start,
    startedAt: start,
    lastActivityAt: lastActivityAt,
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 600,
    estimatedCalories: 20,
    isPartial: ongoing,
    isPausedForResume: paused,
    autoDiscardAt: paused ? start.add(const Duration(days: 1)) : null,
    selectedExerciseIds: const ['a'],
    exercises: [
      ExerciseLog(
        exerciseId: 'a',
        exerciseName: 'a',
        sets: withSet ? const [SetEntry(weight: 40, reps: 8)] : const [],
      ),
    ],
  );
}

void main() {
  final t0 = DateTime(2026, 5, 14, 9);
  DateTime at(Duration gap) => t0.add(gap);
  IdleAction resolve(WorkoutSession s, Duration gap) =>
      WorkoutStorageService.resolveIdleAction(s, at(gap));

  test('inside the idle window → none', () {
    final s = _session(lastActivityAt: t0);
    expect(resolve(s, const Duration(minutes: 29)), IdleAction.none);
  });

  test('completed and paused sessions → none at any age', () {
    expect(
      resolve(_session(ongoing: false, lastActivityAt: t0), const Duration(days: 40)),
      IdleAction.none,
    );
    expect(
      resolve(_session(paused: true, lastActivityAt: t0), const Duration(days: 40)),
      IdleAction.none,
    );
  });

  test('idle-timed-out with work, inside the hard boundary → ask', () {
    final s = _session(lastActivityAt: t0);
    expect(resolve(s, const Duration(minutes: 30)), IdleAction.ask);
    expect(
      resolve(s, const Duration(hours: 11, minutes: 59)),
      IdleAction.ask,
    );
  });

  test('past the hard boundary with work → autoSave (banked, not asked)', () {
    final s = _session(lastActivityAt: t0);
    expect(resolve(s, const Duration(hours: 12)), IdleAction.autoSave);
    expect(resolve(s, const Duration(days: 32)), IdleAction.autoSave); // 765h
  });

  test('idle-timed-out with zero working sets → autoDiscard at any age', () {
    final s = _session(lastActivityAt: t0, withSet: false);
    expect(resolve(s, const Duration(minutes: 30)), IdleAction.autoDiscard);
    expect(resolve(s, const Duration(days: 32)), IdleAction.autoDiscard);
  });

  test('legacy null lastActivityAt anchors on startedAt (never immortal)', () {
    final s = _session(startedAt: t0);
    expect(resolve(s, const Duration(minutes: 29)), IdleAction.none);
    expect(resolve(s, const Duration(hours: 1)), IdleAction.ask);
    expect(resolve(s, const Duration(days: 32)), IdleAction.autoSave);
  });

  test('injectable thresholds override the production constants', () {
    final s = _session(lastActivityAt: t0);
    expect(
      WorkoutStorageService.resolveIdleAction(
        s,
        at(const Duration(seconds: 5)),
        idleTimeout: const Duration(seconds: 2),
        hardIdleTimeout: const Duration(seconds: 4),
      ),
      IdleAction.autoSave,
    );
  });

  test('clock skew: a FUTURE lastActivityAt falls back to startedAt', () {
    // Device clock changed / restored backup: without normalization the gap
    // goes negative and the net is blind until the future timestamp passes.
    final s = _session(
      startedAt: t0,
      lastActivityAt: t0.add(const Duration(days: 30)),
    );
    expect(resolve(s, const Duration(hours: 1)), IdleAction.ask);
    expect(resolve(s, const Duration(days: 2)), IdleAction.autoSave);
  });

  test('clock skew: a fully-future row resolves none (conservative)', () {
    final future = t0.add(const Duration(days: 30));
    final s = _session(startedAt: future, lastActivityAt: future);
    expect(resolve(s, const Duration(hours: 5)), IdleAction.none);
  });

  test('the service constants alias the model windows (no drift)', () {
    expect(WorkoutStorageService.idleTimeout, WorkoutSession.idleWindow);
    expect(
      WorkoutStorageService.hardIdleTimeout,
      WorkoutSession.hardIdleWindow,
    );
  });
}
