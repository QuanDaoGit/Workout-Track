import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/character_service.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/loot_service.dart';
import 'package:workout_track/services/quest_service.dart';
import 'package:workout_track/services/rest_service.dart';
import 'package:workout_track/services/stat_engine.dart';
import 'package:workout_track/services/workout_storage_service.dart';

/// A corrupt or schema-drifted SharedPreferences blob must never throw out of a
/// boot/home-path loader — it degrades to a typed fallback (or the salvageable
/// subset) instead. Before the json_safe hardening these loaders called
/// `jsonDecode(...) as ...` directly, so a single bad record could crash the
/// home screen on open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Garbage that is valid-ish text but not the JSON shape each loader expects.
  const garbage = '}{not json at all';

  group('corrupt blob → typed fallback (no throw)', () {
    void seed(String key, String value) =>
        SharedPreferences.setMockInitialValues({key: value});

    test('workout_sessions → []', () async {
      seed('workout_sessions', garbage);
      expect(await WorkoutStorageService().getSessions(), isEmpty);
    });

    test('gem_ledger_v1 → empty ledger / zero balance', () async {
      seed('gem_ledger_v1', garbage);
      final gem = GemService();
      expect(await gem.ledger(), isEmpty);
      expect(await gem.balance(), 0);
    });

    test('combat_stats → stored stats load without throwing', () async {
      seed('combat_stats', garbage);
      final stats = await StatEngine().getStoredStats();
      expect(stats, isA<Map<String, int>>());
    });

    test('quest_state_v1 → empty state (claimed XP 0)', () async {
      seed('quest_state_v1', garbage);
      expect(await QuestService().claimedRewardXP(), 0);
    });

    test('rest_state_v1 → defaults (loads without throwing)', () async {
      seed('rest_state_v1', garbage);
      final state = await RestService().loadState();
      expect(state, isNotNull);
    });

    test('equipped_loot → empty map', () async {
      seed('equipped_loot', garbage);
      expect(await LootService().getEquippedLoot(), isEmpty);
    });

    test('active_character_v1 → null', () async {
      seed('active_character_v1', garbage);
      expect(await CharacterService().loadActiveCharacter(), isNull);
    });
  });

  group('missing key → typed fallback', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('all primary loaders return their empty/default shape', () async {
      expect(await WorkoutStorageService().getSessions(), isEmpty);
      expect(await GemService().balance(), 0);
      expect(await LootService().getEquippedLoot(), isEmpty);
      expect(await CharacterService().loadActiveCharacter(), isNull);
    });
  });

  group('schema drift → salvageable subset', () {
    test('one valid + one broken session record → keeps the valid one',
        () async {
      final valid = WorkoutSession(
        id: 'good',
        date: DateTime(2026, 1, 2),
        muscleGroup: 'Chest',
        targetDurationMinutes: 30,
        actualDurationSeconds: 600,
        exercises: const [],
        estimatedCalories: 50,
      ).toJson();
      // Second record is a map but missing the fields fromJson requires → it is
      // skipped, not fatal.
      final blob = jsonEncode([valid, {'nonsense': true}]);
      SharedPreferences.setMockInitialValues({'workout_sessions': blob});

      final sessions = await WorkoutStorageService().getSessions();
      expect(sessions.map((s) => s.id), ['good']);
    });
  });
}
