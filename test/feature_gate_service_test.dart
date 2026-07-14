import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/feature_gate_service.dart';
import 'package:workout_track/services/migration_service.dart';

/// Builds a service with injected condition sources so no real store is read.
FeatureGateService service({
  int completed = 0,
  bool gems = false,
  bool loot = false,
  DateTime? now,
}) {
  return FeatureGateService(
    nowProvider: () => now ?? DateTime(2026, 7, 14, 12),
    completedWorkoutCountOverride: () async => completed,
    hasEarnedGemsOverride: () async => gems,
    hasEarnedLootOverride: () async => loot,
  );
}

Future<Map<String, dynamic>> storedState() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(FeatureGateService.storageKey);
  return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    FeatureGateService.resetForTest();
  });

  group('conditions', () {
    test('fresh user: everything locked', () async {
      final unlocked = await service().evaluate();
      expect(unlocked, isEmpty);
      for (final gate in FeatureGate.values) {
        expect(FeatureGateService.isUnlockedSync(gate), isFalse);
      }
    });

    test('1 completed workout unlocks quests only (count gates)', () async {
      final unlocked = await service(completed: 1).evaluate();
      expect(unlocked, [FeatureGate.quests]);
      expect(FeatureGateService.isUnlockedSync(FeatureGate.quests), isTrue);
      expect(FeatureGateService.isUnlockedSync(FeatureGate.guild), isFalse);
      expect(FeatureGateService.isUnlockedSync(FeatureGate.adventure), isFalse);
    });

    test('3 workouts unlock guild; 5 unlock adventure', () async {
      await service(completed: 3).evaluate();
      expect(FeatureGateService.isUnlockedSync(FeatureGate.guild), isTrue);
      expect(FeatureGateService.isUnlockedSync(FeatureGate.adventure), isFalse);
      await service(completed: 5).evaluate();
      expect(FeatureGateService.isUnlockedSync(FeatureGate.adventure), isTrue);
    });

    test('gem-only change unlocks shop with zero workouts (Codex P1)', () async {
      final unlocked = await service(gems: true).evaluate();
      expect(unlocked, [FeatureGate.shop]);
    });

    test('loot-only change unlocks inventory with zero workouts (Codex P1)',
        () async {
      final unlocked = await service(loot: true).evaluate();
      expect(unlocked, [FeatureGate.inventory]);
    });
  });

  group('latching', () {
    test('unlock survives the condition regressing (history delete)', () async {
      await service(completed: 3).evaluate();
      final unlocked = await service(completed: 0).evaluate();
      expect(unlocked, isEmpty, reason: 're-evaluation adds nothing new');
      expect(FeatureGateService.isUnlockedSync(FeatureGate.guild), isTrue);
      expect(FeatureGateService.isUnlockedSync(FeatureGate.quests), isTrue);
    });

    test('re-evaluation never re-reports an already-latched gate', () async {
      expect(await service(completed: 1).evaluate(), [FeatureGate.quests]);
      expect(await service(completed: 1).evaluate(), isEmpty);
    });

    test('markCelebrated is monotonic and ignores locked gates', () async {
      final early = DateTime(2026, 7, 10);
      await service(completed: 1, now: early).evaluate();
      await service(now: DateTime(2026, 7, 11))
          .markCelebrated([FeatureGate.quests, FeatureGate.guild]);
      final state = await storedState();
      expect(state['quests']['celebratedAt'], isNotNull);
      expect(state.containsKey('guild'), isFalse,
          reason: 'celebrating a locked gate must not invent an unlock');
      // A second celebration never overwrites the first stamp.
      await service(now: DateTime(2026, 7, 12))
          .markCelebrated([FeatureGate.quests]);
      final again = await storedState();
      expect(again['quests']['celebratedAt'],
          DateTime(2026, 7, 11).toIso8601String());
    });
  });

  group('pending ceremonies', () {
    test('derived from persisted state, oldest unlock first', () async {
      await service(gems: true, now: DateTime(2026, 7, 2)).evaluate();
      await service(completed: 1, now: DateTime(2026, 7, 1)).evaluate();
      expect(FeatureGateService.pendingCeremoniesSync(),
          [FeatureGate.quests, FeatureGate.shop]);
      await service().markCelebrated([FeatureGate.quests]);
      expect(FeatureGateService.pendingCeremoniesSync(), [FeatureGate.shop]);
    });

    test('load() rebuilds the pending queue from disk (kill/reopen)', () async {
      await service(completed: 1).evaluate();
      FeatureGateService.resetForTest();
      expect(FeatureGateService.pendingCeremoniesSync(), isEmpty,
          reason: 'unloaded snapshot has no pending queue');
      await service().load();
      expect(
          FeatureGateService.pendingCeremoniesSync(), [FeatureGate.quests]);
    });
  });

  group('fail toward fuller', () {
    test('never-loaded snapshot reads unlocked', () {
      expect(FeatureGateService.isUnlockedSync(FeatureGate.guild), isTrue);
    });

    test('corrupt blob re-derives from history without burning ceremonies',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(FeatureGateService.storageKey, '{not json');
      final unlocked = await service(completed: 3).evaluate();
      expect(unlocked,
          containsAll([FeatureGate.quests, FeatureGate.guild]));
      final state = await storedState();
      expect(state['guild']['unlockedAt'], isNotNull);
      expect(state['guild']['celebratedAt'], isNull,
          reason: 'recovery must not silently burn the ceremony (Codex F2)');
    });

    test('a corrupt record for one gate does not drop the others', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        FeatureGateService.storageKey,
        jsonEncode({
          'quests': {'unlockedAt': 'garbage-date'},
          'shop': {'unlockedAt': DateTime(2026, 7, 1).toIso8601String()},
        }),
      );
      await service().load();
      expect(FeatureGateService.isUnlockedSync(FeatureGate.shop), isTrue);
      // quests' bad stamp parses to null → treated as locked until re-derived.
      expect(FeatureGateService.isUnlockedSync(FeatureGate.quests), isFalse);
    });
  });

  group('migration seed (grandfather invariant, Codex P2)', () {
    test('fresh install: nothing latched, migration marks done', () async {
      await MigrationService.runFeatureGateSeedOnce();
      expect(await storedState(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migration_v_feature_gate_seed_done'), isTrue);
    });

    test('legacy: onboarded user with SPARSE data gets every gate, silent',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete_v1', true);
      await MigrationService.runFeatureGateSeedOnce();
      final state = await storedState();
      for (final gate in FeatureGate.values) {
        expect(state[gate.name]['unlockedAt'], isNotNull,
            reason: 'no gem ledger / no loot must NOT lock a legacy user out');
        expect(state[gate.name]['celebratedAt'], isNotNull);
        expect(state[gate.name]['emittedAt'], isNotNull,
            reason: 'seed path never emits synthetic analytics');
      }
      expect(FeatureGateService.pendingCeremoniesSync(), isEmpty);
    });

    test('legacy: stored sessions without onboarding flag still grandfather',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'workout_sessions',
        jsonEncode([
          {'id': 's1', 'isPartial': true, 'isAbandoned': false},
        ]),
      );
      await MigrationService.runFeatureGateSeedOnce();
      final state = await storedState();
      expect(state['adventure']['unlockedAt'], isNotNull,
          reason: 'ANY stored session marks a pre-feature install');
    });

    test('one-shot: a later fresh evaluate still runs the ladder', () async {
      await MigrationService.runFeatureGateSeedOnce(); // fresh → no latch
      await MigrationService.runFeatureGateSeedOnce(); // idempotent
      final unlocked = await service(completed: 1).evaluate();
      expect(unlocked, [FeatureGate.quests],
          reason: 'a fresh install earns through the ladder normally');
      final state = await storedState();
      expect(state['quests']['celebratedAt'], isNull,
          reason: 'a live earn is NOT pre-celebrated');
    });
  });

  group('transaction serialization (Codex P1 races)', () {
    test('two concurrent evaluates cannot lose an update', () async {
      final a = service(completed: 1);
      final b = service(gems: true);
      final results = await Future.wait([a.evaluate(), b.evaluate()]);
      final all = results.expand((r) => r).toSet();
      expect(all, {FeatureGate.quests, FeatureGate.shop});
      final state = await storedState();
      expect(state['quests']['unlockedAt'], isNotNull);
      expect(state['shop']['unlockedAt'], isNotNull);
    });

    test('concurrent evaluate + markCelebrated keep both writes', () async {
      await service(completed: 1).evaluate();
      await Future.wait([
        service(gems: true).evaluate(),
        service().markCelebrated([FeatureGate.quests]),
      ]);
      final state = await storedState();
      expect(state['shop']['unlockedAt'], isNotNull);
      expect(state['quests']['celebratedAt'], isNotNull);
    });
  });

  group('analytics emission marker', () {
    test('emittedAt stamps once and backfills after a crash pre-emit',
        () async {
      await service(completed: 1).evaluate();
      var state = await storedState();
      expect(state['quests']['emittedAt'], isNotNull);
      // Simulate a legacy crash: unlocked but never emitted.
      final prefs = await SharedPreferences.getInstance();
      state['quests'].remove('emittedAt');
      await prefs.setString(
          FeatureGateService.storageKey, jsonEncode(state));
      await service().evaluate();
      state = await storedState();
      expect(state['quests']['emittedAt'], isNotNull,
          reason: 'the next transaction retries the emission');
    });
  });
}
