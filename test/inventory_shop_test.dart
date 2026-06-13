import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/inventory_page.dart';
import 'package:workout_track/pages/shop_page.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/widgets/loot_avatar_frame.dart';
import 'package:workout_track/widgets/motion/hold_depress.dart';
import 'package:workout_track/widgets/motion/phosphor_tap.dart';
import 'package:workout_track/widgets/pixel_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('inventory renders owned loadout only', (tester) async {
    await _pumpInventory(tester);

    expect(find.text('LOOT INVENTORY'), findsOneWidget);
    expect(find.text('Iron Frame'), findsOneWidget);
    expect(find.text('Recruit'), findsOneWidget);

    expect(find.text('GEM WALLET'), findsNothing);
    expect(find.text('Stone Frame'), findsNothing);
    expect(find.text('150'), findsNothing);
  });

  testWidgets('shop renders locked purchasable cosmetics but no titles', (
    tester,
  ) async {
    await _pumpShop(tester);

    expect(find.text('GEM SHOP'), findsOneWidget);
    expect(find.text('Stone Frame'), findsOneWidget);
    expect(find.text('The Grinder'), findsNothing);
    expect(find.text('FEATURED'), findsNothing);
    expect(find.text('BUNDLES'), findsNothing);
    expect(find.text('PASS'), findsNothing);
    expect(find.textContaining('recruits own'), findsNothing);
    expect(find.textContaining('LEFT'), findsNothing);
    expect(_assetImage('assets/icons/economy/icon_gem.png'), findsWidgets);
  });

  testWidgets('shop cards use rarity rails and no lock/shop overlay icons', (
    tester,
  ) async {
    await _pumpShop(tester);

    expect(
      find.byKey(const ValueKey('shop_rarity_badge_common')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('shop_rarity_badge_uncommon')),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('shop_rarity_badge_rare')), findsWidgets);
    expect(find.byKey(const ValueKey('shop_rarity_badge_epic')), findsWidgets);
    expect(_rarityRail('common'), findsWidgets);
    expect(_rarityRail('uncommon'), findsWidgets);
    expect(_rarityRail('rare'), findsWidgets);
    expect(_rarityRail('epic'), findsWidgets);
    expect(_assetImage('assets/icons/economy/icon_gem_lock.png'), findsNothing);
    expect(_assetImage('assets/icons/economy/icon_shop.png'), findsNothing);
  });

  testWidgets('affordable filter only shows items within gem balance', (
    tester,
  ) async {
    final gems = GemService();
    await gems.awardQuestGems(
      claimKey: 'seed',
      amount: 200,
      label: 'Seed gems',
    );

    await _pumpShop(tester);

    await tester.tap(find.text('AFFORDABLE'));
    await tester.pumpAndSettle();

    expect(find.text('Stone Frame'), findsOneWidget);
    expect(find.text('Bronze Frame'), findsNothing);
  });

  testWidgets('buying a shop frame spends gems and moves it to inventory', (
    tester,
  ) async {
    final gems = GemService();
    await gems.awardQuestGems(
      claimKey: 'seed',
      amount: 200,
      label: 'Seed gems',
    );

    await _pumpShop(tester);

    expect(find.text('200'), findsOneWidget);

    await _openStoneFrameInShop(tester);
    await tester.pumpAndSettle();
    expect(_buyButton(150), findsOneWidget);

    await tester.ensureVisible(_buyButton(150));
    await tester.pumpAndSettle();
    await tester.tap(_buyButton(150));
    await tester.pumpAndSettle();

    expect(find.text('UNLOCKED'), findsOneWidget);
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(await gems.balance(), 50);
    expect(find.text('Stone Frame'), findsNothing);

    await _pumpInventory(tester);
    expect(find.text('Stone Frame'), findsOneWidget);
  });

  testWidgets('wallet plus opens demo gem store and top-up refreshes balance', (
    tester,
  ) async {
    await _pumpShop(tester);

    expect(find.byKey(const ValueKey('shop_wallet_plus')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shop_wallet_plus')));
    await tester.pumpAndSettle();

    expect(find.text('GEM STORE'), findsOneWidget);
    expect(find.byKey(const ValueKey('gem_pack_demo_500')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gem_pack_demo_500')));
    await tester.pumpAndSettle();

    expect(await GemService().balance(), 500);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('+500 GEMS'), findsOneWidget);
  });

  testWidgets('insufficient buy opens gem store without granting item', (
    tester,
  ) async {
    await _pumpShop(tester);

    await _openStoneFrameInShop(tester);
    await tester.pumpAndSettle();

    expect(_buyButton(150), findsOneWidget);
    expect(find.widgetWithText(PixelButton, 'NEED 150 GEMS'), findsNothing);

    await tester.ensureVisible(_buyButton(150));
    await tester.pumpAndSettle();
    await tester.tap(_buyButton(150));
    await tester.pumpAndSettle();

    expect(find.text('Not enough gems'), findsOneWidget);
    expect(find.text('GEM STORE'), findsOneWidget);
    expect(await GemService().balance(), 0);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Stone Frame'), findsOneWidget);

    await _pumpInventory(tester);
    expect(find.text('Stone Frame'), findsNothing);
  });

  testWidgets('purchase sheet shows live frame preview and expanded preview', (
    tester,
  ) async {
    await _pumpShop(tester);

    await _openStoneFrameInShop(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('shop_live_preview_avatarFrame')),
      findsOneWidget,
    );
    expect(find.byType(LootAvatarFrame), findsOneWidget);
    expect(find.text('PREVIEW'), findsOneWidget);

    await tester.ensureVisible(find.text('PREVIEW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PREVIEW'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shop_expanded_preview')), findsOneWidget);
    expect(find.byType(LootAvatarFrame), findsWidgets);
  });

  testWidgets('shop cards and filters use micro-motion widgets', (
    tester,
  ) async {
    await _pumpShop(tester);

    expect(find.byType(HoldDepress), findsWidgets);
    expect(find.byType(PhosphorTap), findsWidgets);
    expect(find.widgetWithText(PixelButton, 'NEED 150 GEMS'), findsNothing);

    await _openStoneFrameInShop(tester);
    await tester.pumpAndSettle();

    expect(_buyButton(150), findsOneWidget);
    expect(find.widgetWithText(PixelButton, 'NEED 150 GEMS'), findsNothing);
  });
}

Finder _buyButton(int price) {
  return find.byWidgetPredicate((widget) {
    return widget is PixelButton &&
        widget.label.contains('BUY') &&
        widget.label.contains('$price');
  });
}

Finder _assetImage(String assetName) {
  return find.byWidgetPredicate((widget) {
    return widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetName;
  });
}

Finder _rarityRail(String rarityName) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('shop_rarity_rail_${rarityName}_');
  });
}

Future<void> _pumpInventory(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: InventoryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpShop(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: ShopPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openStoneFrameInShop(WidgetTester tester) async {
  final stoneFrame = find.text('Stone Frame');
  await tester.scrollUntilVisible(
    stoneFrame,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(stoneFrame);
  await tester.pumpAndSettle();
}
