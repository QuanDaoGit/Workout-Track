import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/rest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to Monday Wednesday Friday training days', () async {
    final state = await RestService(
      nowProvider: () => DateTime(2026, 5, 14),
    ).loadState();

    expect(state.trainingWeekdays, {1, 3, 5});
  });

  test('pending schedule applies on the next Monday only', () async {
    final service = RestService(nowProvider: () => DateTime(2026, 5, 14));
    await service.saveTrainingWeekdays({2, 4, 6});

    final current = await service.loadState(now: DateTime(2026, 5, 14));
    expect(current.trainingWeekdays, {1, 3, 5});
    expect(current.pendingTrainingWeekdays, {2, 4, 6});
    expect(current.pendingStartWeekKey, '2026-05-18');

    final nextWeek = await service.loadState(now: DateTime(2026, 5, 18));
    expect(nextWeek.trainingWeekdays, {2, 4, 6});
    expect(nextWeek.pendingTrainingWeekdays, isNull);
  });

  test('reports planned rest and scheduled training status', () async {
    final service = RestService(nowProvider: () => DateTime(2026, 5, 12));
    final state = await service.loadState();

    final monday = service.dayInfoForState(
      day: DateTime(2026, 5, 11),
      sessions: const [],
      state: state,
      now: DateTime(2026, 5, 12),
    );
    final tuesday = service.dayInfoForState(
      day: DateTime(2026, 5, 12),
      sessions: const [],
      state: state,
      now: DateTime(2026, 5, 12),
    );

    expect(monday.kind, RestDayKind.unplannedMiss);
    expect(tuesday.kind, RestDayKind.plannedRest);
  });

  test('automatic recovery starts today-forward only', () async {
    final service = RestService(nowProvider: () => DateTime(2026, 5, 12));

    final state = await service.ensureAutomaticRecoveryForToday(
      sessions: const [],
      baseXP: 10000,
    );

    expect(state.autoRecoveryStartKey, '2026-05-12');
    expect(state.recoveryClaims.keys, ['2026-05-12']);
    expect(state.recoveryClaims.containsKey('2026-05-10'), isFalse);
  });

  test('planned rest auto-grants recovery once', () async {
    final service = RestService(nowProvider: () => DateTime(2026, 5, 12));

    await service.ensureAutomaticRecoveryForToday(
      sessions: const [],
      baseXP: 10000,
    );
    final second = await service.ensureAutomaticRecoveryForToday(
      sessions: const [],
      baseXP: 10000,
    );

    // Granted once per day (idempotent). Recovery XP = clamp(round(current
    // level's XP span × 0.02), 1, 40); at 10000 XP (level 31, span 671) → 13.
    expect(second.recoveryClaims.length, 1);
    expect(second.recoveryClaims['2026-05-12']?.xp, 13);
    expect(await service.effectiveRecoveryXP(const []), 13);
  });

  test('recovery reward is clamped to [1, 40]', () {
    expect(RestService.recoveryRewardXP(0), 1); // floor (tiny early span)
    expect(RestService.recoveryRewardXP(10000), 13); // 2% of a mid-level span
    expect(
      RestService.recoveryRewardXP(1000000),
      40,
    ); // cap binds only at extreme XP
  });

  test('completed workout on rest day replaces recovery XP', () async {
    final service = RestService(nowProvider: () => DateTime(2026, 5, 12));
    await service.ensureAutomaticRecoveryForToday(
      sessions: const [],
      baseXP: 0,
    );

    final sessions = [_session(date: DateTime(2026, 5, 12))];

    expect(await service.effectiveRecoveryXP(sessions), 0);
  });

  test(
    'old recovery records still count unless overridden by workout',
    () async {
      SharedPreferences.setMockInitialValues({
        RestService.stateKey: jsonEncode(
          RestState.defaults(currentWeekKey: '2026-05-11')
              .copyWith(
                autoRecoveryStartKey: '2026-05-16',
                recoveryClaims: {
                  '2026-05-12': RestRecoveryClaim(
                    xp: 7,
                    claimedAt: DateTime(2026, 5, 12),
                  ),
                },
              )
              .toJson(),
        ),
      });
      final service = RestService(nowProvider: () => DateTime(2026, 5, 16));

      expect(await service.effectiveRecoveryXP(const []), 7);
      expect(
        await service.effectiveRecoveryXP([
          _session(date: DateTime(2026, 5, 12)),
        ]),
        0,
      );
    },
  );

  test(
    'two consecutive successful weeks grant one shield up to max two',
    () async {
      final service = RestService(nowProvider: () => DateTime(2026, 6, 8));
      final sessions = [
        for (final day in [
          DateTime(2026, 5, 11),
          DateTime(2026, 5, 13),
          DateTime(2026, 5, 15),
          DateTime(2026, 5, 18),
          DateTime(2026, 5, 20),
          DateTime(2026, 5, 22),
          DateTime(2026, 5, 25),
          DateTime(2026, 5, 27),
          DateTime(2026, 5, 29),
          DateTime(2026, 6, 1),
          DateTime(2026, 6, 3),
          DateTime(2026, 6, 5),
        ])
          _session(date: day),
      ];

      final state = await service.refreshWeeklyShieldProgress(sessions);

      expect(state.shieldCharges, 2);
    },
  );

  test('failed weeks reset shield progress', () async {
    final service = RestService(nowProvider: () => DateTime(2026, 5, 25));
    final sessions = [
      _session(date: DateTime(2026, 5, 11)),
      _session(date: DateTime(2026, 5, 13)),
      _session(date: DateTime(2026, 5, 15)),
      _session(date: DateTime(2026, 5, 20)),
      _session(date: DateTime(2026, 5, 22)),
    ];

    final state = await service.refreshWeeklyShieldProgress(sessions);

    expect(state.shieldCharges, 0);
    expect(state.consecutiveSuccessfulWeeks, 0);
  });

  test('shield protects one missed training day', () async {
    final now = DateTime(2026, 5, 14);
    SharedPreferences.setMockInitialValues({
      RestService.stateKey: jsonEncode(
        RestState.defaults(
          currentWeekKey: RestService.weekKey(now),
        ).copyWith(shieldCharges: 1).toJson(),
      ),
    });
    final service = RestService(nowProvider: () => now);
    final result = await service.applyShieldsForMissedTrainingDays(
      sessions: [_session(date: DateTime(2026, 5, 8))],
      since: DateTime(2026, 5, 8),
    );

    expect(result.protectedCount, 1);
    expect(result.unprotectedMissedDates, [DateTime(2026, 5, 13)]);
    expect(result.state.shieldCharges, 0);
    expect(result.state.protectedMissDateKeys, contains('2026-05-11'));
  });

  group('consistencyWeeks (weekly LCK)', () {
    final service = RestService();
    final state = RestState.defaults(); // default schedule: Mon / Wed / Fri
    final now = DateTime(2026, 6, 1, 9); // a Monday

    test('no completed history → 0', () {
      expect(
        service.consistencyWeeks(sessions: const [], state: state, now: now),
        0,
      );
    });

    test('first workout today → 0 (no full 7-day block yet)', () {
      expect(
        service.consistencyWeeks(
          sessions: [_session(date: now)],
          state: state,
          now: now,
        ),
        0,
      );
    });

    test('three perfectly-adherent M/W/F weeks → 3', () {
      final sessions = _scheduledThrough(
        from: DateTime(2026, 5, 11),
        untilExclusive: now,
      );
      expect(
        service.consistencyWeeks(sessions: sessions, state: state, now: now),
        3,
      );
    });

    test('an unprotected missed scheduled day resets to 0', () {
      // Drop the most recent scheduled Friday (05-29) → unscheduled recovery.
      final sessions = _scheduledThrough(
        from: DateTime(2026, 5, 11),
        untilExclusive: DateTime(2026, 5, 29),
      );
      expect(
        service.consistencyWeeks(sessions: sessions, state: state, now: now),
        0,
      );
    });

    test('a shielded miss does not reset the streak', () {
      final sessions = _scheduledThrough(
        from: DateTime(2026, 5, 11),
        untilExclusive: DateTime(2026, 5, 29),
      );
      final shielded = state.copyWith(
        protectedMissDateKeys: {RestService.dateKey(DateTime(2026, 5, 29))},
      );
      expect(
        service.consistencyWeeks(sessions: sessions, state: shielded, now: now),
        3,
      );
    });

    test('long gaps on non-scheduled days do not reset', () {
      // Mon-only schedule: the six non-scheduled days between Mondays are never
      // misses, so a sparse-but-adherent history still accrues weeks.
      final monOnly = state.copyWith(trainingWeekdays: {1});
      final sessions = [
        _session(date: DateTime(2026, 5, 11, 10)),
        _session(date: DateTime(2026, 5, 18, 10)),
        _session(date: DateTime(2026, 5, 25, 10)),
      ];
      expect(
        service.consistencyWeeks(sessions: sessions, state: monOnly, now: now),
        3,
      );
    });
  });
}

/// Seeds a completed session on every scheduled [weekdays] day in
/// `[from, untilExclusive)`.
List<WorkoutSession> _scheduledThrough({
  required DateTime from,
  required DateTime untilExclusive,
  Set<int> weekdays = const {1, 3, 5},
}) {
  final out = <WorkoutSession>[];
  var day = DateTime(from.year, from.month, from.day);
  final end = DateTime(
    untilExclusive.year,
    untilExclusive.month,
    untilExclusive.day,
  );
  while (day.isBefore(end)) {
    if (weekdays.contains(day.weekday)) {
      out.add(_session(date: day.add(const Duration(hours: 10))));
    }
    day = day.add(const Duration(days: 1));
  }
  return out;
}

WorkoutSession _session({required DateTime date}) {
  return WorkoutSession(
    id: date.microsecondsSinceEpoch.toString(),
    date: date,
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: const [
      ExerciseLog(
        exerciseId: 'bench',
        exerciseName: 'Bench Press',
        sets: [SetEntry(weight: 50, reps: 5)],
      ),
    ],
    estimatedCalories: 100,
  );
}
