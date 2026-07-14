import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/loot_item.dart';
import 'package:workout_track/services/loot_service.dart';
import 'package:workout_track/services/migration_service.dart';

/// Upgrade-path regression for the theme removal: a user who had a theme equipped
/// / owned before the feature was deleted must load clean, with the dead theme
/// data stripped and their frames intact.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cleanup strips the theme slot + theme ids, keeps frames, load is safe', () async {
    SharedPreferences.setMockInitialValues({
      'equipped_loot': jsonEncode({
        'frame': 'frame_iron',
        'theme': 'theme_inferno',
      }),
      'loot_inventory': <String>[
        'frame_iron',
        'frame_stone',
        'theme_inferno',
        'theme_default',
      ],
    });

    await MigrationService.runThemeLootCleanupOnce();

    final prefs = await SharedPreferences.getInstance();
    final equipped =
        jsonDecode(prefs.getString('equipped_loot')!) as Map<String, dynamic>;
    expect(equipped.containsKey('theme'), isFalse, reason: 'dead theme slot');
    expect(equipped['frame'], 'frame_iron', reason: 'frame slot preserved');

    final inv = prefs.getStringList('loot_inventory')!;
    expect(inv.where((id) => id.startsWith('theme_')), isEmpty);
    expect(inv, contains('frame_stone'));

    // Load paths tolerate the data and never throw.
    final service = LootService();
    final equippedLoot = await service.getEquippedLoot();
    expect(equippedLoot[LootCategory.avatarFrame]?.id, 'frame_iron');
    final ownedIds = (await service.getInventory()).map((i) => i.id);
    expect(ownedIds, isNot(contains('theme_inferno')));
  });

  test('cleanup is gated + a no-op when there is no theme data', () async {
    SharedPreferences.setMockInitialValues({
      'equipped_loot': jsonEncode({'frame': 'frame_iron'}),
      'loot_inventory': <String>['frame_iron'],
    });

    await MigrationService.runThemeLootCleanupOnce();
    // Second call is gated and harmless.
    await MigrationService.runThemeLootCleanupOnce();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('loot_inventory'), ['frame_iron']);
    expect(
      jsonDecode(prefs.getString('equipped_loot')!),
      {'frame': 'frame_iron'},
    );
  });
}
