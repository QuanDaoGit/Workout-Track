import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/adventure_routes.dart';
import 'package:workout_track/models/adventure_models.dart';
import 'package:workout_track/models/gem_ledger_entry.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/adventure_service.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/stat_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 6, 12, 18); // Friday

  const catalog = {'bench': 'chest'};

  WorkoutSession session(String id, DateTime date, {int sets = 3}) {
    return WorkoutSession(
      id: id,
      date: date,
      muscleGroup: 'Chest',
      targetDurationMinutes: 45,
      actualDurationSeconds: 2700,
      estimatedCalories: 200,
      exercises: [
        ExerciseLog(
          exerciseId: 'bench',
          exerciseName: 'bench',
          sets: [
            for (var i = 0; i < sets; i++) const SetEntry(weight: 60, reps: 8),
          ],
        ),
      ],
    );
  }

  AdventureService service({DateTime? at, String boot = 'boot-A'}) =>
      AdventureService(
        nowProvider: () => at ?? now,
        statEngine: StatEngine(catalog: catalog, nowProvider: () => at ?? now),
        bootIdOverride: boot,
      );

  Future<AdventureState> storedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AdventureService.stateKey);
    return AdventureState.fromJson(
      raw == null ? null : jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('dispatch eligibility', () {
    test('first completed workout of the day dispatches', () async {
      await service().dispatchForSession(session('s1', now));
      final state = await storedState();
      expect(state.pending, isNotNull);
      expect(state.weekCount, 1);
      expect(state.lastDispatchDay, '2026-06-12');
      // Default standing order resolved (class default).
      expect(state.standingOrderRouteId, isNotNull);
    });

    test('second same-day save does not re-dispatch', () async {
      final svc = service();
      await svc.dispatchForSession(session('s1', now));
      await svc.dispatchForSession(
        session('s2', now.add(const Duration(hours: 2))),
      );
      final state = await storedState();
      expect(state.weekCount, 1);
      expect(state.pending!.id, contains('s1'));
    });

    test('partial, abandoned, and empty sessions never dispatch', () async {
      final svc = service();
      await svc.dispatchForSession(
        WorkoutSession(
          id: 'p',
          date: now,
          muscleGroup: 'Chest',
          targetDurationMinutes: 45,
          actualDurationSeconds: 100,
          estimatedCalories: 10,
          exercises: const [],
          isPartial: true,
        ),
      );
      await svc.dispatchForSession(session('empty', now, sets: 0));
      final state = await storedState();
      expect(state.pending, isNull);
      expect(state.weekCount, 0);
    });

    test('weekly cap of 5 holds and resets on a new ISO week', () async {
      // 5 dispatches Mon-Fri (resolve pending across days via day boundary).
      for (var day = 8; day <= 12; day++) {
        final at = DateTime(2026, 6, day, 18);
        await service(at: at).dispatchForSession(session('d$day', at));
      }
      var state = await storedState();
      expect(state.weekCount, 5);

      // Saturday: capped.
      final sat = DateTime(2026, 6, 13, 10);
      await service(at: sat).dispatchForSession(session('sat', sat));
      state = await storedState();
      expect(state.weekCount, 5);
      expect(state.lastDispatchDay, isNot('2026-06-13'));

      // Monday next week: resets.
      final mon = DateTime(2026, 6, 15, 10);
      await service(at: mon).dispatchForSession(session('mon', mon));
      state = await storedState();
      expect(state.weekCount, 1);
      expect(state.lastDispatchDay, '2026-06-15');
    });

    test('clock rollback cannot earn a second dispatch (max anchor)', () async {
      await service().dispatchForSession(session('s1', now));
      // Settle the pending so it can't be the blocker, then roll back a day.
      final yesterday = now.subtract(const Duration(days: 1));
      await service(at: yesterday, boot: 'boot-B').settleAndPeekReport();
      await service(
        at: yesterday,
        boot: 'boot-B',
      ).dispatchForSession(session('rollback', yesterday));
      final state = await storedState();
      // Anchored "today" is still 2026-06-12 — same day, no new dispatch.
      expect(state.pending, isNull);
      expect(state.weekCount, 1);
    });
  });

  group('settlement and reveal', () {
    test('pending is not revealable in the dispatching sitting', () async {
      final svc = service();
      await svc.dispatchForSession(session('s1', now));
      final report = await svc.settleAndPeekReport();
      expect(report, isNull);
      expect((await storedState()).pending, isNotNull);
    });

    test(
      'process restart settles, awards gems once, reveals once after ack',
      () async {
        await service(boot: 'boot-A').dispatchForSession(session('s1', now));
        final pendingPayout = (await storedState()).pending!.payout;

        final reopened = service(boot: 'boot-B');
        final report = await reopened.settleAndPeekReport();
        expect(report, isNotNull);
        expect(report!.expedition.payout, pendingPayout);
        expect(report.classDefaultOrders, isTrue);

        expect(await GemService().balance(), pendingPayout);
        final ledger = await GemService().ledger();
        expect(ledger.single.sourceKind, GemLedgerSourceKind.adventure);

        // Acknowledge (ceremony shown) → no longer revealable; no re-award.
        await reopened.acknowledgeReport(report.expedition.id);
        final again = await reopened.settleAndPeekReport();
        expect(again, isNull);
        expect(await GemService().balance(), pendingPayout);

        final state = await storedState();
        expect(state.pending, isNull);
        expect(state.history.single.viewed, isTrue);
      },
    );

    test('day boundary makes the same-boot pending revealable', () async {
      final svc = service();
      await svc.dispatchForSession(session('s1', now));
      final tomorrow = now.add(const Duration(days: 1));
      final report = await service(
        at: tomorrow,
        boot: 'boot-A',
      ).settleAndPeekReport();
      expect(report, isNotNull);
    });

    test('single-flight: concurrent settles award exactly once', () async {
      await service(boot: 'boot-A').dispatchForSession(session('s1', now));
      final reopened = service(boot: 'boot-B');
      final results = await Future.wait([
        reopened.settleAndPeekReport(),
        reopened.settleAndPeekReport(),
        reopened.settleAndPeekReport(),
      ]);
      // Peek is non-consuming, so all three see the same unviewed report —
      // the money invariant is that settlement awarded EXACTLY ONCE.
      final reports = results.whereType<ExpeditionReport>().toList();
      expect(reports, hasLength(3));
      expect(reports.map((r) => r.expedition.id).toSet(), hasLength(1));
      expect((await GemService().ledger()), hasLength(1));
      expect(
        await GemService().balance(),
        (await storedState()).history.single.payout,
      );
    });

    test('peek without acknowledge never burns the ceremony (Codex)', () async {
      await service(boot: 'boot-A').dispatchForSession(session('s1', now));
      final reopened = service(boot: 'boot-B');

      // Home takes the report but bails before showing it (route not current).
      final first = await reopened.settleAndPeekReport();
      expect(first, isNotNull);
      expect((await storedState()).history.single.viewed, isFalse);

      // Next valid open still finds the same unviewed report.
      final second = await reopened.settleAndPeekReport();
      expect(second!.expedition.id, first!.expedition.id);

      // Only acknowledge consumes it (idempotent).
      await reopened.acknowledgeReport(first.expedition.id);
      await reopened.acknowledgeReport(first.expedition.id);
      expect((await storedState()).history.single.viewed, isTrue);
      expect(await reopened.settleAndPeekReport(), isNull);
      // Gems were awarded exactly once across all of the above.
      expect((await GemService().ledger()), hasLength(1));
    });

    test(
      'settle-before-dispatch: a revealable pending never costs the day',
      () async {
        // Day 1: dispatch.
        await service(boot: 'boot-A').dispatchForSession(session('s1', now));
        // Day 2, new boot: the user trains BEFORE any Home reveal ran.
        final day2 = now.add(const Duration(days: 1));
        await service(
          at: day2,
          boot: 'boot-B',
        ).dispatchForSession(session('s2', day2));
        final state = await storedState();
        // Old expedition settled to history; new one dispatched today.
        expect(state.history, hasLength(1));
        expect(state.pending, isNotNull);
        expect(state.pending!.day, '2026-06-13');
        expect(state.weekCount, 2);
        // Settled gems already in the ledger; report still unviewed.
        expect(await GemService().balance(), state.history.single.payout);
        expect(state.history.single.viewed, isFalse);
      },
    );
  });

  group('payout integrity', () {
    test('payout is rolled at dispatch within the rank band and never '
        'rerolled', () async {
      await service().dispatchForSession(session('s1', now));
      final state = await storedState();
      final pending = state.pending!;
      final base = AdventureService.basePayoutForRank(pending.rank);
      expect(pending.payout, greaterThanOrEqualTo((base * 0.7).round() - 1));
      expect(pending.payout, lessThanOrEqualTo((base * 1.3).round() + 1));

      // Settle on a different boot: awarded amount == stored roll.
      final report = await service(boot: 'boot-B').settleAndPeekReport();
      expect(report!.expedition.payout, pending.payout);
    });

    test('new user dispatches at D-rank base', () async {
      await service().dispatchForSession(session('s1', now));
      final pending = (await storedState()).pending!;
      expect(pending.rank, 'D');
      expect(AdventureService.basePayoutForRank(pending.rank), 8);
    });

    test('award is idempotent by expedition id at the ledger', () async {
      final gems = GemService();
      final first = await gems.awardAdventureGems(
        expeditionId: 'exp_x',
        amount: 12,
        label: 'test',
      );
      final second = await gems.awardAdventureGems(
        expeditionId: 'exp_x',
        amount: 12,
        label: 'test',
      );
      expect(first, 12);
      expect(second, 0);
      expect(await gems.balance(), 12);
    });
  });

  group('orders', () {
    test('setStandingOrder confirms orders and later reports drop the '
        'class-default flag', () async {
      await AdventureService().setStandingOrder('infini_maze');
      await service().dispatchForSession(session('s1', now));
      final state = await storedState();
      expect(state.standingOrderRouteId, 'infini_maze');
      expect(state.ordersConfirmed, isTrue);
      final report = await service(boot: 'boot-B').settleAndPeekReport();
      expect(report!.classDefaultOrders, isFalse);
      expect(report.expedition.routeId, 'infini_maze');
    });

    test('unknown stored route id falls back to a real route', () {
      expect(adventureRouteById('nope').id, adventureRoutes.first.id);
    });
  });

  group('defensive persistence', () {
    test(
      'default constructor loads fresh state without a boot override',
      () async {
        expect(() => AdventureService(), returnsNormally);

        final state = await AdventureService().loadState();
        expect(state.pending, isNull);
        expect(state.history, isEmpty);
      },
    );

    test('malformed state decodes fresh and never throws', () async {
      SharedPreferences.setMockInitialValues({
        AdventureService.stateKey: '{not valid json',
      });
      final state = await AdventureService().loadState();
      expect(state.pending, isNull);
      expect(state.history, isEmpty);
      await service().dispatchForSession(session('s1', now));
      expect((await storedState()).pending, isNotNull);
    });

    test('malformed expedition records are dropped, not fatal', () {
      final state = AdventureState.fromJson({
        'version': 1,
        'history': [
          {'id': 'good', 'routeId': 'iron_vault', 'day': '2026-06-01'},
          {'id': 42},
          'garbage',
        ],
        'pending': {'noId': true},
      });
      expect(state.history, hasLength(1));
      expect(state.pending, isNull);
    });

    test('history is capped', () async {
      // Seed a state with a full history, then settle one more.
      final history = [
        for (var i = 0; i < AdventureService.historyCap; i++)
          Expedition(
            id: 'old$i',
            routeId: 'iron_vault',
            day: '2026-05-01',
            bootId: 'boot-old',
            rank: 'D',
            payout: 8,
            flavorIdx: 0,
            settledAtIso: '2026-05-01T10:00:00',
            viewed: true,
          ),
      ];
      SharedPreferences.setMockInitialValues({
        AdventureService.stateKey: jsonEncode(
          AdventureState(history: history).toJson(),
        ),
      });
      await service(boot: 'boot-A').dispatchForSession(session('s1', now));
      await service(boot: 'boot-B').settleAndPeekReport();
      final state = await storedState();
      expect(state.history.length, AdventureService.historyCap);
      expect(state.history.first.id, contains('s1'));
    });

    test(
      'adventure flows never touch board stats or workout history',
      () async {
        // Realistic fixture: dispatch always follows a session save, so
        // history exists and the rank read takes StatEngine's cached path.
        final sessionsRaw = jsonEncode([session('h', now).toJson()]);
        SharedPreferences.setMockInitialValues({
          'combat_stats': '{"STR":250,"AGI":80,"END":120,"VIT":50,"LCK":2}',
          'workout_sessions': sessionsRaw,
        });
        await service(boot: 'boot-A').dispatchForSession(session('s1', now));
        await service(boot: 'boot-B').settleAndPeekReport();
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('combat_stats'),
          '{"STR":250,"AGI":80,"END":120,"VIT":50,"LCK":2}',
        );
        expect(prefs.getString('workout_sessions'), sessionsRaw);
      },
    );

    test('rank captured at dispatch uses the stored board', () async {
      SharedPreferences.setMockInitialValues({
        'combat_stats': '{"STR":350,"AGI":80,"END":120,"VIT":50,"LCK":2}',
        'workout_sessions': jsonEncode([session('h', now).toJson()]),
      });
      await AdventureService(
        nowProvider: () => now,
        statEngine: StatEngine(catalog: catalog, nowProvider: () => now),
        bootIdOverride: 'boot-A',
      ).setStandingOrder('iron_vault');
      await service().dispatchForSession(session('s1', now));
      final pending = (await storedState()).pending!;
      expect(pending.rank, 'B'); // STR 350 → B (300-599)
      expect(AdventureService.basePayoutForRank('B'), 18);
    });
  });

  // Regression guard for the Home-loader incident (2026-06-13): the default
  // constructor — the path production (and Home) actually uses — once threw
  // during static `bootId` init (`Random().nextInt(1 << 32)` → `nextInt(0)`
  // on web). Every other test injects `bootIdOverride`, so the real path was
  // uncovered. The VM can't reproduce the web int-overflow itself (JS int
  // semantics), so the user-facing guard is Home's fail-soft load; this group
  // covers the constructor/`bootId` flow the VM *can* exercise.
  group('default-constructor path (no bootIdOverride)', () {
    test('static bootId is a usable non-empty id', () {
      expect(AdventureService.bootId, isNotEmpty);
    });

    test('default-constructed service constructs and dispatches', () async {
      final svc = AdventureService(
        nowProvider: () => now,
        statEngine: StatEngine(catalog: catalog, nowProvider: () => now),
      );
      await svc.dispatchForSession(session('s1', now));
      final state = await storedState();
      expect(state.pending, isNotNull);
      // Same process bootId → the report is not revealable in this sitting.
      final report = await svc.settleAndPeekReport();
      expect(report, isNull);
      expect((await storedState()).pending, isNotNull);
    });
  });
}
