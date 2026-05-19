import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('removes old battle and class keys once', () async {
    const doneKey = 'migration_v1_battle_strip_done';
    const deadKeys = [
      'loot_scrap_balance',
      'unclaimed_loot',
      'idle_battle_state',
      'idle_battle_history',
      'idle_battle_last_active',
      'idle_battle_last_floor',
      'idle_battle_last_timestamp',
      'battle_scheduler_pending',
      'battle_scheduler_history',
      'battle_scheduler_floor',
      'last_battle_result',
      'dungeon_floor',
      'scrap',
      'dungeonFloor',
      'lastBattleResult',
      'idle_current_floor',
      'idle_highest_floor',
      'idle_last_session_timestamp',
      'idle_migrated',
      'class_carryover_v1',
      'class_ultimate_pending_reveal',
      'unlocked_abilities',
      'ultimate_progress',
    ];

    SharedPreferences.setMockInitialValues({
      for (final key in deadKeys) key: 'legacy',
      'keep_me': 'still here',
    });

    await MigrationService.runOnce();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getBool(doneKey), isTrue);
    expect(prefs.getString('keep_me'), 'still here');
    for (final key in deadKeys) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }

    await prefs.setString('scrap', '250');
    await MigrationService.runOnce();

    expect(prefs.getString('scrap'), '250');
  });
}
