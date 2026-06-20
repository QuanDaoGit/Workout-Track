import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/home.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/loot_avatar_frame.dart';
import 'package:workout_track/widgets/pixel_loader.dart';
import 'package:workout_track/widgets/radar_stat_icon.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('HomeStatusHud renders Ironbit, LCK, gems, and vitality', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: HomeStatusHud(
              lck: 2, // 1 diamond (weekly ladder) → active icon
              lckMultiplier: 1.5,
              gemBalance: 125,
              vitality: 80,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home_status_hud')), findsOneWidget);
    expect(find.text('Ironbit'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_status_class_icon')), findsNothing);
    _expectImageAsset(
      tester,
      const ValueKey('home_status_lck_icon'),
      RadarStatIcons.lckActive,
    );
    _expectImageAsset(
      tester,
      const ValueKey('home_status_gem_icon'),
      'assets/icons/economy/icon_gem.png',
    );
    _expectImageAsset(
      tester,
      const ValueKey('home_status_vit_icon'),
      RadarStatIcons.vitality80,
    );

    expect(
      _textForKey(tester, const ValueKey('home_status_lck_multiplier')).data,
      '1.5x',
    );
    expect(
      _textForKey(tester, const ValueKey('home_status_gem_balance')).data,
      '125',
    );
    expect(
      _textForKey(tester, const ValueKey('home_status_vit_value')).data,
      '80',
    );
    expect(
      _textForKey(
        tester,
        const ValueKey('home_status_lck_multiplier'),
      ).style?.color,
      kAmber,
    );
    expect(
      _textForKey(
        tester,
        const ValueKey('home_status_gem_balance'),
      ).style?.color,
      kText,
    );
  });

  testWidgets('HomeStatusHud renders hot LCK and large balances', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: HomeStatusHud(
              lck: 100,
              lckMultiplier: 2,
              gemBalance: 2400,
              vitality: 40,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home_status_hud')), findsOneWidget);
    expect(find.text('Ironbit'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_status_class_icon')), findsNothing);
    _expectImageAsset(
      tester,
      const ValueKey('home_status_lck_icon'),
      RadarStatIcons.lckHot,
    );
    _expectImageAsset(
      tester,
      const ValueKey('home_status_gem_icon'),
      'assets/icons/economy/icon_gem.png',
    );
    _expectImageAsset(
      tester,
      const ValueKey('home_status_vit_icon'),
      RadarStatIcons.vitality40,
    );
    expect(
      _textForKey(tester, const ValueKey('home_status_lck_multiplier')).data,
      '2.0x',
    );
    expect(
      _textForKey(tester, const ValueKey('home_status_gem_balance')).data,
      '2400',
    );
    expect(
      _textForKey(tester, const ValueKey('home_status_vit_value')).data,
      '40',
    );
  });

  testWidgets('HomeStatusHud remains visible with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(
              width: 390,
              child: HomeStatusHud(
                lck: 25,
                lckMultiplier: 1.5,
                gemBalance: 125,
                vitality: 80,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home_status_hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_status_lck_icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_status_gem_icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_status_vit_icon')), findsOneWidget);
  });

  testWidgets('HomePage shows sticky HUD without removing main Home surfaces', (
    tester,
  ) async {
    // Phone-sized surface: the Home Room is the top hero and the level strip +
    // mission card peek below it. The default 800×600 test surface would push
    // the room to its min-height and bury the cards off-screen.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: HomePage(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await _pumpUntilFound(tester, const ValueKey('home_status_hud'));

    final initialTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_status_hud')))
        .dy;

    expect(find.byKey(const ValueKey('home_status_hud')), findsOneWidget);
    expect(find.byType(PixelLoader), findsNothing);
    expect(find.text("TODAY'S MISSION"), findsWidgets);
    // The level strip is Home's single competence surface, above the mission.
    expect(find.byType(HomeLevelStrip), findsOneWidget);
    // The character bar (and its avatar) moved to Labs — Home keeps identity
    // via BIT + the level strip, no profile card.
    expect(find.byType(LootAvatarFrame), findsNothing);
    // The quests card sits below the Adventure callout now — scroll it into the
    // lazily-built sliver viewport before asserting it exists.
    await tester.scrollUntilVisible(
      find.text('WEEKLY QUESTS'),
      240,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('WEEKLY QUESTS'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Ironbit'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_status_class_icon')), findsNothing);
    expect(find.byKey(const ValueKey('home_status_lck_icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_status_gem_icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_status_vit_icon')), findsOneWidget);
    expect(
      _textForKey(tester, const ValueKey('home_status_lck_multiplier')).data,
      '1.0x',
    );
    expect(
      _textForKey(tester, const ValueKey('home_status_gem_balance')).data,
      '0',
    );
    expect(
      _textForKey(tester, const ValueKey('home_status_vit_value')).data,
      '10',
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_status_hud')), findsOneWidget);
    final scrolledTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_status_hud')))
        .dy;
    expect(scrolledTop, lessThanOrEqualTo(initialTop));
    expect(scrolledTop, lessThanOrEqualTo(4));
    expect(find.byKey(const ValueKey('home_status_class_icon')), findsNothing);
    expect(find.text("TODAY'S MISSION"), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('HomeStatusHud metrics are per-section nav buttons', (
    tester,
  ) async {
    var lckTaps = 0;
    var gemTaps = 0;
    var vitTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: HomeStatusHud(
              lck: 25,
              lckMultiplier: 1.5,
              gemBalance: 125,
              vitality: 80,
              onLckTap: () => lckTaps++,
              onGemTap: () => gemTaps++,
              onVitTap: () => vitTaps++,
            ),
          ),
        ),
      ),
    );

    // LCK → stat board (luck is a combat stat shown there).
    await tester.tap(find.byKey(const ValueKey('home_status_lck_multiplier')));
    await tester.pumpAndSettle();
    expect([lckTaps, gemTaps, vitTaps], [1, 0, 0]);

    // Gem → gem store.
    await tester.tap(find.byKey(const ValueKey('home_status_gem_balance')));
    await tester.pumpAndSettle();
    expect([lckTaps, gemTaps, vitTaps], [1, 1, 0]);

    // Heart/VIT → stat board.
    await tester.tap(find.byKey(const ValueKey('home_status_vit_value')));
    await tester.pumpAndSettle();
    expect([lckTaps, gemTaps, vitTaps], [1, 1, 1]);

    // Chrome-free but exposed to assistive tech as a labelled button.
    expect(find.bySemanticsLabel('Gems 125'), findsOneWidget);
  });
}

Text _textForKey(WidgetTester tester, Key key) {
  return tester.widget<Text>(find.byKey(key));
}

Future<void> _pumpUntilFound(WidgetTester tester, Key key) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(key).evaluate().isNotEmpty) return;
  }
  final exception = tester.takeException();
  final visibleText = find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>()
      .join(', ');
  fail(
    'Timed out waiting for $key. '
    'exception=$exception visibleText=[$visibleText]',
  );
}

void _expectImageAsset(WidgetTester tester, Key key, String expectedAsset) {
  final direct = find.byKey(key);
  final imageFinder = tester.widget(direct) is Image
      ? direct
      : find.descendant(of: direct, matching: find.byType(Image));
  final image = tester.widget<Image>(imageFinder);
  final provider = image.image;
  expect(provider, isA<AssetImage>());
  expect((provider as AssetImage).assetName, expectedAsset);
}
