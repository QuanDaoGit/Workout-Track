import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/inventory_page.dart';
import 'package:workout_track/services/loot_service.dart';

import 'audit_capture.dart';

/// Pilot audit scenario for the `/audit` skill — renders the real
/// [InventoryPage] with a seeded loot inventory to a truthful PNG.
///
/// Seeds through the REAL service write API ([LootService.grantItem]) so the
/// fixture tracks the inventory schema (Codex F1: no hand-rolled prefs blob that
/// can render a stale lie). Run: `flutter test test/audit/inventory_capture_test.dart`
/// → writes `test/audit/_shots/inventory_owned.png` for the Presentation pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('audit/inventory — owned frames + title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final loot = LootService();
    await loot.grantItem('frame_bronze');
    await loot.grantItem('frame_silver');
    await loot.grantItem('frame_gold');
    await loot.grantItem('title_iron_will');

    final result = await captureSurface(
      tester,
      name: 'inventory_owned',
      // 'No Title' only renders in the LOADED title section — proves the page
      // got past its loading spinner (AppBar text would not).
      smokeText: 'No Title',
      builder: (context) => const InventoryPage(),
    );

    // Feed the deterministic lint track: a healthy page has no layout overflow.
    expect(
      result.overflowErrors,
      isEmpty,
      reason: 'layout overflow on Inventory: ${result.overflowErrors}',
    );
  },
      timeout: const Timeout(Duration(seconds: 45)),
      // Audit captures are on-demand tools, not regression tests: they WRITE a
      // (gitignored) PNG and only run under `--update-goldens`. Skipping here
      // keeps a normal `flutter test` green.
      skip: !autoUpdateGoldenFiles);
}
