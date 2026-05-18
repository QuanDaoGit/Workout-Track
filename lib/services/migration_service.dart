import 'package:shared_preferences/shared_preferences.dart';

/// One-shot cleanup of dead `shared_preferences` keys left over from the
/// battle / dungeon / scrap / ability / ultimate systems.
///
/// Guarded by [_doneKey] so it only runs once per install.
class MigrationService {
  const MigrationService._();

  static const _doneKey = 'migration_v1_battle_strip_done';

  static const _deadKeys = <String>[
    // Battle / dungeon / scrap
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
    // Class abilities / ultimate
    'class_carryover_v1',
    'class_ultimate_pending_reveal',
    'unlocked_abilities',
    'ultimate_progress',
  ];

  /// Runs once. Idempotent. Safe to call from `main.dart` before runApp.
  static Future<void> runOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) == true) return;

    for (final key in _deadKeys) {
      await prefs.remove(key);
    }

    await prefs.setBool(_doneKey, true);
  }
}
