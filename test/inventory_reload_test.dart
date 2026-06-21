import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/loot_registry.dart';
import 'package:workout_track/models/loot_item.dart';
import 'package:workout_track/pages/inventory_page.dart';
import 'package:workout_track/services/loot_service.dart';

/// Regression: the Inventory page lives in RootPage's IndexedStack (kept alive),
/// so its `initState` load runs once. Loot earned AFTER that first build must
/// surface when RootPage calls `reload()` on tab re-entry — not only after an
/// equip. This pins the public `reload()` that the fix relies on.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('reload() surfaces loot granted after the first build', (
    tester,
  ) async {
    final loot = LootService();
    final ownedAtBuild =
        (await loot.getInventory()).map((i) => i.id).toSet();
    // A static (non-animated) frame the user does NOT own at first build.
    final newFrame = lootRegistry.firstWhere(
      (i) =>
          i.category == LootCategory.avatarFrame &&
          i.frameCount <= 1 && // static frame → no perpetual animation to settle
          !ownedAtBuild.contains(i.id),
    );

    final key = GlobalKey<InventoryPageState>();
    await tester.pumpWidget(MaterialApp(home: InventoryPage(key: key)));
    await tester.pumpAndSettle(); // initial _load completes

    expect(find.text(newFrame.name), findsNothing); // not earned yet

    // Loot earned elsewhere (a workout save / quest claim) while this kept-alive
    // page sits in the stack.
    await loot.grantItem(newFrame.id);
    await tester.pump();
    expect(
      find.text(newFrame.name),
      findsNothing,
      reason: 'kept-alive page is stale until something triggers a reload',
    );

    // The fix: RootPage.goTo(inventory) calls this on tab re-entry.
    await key.currentState!.reload();
    await tester.pumpAndSettle();
    expect(
      find.text(newFrame.name),
      findsOneWidget,
      reason: 'reload() re-fetches owned loot and renders the new frame',
    );
  });
}
