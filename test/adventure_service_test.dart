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

/// A StatEngine whose stored-stats read always throws — used to prove the
/// single-flight queue recovers after a failed mutation (Codex plan finding #1).
class _BoomEngine extends StatEngine {
  _BoomEngine() : super();

  @override
  Future<Map<String, int>> getStoredStats() async =>
      throw StateError('boom');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 6, 12, 18); // Friday

  const catalog = {'bench': 'chest'};

  WorkoutSession session(
    String id,
    DateTime date, {
    int sets = 3,
    bool partial = false,
    bool abandoned = false,
  }) {
    return WorkoutSession(
      id: id,
      date: date,
      muscleGroup: 'Chest',
      targetDurationMinutes: 45,
      actualDurationSeconds: 2700,
      estimatedCalories: 200,
      isPartial: partial,
      isAbandoned: abandoned,
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

  /// Earns one charge then dispatches it on [routeId]; returns the expedition.
  Future<Expedition> earnAndDispatch(
    String routeId, {
    DateTime? at,
  }) async {
    final svc = service(at: at);
    await svc.grantChargeForSession(session('w', at ?? now));
    final e = await svc.dispatchExpedition(routeId);
    return e!;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VIT mapping', () {
    // VIT floors at 10 (docs/stats-mechanics.md), so the real domain is
    // [10,100] → [4h,8h] / [1.0×,1.4×].
    test('durationForVit spans 4h–8h across VIT [10,100], monotonic, clamped',
        () {
      expect(AdventureService.durationForVit(10), 240); // floor → 4h
      expect(AdventureService.durationForVit(100), 480); // 8h
      expect(AdventureService.durationForVit(55), 360); // midpoint → 6h
      expect(AdventureService.durationForVit(0), 240); // clamp to floor
      expect(AdventureService.durationForVit(250), 480); // clamp high
      expect(
        AdventureService.durationForVit(75),
        greaterThan(AdventureService.durationForVit(25)),
      );
    });

    test('multiplierForVit spans 1.0–1.4 across VIT [10,100], monotonic, '
        'clamped', () {
      expect(AdventureService.multiplierForVit(10), 1.0); // floor
      expect(AdventureService.multiplierForVit(100), closeTo(1.4, 1e-9));
      expect(AdventureService.multiplierForVit(55), closeTo(1.2, 1e-9));
      expect(AdventureService.multiplierForVit(0), 1.0); // clamp to floor
      expect(AdventureService.multiplierForVit(180), closeTo(1.4, 1e-9));
    });
  });

  group('charge grant', () {
    test('a qualifying workout grants exactly one charge (never dispatches)',
        () async {
      await service().grantChargeForSession(session('w', now));
      final s = await storedState();
      expect(s.charges, 1);
      expect(s.lastChargeDay, '2026-06-12');
      expect(s.pending, isNull);
    });

    test('at most one charge per day (max-anchored)', () async {
      final svc = service();
      await svc.grantChargeForSession(session('w1', now));
      await svc.grantChargeForSession(
        session('w2', now.add(const Duration(hours: 3))),
      );
      expect((await storedState()).charges, 1);
    });

    test('charges bank up to the cap of 3', () async {
      for (var day = 9; day <= 13; day++) {
        final at = DateTime(2026, 6, day, 18);
        await service(at: at).grantChargeForSession(session('w$day', at));
      }
      expect((await storedState()).charges, AdventureState.chargeCap);
    });

    test('partial, abandoned, and empty sessions grant nothing', () async {
      final svc = service();
      await svc.grantChargeForSession(session('p', now, partial: true));
      await svc.grantChargeForSession(session('a', now, abandoned: true));
      await svc.grantChargeForSession(session('empty', now, sets: 0));
      expect((await storedState()).charges, 0);
    });

    test('clock rollback cannot re-earn a charge for the same day', () async {
      await service().grantChargeForSession(session('w', now)); // day 06-12
      final yesterday = now.subtract(const Duration(days: 1));
      await service(
        at: yesterday,
      ).grantChargeForSession(session('rb', yesterday));
      expect((await storedState()).charges, 1); // anchored day still 06-12
    });
  });

  group('manual dispatch', () {
    test('spends a charge and sends one expedition out with frozen timing',
        () async {
      final svc = service();
      await svc.grantChargeForSession(session('w', now));
      final e = await svc.dispatchExpedition('iron_vault');
      expect(e, isNotNull);

      final s = await storedState();
      expect(s.charges, 0);
      expect(s.pending!.id, e!.id);
      expect(s.weekCount, 1);
      expect(s.standingOrderRouteId, 'iron_vault');
      expect(s.ordersConfirmed, isTrue);

      // Timing + multiplier are derived from the captured VIT and frozen.
      final dispatchedAt = DateTime.parse(e.dispatchedAtIso!);
      final returnsAt = DateTime.parse(e.returnsAtIso!);
      expect(e.durationMinutes, AdventureService.durationForVit(e.vitAtDispatch));
      expect(returnsAt.difference(dispatchedAt).inMinutes, e.durationMinutes);
      expect(e.multiplier, AdventureService.multiplierForVit(e.vitAtDispatch));

      // Payout sits in the base × multiplier × ±30% band.
      final base = AdventureService.basePayoutForRank(e.rank);
      expect(
        e.payout,
        greaterThanOrEqualTo((base * e.multiplier * 0.7).round() - 1),
      );
      expect(
        e.payout,
        lessThanOrEqualTo((base * e.multiplier * 1.3).round() + 1),
      );
    });

    test('dispatch needs a charge', () async {
      final e = await service().dispatchExpedition('iron_vault');
      expect(e, isNull);
      expect((await storedState()).pending, isNull);
    });

    test('only one expedition out at a time', () async {
      final svc = service();
      await svc.grantChargeForSession(session('w', now));
      await svc.dispatchExpedition('iron_vault');
      final second = await svc.dispatchExpedition('sky_tracer');
      expect(second, isNull);
      expect((await storedState()).pending!.routeId, 'iron_vault');
    });

    test('concurrent dispatches cannot double-spend a charge (single-flight)',
        () async {
      final svc = service();
      await svc.grantChargeForSession(session('w', now));
      final results = await Future.wait([
        svc.dispatchExpedition('iron_vault'),
        svc.dispatchExpedition('iron_vault'),
      ]);
      expect(results.whereType<Expedition>().toList(), hasLength(1));
      final s = await storedState();
      expect(s.charges, 0);
      expect(s.weekCount, 1);
    });

    test('same-day dispatches get distinct ids despite an identical clock',
        () async {
      // Bank two charges (1/day), then dispatch twice at the SAME fixed `now`
      // — the worst case for id collision. Distinctness must come from the
      // random suffix, not the (identical) microsecond clock.
      await service(at: DateTime(2026, 6, 11, 18)).grantChargeForSession(
        session('a', DateTime(2026, 6, 11, 18)),
      );
      final svc = service(); // now = 2026-06-12 18:00 (fixed)
      await svc.grantChargeForSession(session('b', now));
      final e1 = await svc.dispatchExpedition('iron_vault');
      // Clear the pending so a second dispatch is allowed.
      final after = DateTime.parse(e1!.returnsAtIso!).add(
        const Duration(minutes: 1),
      );
      await service(at: after).settleAndPeekReport();
      final e2 = await svc.dispatchExpedition('iron_vault');
      expect(e2, isNotNull);
      expect(e1.id, isNot(e2!.id));
    });

    test('a thrown mutation does not strand the serial queue (Codex #1)',
        () async {
      final boom = AdventureService(
        nowProvider: () => now,
        statEngine: _BoomEngine(),
      );
      await boom.grantChargeForSession(session('w', now)); // charge granted
      await expectLater(
        boom.dispatchExpedition('iron_vault'), // throws in getStoredStats
        throwsA(anything),
      );
      // A later queued mutation still runs (queue not poisoned).
      final tomorrow = now.add(const Duration(days: 1));
      await service(at: tomorrow).grantChargeForSession(
        session('w2', tomorrow),
      );
      expect((await storedState()).charges, 2);
    });
  });

  group('settlement and reveal (timed)', () {
    test('not revealable before returnsAt, revealable after; awards once',
        () async {
      final e = await earnAndDispatch('iron_vault');
      final returnsAt = DateTime.parse(e.returnsAtIso!);

      final before = returnsAt.subtract(const Duration(minutes: 1));
      expect(await service(at: before).settleAndPeekReport(), isNull);
      expect((await storedState()).pending, isNotNull);

      final after = returnsAt.add(const Duration(minutes: 1));
      final report = await service(at: after).settleAndPeekReport();
      expect(report, isNotNull);
      expect(report!.expedition.id, e.id);
      expect(await GemService().balance(), e.payout);
      final ledger = await GemService().ledger();
      expect(ledger.single.sourceKind, GemLedgerSourceKind.adventure);
    });

    test('peek without acknowledge never burns the ceremony', () async {
      final e = await earnAndDispatch('iron_vault');
      final after = DateTime.parse(e.returnsAtIso!).add(
        const Duration(minutes: 1),
      );
      final reopened = service(at: after);

      final first = await reopened.settleAndPeekReport();
      expect(first, isNotNull);
      expect((await storedState()).history.single.viewed, isFalse);

      final second = await reopened.settleAndPeekReport();
      expect(second!.expedition.id, first!.expedition.id);

      await reopened.acknowledgeReport(first.expedition.id);
      await reopened.acknowledgeReport(first.expedition.id); // idempotent
      expect((await storedState()).history.single.viewed, isTrue);
      expect(await reopened.settleAndPeekReport(), isNull);
      expect(await GemService().ledger(), hasLength(1));
    });

    test('single-flight: concurrent settles award exactly once', () async {
      final e = await earnAndDispatch('iron_vault');
      final after = DateTime.parse(e.returnsAtIso!).add(
        const Duration(minutes: 1),
      );
      final reopened = service(at: after);
      final results = await Future.wait([
        reopened.settleAndPeekReport(),
        reopened.settleAndPeekReport(),
        reopened.settleAndPeekReport(),
      ]);
      final reports = results.whereType<ExpeditionReport>().toList();
      expect(reports, hasLength(3));
      expect(reports.map((r) => r.expedition.id).toSet(), hasLength(1));
      expect(await GemService().ledger(), hasLength(1));
    });

    test('max-seen clock is monotonic; rollback cannot un-settle or '
        'double-award', () async {
      final e = await earnAndDispatch('iron_vault');
      final returnsAt = DateTime.parse(e.returnsAtIso!);

      final after = returnsAt.add(const Duration(hours: 2));
      await service(at: after).settleAndPeekReport();
      final s1 = await storedState();
      expect(s1.pending, isNull);
      expect(s1.history.single.id, e.id);
      final maxSeen1 = DateTime.parse(s1.maxSeenAtIso!);
      expect(maxSeen1.isBefore(after), isFalse);

      // Roll the clock far back and settle again: no second award, history
      // intact, and the max-seen clock never regresses.
      await service(
        at: returnsAt.subtract(const Duration(days: 2)),
      ).settleAndPeekReport();
      final s2 = await storedState();
      expect(await GemService().ledger(), hasLength(1));
      expect(s2.history.single.id, e.id);
      expect(DateTime.parse(s2.maxSeenAtIso!).isBefore(maxSeen1), isFalse);
    });

    test('a returned pending auto-settles when the next workout grants a '
        'charge (settlement before earn)', () async {
      final e = await earnAndDispatch('iron_vault');
      final returnsAt = DateTime.parse(e.returnsAtIso!);
      final nextDay = DateTime(
        returnsAt.year,
        returnsAt.month,
        returnsAt.day + 1,
        18,
      );
      await service(at: nextDay).grantChargeForSession(
        session('w2', nextDay),
      );
      final s = await storedState();
      expect(s.pending, isNull); // old expedition settled
      expect(s.history.single.id, e.id);
      expect(s.charges, greaterThanOrEqualTo(1)); // and a fresh charge earned
      expect(await GemService().balance(), e.payout);
      expect(s.history.single.viewed, isFalse); // report still waits to reveal
    });

    test('legacy v1 pending (no returnsAtIso) settles exactly once', () async {
      final legacyPending = Expedition(
        id: 'exp_legacy_1',
        routeId: 'iron_vault',
        day: '2026-06-11',
        bootId: 'old-boot',
        rank: 'C',
        payout: 12,
        flavorIdx: 0,
        // No dispatchedAtIso/returnsAtIso → revealable now (legacy rule).
      );
      SharedPreferences.setMockInitialValues({
        AdventureService.stateKey: jsonEncode(
          AdventureState(
            pending: legacyPending,
            standingOrderRouteId: 'iron_vault',
            ordersConfirmed: true,
            lastDispatchDay: '2026-06-11',
            weekCount: 1,
          ).toJson(),
        ),
      });
      final svc = service();
      final report = await svc.settleAndPeekReport();
      expect(report, isNotNull);
      expect(report!.expedition.id, 'exp_legacy_1');
      expect(await GemService().balance(), 12);

      await svc.acknowledgeReport('exp_legacy_1');
      expect(await svc.settleAndPeekReport(), isNull);
      expect(await GemService().balance(), 12); // no double award
      expect((await storedState()).pending, isNull);

      // The first v2 dispatch is not wedged by the legacy fields.
      await svc.grantChargeForSession(session('w', now));
      expect(await svc.dispatchExpedition('iron_vault'), isNotNull);
    });
  });

  group('weekly budget', () {
    test('cap of 5 holds within an ISO week (banked charges cannot exceed it) '
        'and resets next ISO week', () async {
      Future<void> dayCycle(int day) async {
        final at = DateTime(2026, 6, day, 18);
        final svc = service(at: at);
        await svc.grantChargeForSession(session('w$day', at));
        await svc.dispatchExpedition('iron_vault');
        // Settle next morning so the pending clears for the next day.
        await service(
          at: DateTime(2026, 6, day + 1, 10),
        ).settleAndPeekReport();
      }

      for (var day = 8; day <= 12; day++) {
        await dayCycle(day); // Mon–Fri, ISO week 24
      }
      expect((await storedState()).weekCount, 5);

      // Saturday (same ISO week): a charge is earned but dispatch is capped.
      final sat = DateTime(2026, 6, 13, 18);
      final satSvc = service(at: sat);
      await satSvc.grantChargeForSession(session('sat', sat));
      expect(await satSvc.dispatchExpedition('iron_vault'), isNull);
      expect((await storedState()).weekCount, 5);
      expect((await storedState()).charges, 1); // charge banks for next week

      // Monday next ISO week (25): resets and dispatches.
      final mon = DateTime(2026, 6, 15, 18);
      final monSvc = service(at: mon);
      await monSvc.grantChargeForSession(session('mon', mon));
      expect(await monSvc.dispatchExpedition('iron_vault'), isNotNull);
      expect((await storedState()).weekCount, 1);
    });
  });

  group('payout integrity', () {
    test('new user dispatches at D-rank base', () async {
      final e = await earnAndDispatch('iron_vault');
      expect(e.rank, 'D');
      expect(AdventureService.basePayoutForRank(e.rank), 8);
    });

    test('rank is captured at dispatch from the stored board', () async {
      SharedPreferences.setMockInitialValues({
        'combat_stats': '{"STR":350,"AGI":80,"END":120,"VIT":50,"LCK":2}',
        'workout_sessions': jsonEncode([session('h', now).toJson()]),
      });
      final svc = service();
      await svc.grantChargeForSession(session('w', now));
      final e = await svc.dispatchExpedition('iron_vault');
      expect(e!.rank, 'B'); // STR 350 → B (300–599)
      expect(AdventureService.basePayoutForRank('B'), 18);
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
    test('manual dispatch confirms orders; the report is not class-default',
        () async {
      final svc = service();
      await svc.grantChargeForSession(session('w', now));
      final e = await svc.dispatchExpedition('infini_maze');
      final s = await storedState();
      expect(s.standingOrderRouteId, 'infini_maze');
      expect(s.ordersConfirmed, isTrue);

      final after = DateTime.parse(e!.returnsAtIso!).add(
        const Duration(minutes: 1),
      );
      final report = await service(at: after).settleAndPeekReport();
      expect(report!.classDefaultOrders, isFalse);
      expect(report.expedition.routeId, 'infini_maze');
    });

    test('unknown stored route id falls back to a real route', () {
      expect(adventureRouteById('nope').id, adventureRoutes.first.id);
    });
  });

  group('defensive persistence', () {
    test('default constructor loads fresh state without a boot override',
        () async {
      expect(() => AdventureService(), returnsNormally);
      final state = await AdventureService().loadState();
      expect(state.pending, isNull);
      expect(state.history, isEmpty);
      expect(state.charges, 0);
    });

    test('malformed state decodes fresh and never throws', () async {
      SharedPreferences.setMockInitialValues({
        AdventureService.stateKey: '{not valid json',
      });
      final state = await AdventureService().loadState();
      expect(state.pending, isNull);
      expect(state.charges, 0);
      final svc = service();
      await svc.grantChargeForSession(session('w', now));
      expect(await svc.dispatchExpedition('iron_vault'), isNotNull);
    });

    test('malformed expedition records are dropped, not fatal', () {
      final state = AdventureState.fromJson({
        'version': 2,
        'charges': 99, // clamped to the cap
        'history': [
          {'id': 'good', 'routeId': 'iron_vault', 'day': '2026-06-01'},
          {'id': 42},
          'garbage',
        ],
        'pending': {'noId': true},
      });
      expect(state.history, hasLength(1));
      expect(state.pending, isNull);
      expect(state.charges, AdventureState.chargeCap);
    });

    test('history is capped', () async {
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
      final svc = service();
      await svc.grantChargeForSession(session('w', now));
      final e = await svc.dispatchExpedition('iron_vault');
      final after = DateTime.parse(e!.returnsAtIso!).add(
        const Duration(minutes: 1),
      );
      await service(at: after).settleAndPeekReport();
      final state = await storedState();
      expect(state.history.length, AdventureService.historyCap);
      expect(state.history.first.id, e.id);
    });

    test('adventure flows never touch board stats or workout history',
        () async {
      final sessionsRaw = jsonEncode([session('h', now).toJson()]);
      SharedPreferences.setMockInitialValues({
        'combat_stats': '{"STR":250,"AGI":80,"END":120,"VIT":50,"LCK":2}',
        'workout_sessions': sessionsRaw,
      });
      final svc = service();
      await svc.grantChargeForSession(session('w', now));
      final e = await svc.dispatchExpedition('iron_vault');
      final after = DateTime.parse(e!.returnsAtIso!).add(
        const Duration(minutes: 1),
      );
      await service(at: after).settleAndPeekReport();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('combat_stats'),
        '{"STR":250,"AGI":80,"END":120,"VIT":50,"LCK":2}',
      );
      expect(prefs.getString('workout_sessions'), sessionsRaw);
    });
  });

  // Regression guard for the Home-loader incident (2026-06-13): the default
  // constructor — the path production (and Home) actually uses — once threw
  // during static `bootId` init (`Random().nextInt(1 << 32)` → `nextInt(0)`
  // on web). Every other test injects `bootIdOverride`, so the real path was
  // uncovered.
  group('default-constructor path (no bootIdOverride)', () {
    test('static bootId is a usable non-empty id', () {
      expect(AdventureService.bootId, isNotEmpty);
    });

    test('default-constructed service grants and dispatches', () async {
      final svc = AdventureService(
        nowProvider: () => now,
        statEngine: StatEngine(catalog: catalog, nowProvider: () => now),
      );
      await svc.grantChargeForSession(session('w', now));
      final e = await svc.dispatchExpedition('iron_vault');
      expect(e, isNotNull);
      expect((await storedState()).pending, isNotNull);
      // Freshly dispatched → returns hours from now → not revealable yet.
      expect(await svc.settleAndPeekReport(), isNull);
    });
  });
}
