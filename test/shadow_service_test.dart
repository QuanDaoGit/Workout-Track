import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/shadow_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/loot_service.dart';
import 'package:workout_track/services/shadow_service.dart';
import 'package:workout_track/services/stat_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fixed "today" for every test (a Friday).
  final now = DateTime(2026, 6, 12, 18);

  const catalog = {'bench': 'chest', 'ohp': 'shoulders', 'squat': 'quadriceps'};

  WorkoutSession session(
    String id,
    DateTime date, {
    double weight = 60,
    int reps = 8,
    int sets = 3,
  }) {
    return WorkoutSession(
      id: id,
      date: date,
      muscleGroup: 'Full Body',
      targetDurationMinutes: 45,
      actualDurationSeconds: 2700,
      estimatedCalories: 200,
      exercises: [
        for (final exerciseId in catalog.keys)
          ExerciseLog(
            exerciseId: exerciseId,
            exerciseName: exerciseId,
            sets: [
              for (var i = 0; i < sets; i++)
                SetEntry(weight: weight, reps: reps),
            ],
          ),
      ],
    );
  }

  /// Sessions every [gapDays] going back from [daysAgoStart], identical
  /// content unless [weightAt] overrides per-index.
  List<WorkoutSession> cadence({
    required int count,
    required int gapDays,
    int daysAgoStart = 1,
    double Function(int index)? weightAt,
  }) {
    return [
      for (var i = 0; i < count; i++)
        session(
          's$i',
          now.subtract(Duration(days: daysAgoStart + i * gapDays)),
          weight: weightAt?.call(i) ?? 60,
        ),
    ];
  }

  Future<void> seed(List<WorkoutSession> sessions) async {
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode(sessions.map((s) => s.toJson()).toList()),
    });
  }

  ShadowService service({DateTime? at}) => ShadowService(
    nowProvider: () => at ?? now,
    statEngine: StatEngine(catalog: catalog, nowProvider: () => at ?? now),
  );

  group('cold start and sufficiency', () {
    test('under 6 completed sessions is locked', () async {
      await seed(cadence(count: 3, gapDays: 3));
      final eval = await service().evaluate();
      expect(eval.status, ShadowStatus.locked);
      expect(eval.completedSessions, 3);
      expect(eval.axes, isEmpty);
    });

    test('6 sessions all inside the acute window is forming (no chronic '
        'baseline yet)', () async {
      await seed(cadence(count: 6, gapDays: 1));
      final eval = await service().evaluate();
      expect(eval.status, ShadowStatus.forming);
    });

    test('partial and abandoned sessions never count', () async {
      final real = cadence(count: 5, gapDays: 3);
      final ghosts = [
        WorkoutSession(
          id: 'partial',
          date: now.subtract(const Duration(days: 2)),
          muscleGroup: 'Chest',
          targetDurationMinutes: 45,
          actualDurationSeconds: 100,
          estimatedCalories: 10,
          exercises: const [],
          isPartial: true,
        ),
        WorkoutSession(
          id: 'abandoned',
          date: now.subtract(const Duration(days: 3)),
          muscleGroup: 'Chest',
          targetDurationMinutes: 45,
          actualDurationSeconds: 100,
          estimatedCalories: 10,
          exercises: const [],
          isPartial: true,
          isAbandoned: true,
        ),
      ];
      await seed([...real, ...ghosts]);
      final eval = await service().evaluate();
      expect(eval.status, ShadowStatus.locked); // 5 real < 6
    });
  });

  group('consistent veteran (mature, steady cadence)', () {
    test('steady training is never scored behind', () async {
      // Every 3 days for 14 sessions (~6 weeks of history).
      await seed(cadence(count: 14, gapDays: 3));
      final eval = await service().evaluate();
      expect(eval.status, isNot(ShadowStatus.locked));
      expect(eval.status, isNot(ShadowStatus.forming));
      expect(eval.provisional, isFalse);
      for (final axis in eval.axes) {
        expect(
          axis.state,
          anyOf(ShadowAxisState.ahead, ShadowAxisState.close),
          reason:
              'steady cadence must read ahead/close, got ${axis.state} '
              'for ${axis.axis} (r=${axis.ratio})',
        );
      }
    });

    test(
      'progressive overload defeats the Shadow and earns the title once',
      () async {
        // Recent sessions denser AND heavier than the chronic month (density
        // lifts the rep-based END axis; load lifts STR/AGI).
        final sessions = [
          // Acute: 4 sessions inside the 10-day window, heavier.
          for (var i = 0; i < 4; i++)
            session('a$i', now.subtract(Duration(days: 1 + i * 2)), weight: 70),
          // Chronic: 9 sessions in the prior month, lighter.
          for (var i = 0; i < 9; i++)
            session(
              'c$i',
              now.subtract(Duration(days: 12 + i * 3)),
              weight: 60,
            ),
        ];
        await seed(sessions);
        final eval = await service().evaluate();
        expect(eval.status, ShadowStatus.defeated);
        expect(eval.titleEarnedNow, isTrue);
        expect(eval.titleEarned, isTrue);

        final owned = await LootService().getInventory();
        final ownedIds = owned.map((i) => i.id).toSet();
        expect(ownedIds, contains(ShadowService.titleLootId));
        expect(ownedIds, contains(ShadowService.frameLootId));

        // Reward idempotency: a second evaluation never re-grants.
        final again = await service().evaluate();
        expect(again.status, ShadowStatus.defeated);
        expect(again.titleEarnedNow, isFalse);
        expect(again.titleEarned, isTrue);
      },
    );
  });

  group('provisional shadow (6–11 sessions)', () {
    test('defeat while provisional never awards the title', () async {
      final sessions = [
        for (var i = 0; i < 3; i++)
          session('a$i', now.subtract(Duration(days: 1 + i * 3)), weight: 80),
        for (var i = 0; i < 4; i++)
          session('c$i', now.subtract(Duration(days: 12 + i * 6)), weight: 60),
      ];
      await seed(sessions); // 7 completed sessions
      final eval = await service().evaluate();
      expect(eval.provisional, isTrue);
      expect(eval.titleEarnedNow, isFalse);
      final owned = await LootService().getInventory();
      expect(
        owned.map((i) => i.id),
        isNot(contains(ShadowService.titleLootId)),
      );
    });
  });

  group('slipper and the faded floor (anti under-training)', () {
    test('no recent training reads behind with a no-work reason', () async {
      // 12 strong sessions, all 12+ days ago; nothing acute.
      await seed(cadence(count: 12, gapDays: 2, daysAgoStart: 12));
      final eval = await service().evaluate();
      expect(eval.status, ShadowStatus.contest);
      expect(eval.headline, isNotNull);
      for (final axis in eval.axes) {
        if (axis.state == ShadowAxisState.forming) continue;
        expect(axis.state, ShadowAxisState.behind);
        expect(axis.reason, contains('NO'));
      }
    });

    test('resting away the baseline then training again gives no reward '
        '(faded)', () async {
      // Phase 1: strong steady month — sets the high-water.
      final strong = cadence(count: 14, gapDays: 3, daysAgoStart: 1);
      await seed(strong);
      await service().evaluate();

      // Phase 2: ~5 weeks later — the strong month rolled out of chronic;
      // chronic is now 3 thin sessions, acute is 3 heavy ones. The ratio
      // says "defeated" but the high-water floor says faded → no title.
      final later = now.add(const Duration(days: 36));
      final thin = [
        for (var i = 0; i < 3; i++)
          session(
            'thin$i',
            later.subtract(Duration(days: 12 + i * 8)),
            weight: 20,
            sets: 1,
          ),
        for (var i = 0; i < 3; i++)
          session(
            'back$i',
            later.subtract(Duration(days: 1 + i * 3)),
            weight: 40,
          ),
      ];
      final prefs = await SharedPreferences.getInstance();
      final shadowState = prefs.getString(ShadowService.stateKey);
      SharedPreferences.setMockInitialValues({
        'workout_sessions': jsonEncode(
          [...strong, ...thin].map((s) => s.toJson()).toList(),
        ),
        ShadowService.stateKey: ?shadowState,
      });

      final eval = await service(at: later).evaluate();
      expect(eval.status, ShadowStatus.faded);
      expect(eval.titleEarnedNow, isFalse);
      final owned = await LootService().getInventory();
      expect(
        owned.map((i) => i.id),
        isNot(contains(ShadowService.titleLootId)),
      );
    });
  });

  group('sparse trainer (1–2 sessions/week)', () {
    test('twice-a-week lifter gets a live, sane contest', () async {
      // Every 4 days, 10 sessions (~6 weeks).
      await seed(cadence(count: 10, gapDays: 4));
      final eval = await service().evaluate();
      expect(eval.status, isNot(ShadowStatus.locked));
      expect(eval.status, isNot(ShadowStatus.forming));
      for (final axis in eval.axes) {
        if (axis.ratio == null) continue;
        expect(axis.ratio, greaterThan(0));
        expect(axis.ratio, lessThan(3), reason: 'no degenerate explosions');
      }
    });
  });

  group('noise and clock edge cases', () {
    test('one huge session is dampened by the rate window', () async {
      final sessions = [
        session('huge', now.subtract(const Duration(days: 1)), weight: 200),
        for (var i = 0; i < 12; i++)
          session('c$i', now.subtract(Duration(days: 5 + i * 3))),
      ];
      await seed(sessions);
      final eval = await service().evaluate();
      // One 3.3x-weight session in a 10-day window can lead, but the service
      // must stay coherent — and the render clamp handles the polygon.
      expect(eval.status, isNot(ShadowStatus.locked));
      expect(() => eval.axes, returnsNormally);
    });

    test(
      'clock rollback cannot duplicate the reward or corrupt state',
      () async {
        final sessions = [
          for (var i = 0; i < 4; i++)
            session('a$i', now.subtract(Duration(days: 1 + i * 2)), weight: 70),
          for (var i = 0; i < 9; i++)
            session(
              'c$i',
              now.subtract(Duration(days: 12 + i * 3)),
              weight: 60,
            ),
        ];
        await seed(sessions);
        final first = await service().evaluate();
        expect(first.titleEarnedNow, isTrue);

        // Device clock jumps back a week: evaluation anchors to the latest
        // session date, not the wall clock.
        final rolledBack = await service(
          at: now.subtract(const Duration(days: 7)),
        ).evaluate();
        expect(rolledBack.titleEarnedNow, isFalse);
        expect(rolledBack.titleEarned, isTrue);
        expect(() => rolledBack.axes, returnsNormally);
      },
    );

    test('week rollover swaps the gap-closing baseline idempotently', () async {
      // Behind in week 1.
      final base = cadence(count: 12, gapDays: 3, daysAgoStart: 8);
      await seed(base);
      final week1 = await service().evaluate();
      expect(week1.status, ShadowStatus.contest);

      // Week 2: training resumed — ratios improve.
      final week2Now = now.add(const Duration(days: 7));
      final resumed = [
        ...base,
        session('r1', week2Now.subtract(const Duration(days: 1))),
        session('r2', week2Now.subtract(const Duration(days: 3))),
      ];
      final prefs = await SharedPreferences.getInstance();
      final shadowState = prefs.getString(ShadowService.stateKey);
      SharedPreferences.setMockInitialValues({
        'workout_sessions': jsonEncode(resumed.map((s) => s.toJson()).toList()),
        ShadowService.stateKey: ?shadowState,
      });
      final week2 = await service(at: week2Now).evaluate();
      // Re-running the same week is idempotent.
      final week2Again = await service(at: week2Now).evaluate();
      expect(week2.status, week2Again.status);
      expect(week2.gapClosing, week2Again.gapClosing);
    });
  });

  group('defensive persistence', () {
    test('malformed stored state falls back cleanly and never touches the '
        'board', () async {
      final sessions = cadence(count: 14, gapDays: 3);
      SharedPreferences.setMockInitialValues({
        'workout_sessions': jsonEncode(
          sessions.map((s) => s.toJson()).toList(),
        ),
        ShadowService.stateKey: '{not valid json',
        'combat_stats': '{"STR":123,"AGI":45,"END":67}',
      });
      final eval = await service().evaluate();
      expect(eval.status, isNot(ShadowStatus.locked));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('combat_stats'),
        '{"STR":123,"AGI":45,"END":67}',
        reason: 'Shadow evaluation must never mutate board stats',
      );
    });

    test('wrong-shape stored state decodes per-field without throwing', () {
      final state = ShadowState.fromJson({
        'version': 'nope',
        'highWater': ['not', 'a', 'map'],
        'lastWeekMeanRatio': 'NaN-ish',
        'firstDefeatAtIso': 42,
      });
      expect(state.version, ShadowState.currentVersion);
      expect(state.highWater, isEmpty);
      expect(state.lastWeekMeanRatio, isNull);
      expect(state.firstDefeatAtIso, isNull);
    });
  });

  group('linear currency (Codex finding: never log-curved)', () {
    test('sessionAxisLoads returns linear per-session credits', () async {
      final engine = StatEngine(catalog: catalog, nowProvider: () => now);
      final light = session('l', now, weight: 50);
      final heavy = session('h', now, weight: 100);
      final loads = await engine.sessionAxisLoads([light, heavy]);
      expect(loads, hasLength(2));
      final lightLoad = loads.firstWhere((l) => l.sessionId == 'l');
      final heavyLoad = loads.firstWhere((l) => l.sessionId == 'h');
      // Linear: double the load (same reps) = exactly double the credit.
      expect(heavyLoad.str, closeTo(lightLoad.str * 2, 0.001));
      expect(heavyLoad.agi, closeTo(lightLoad.agi * 2, 0.001));
    });
  });
}
