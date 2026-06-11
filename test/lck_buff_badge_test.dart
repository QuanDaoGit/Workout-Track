import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/radar_stat_icon.dart';
import 'package:workout_track/widgets/lck_buff_badge.dart';

void main() {
  testWidgets('hidden when there is no buff (multiplier 1.0)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LckBuffBadge(multiplier: 1.0, lck: 0)),
      ),
    );
    expect(find.textContaining('LCK'), findsNothing);
    expect(find.byKey(const ValueKey('lck_buff_badge_icon')), findsNothing);
  });

  testWidgets('shows LCK x label and reason tooltip when buffed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LckBuffBadge(multiplier: 2.0, lck: 4)),
      ),
    );

    expect(find.text('LCK x2.0x'), findsNothing); // no double-x bug
    expect(find.text('LCK x2'), findsOneWidget); // clean "2", no ".0"
    _expectImageAsset(
      tester,
      const ValueKey('lck_buff_badge_icon'),
      RadarStatIcons.lckActive,
    );

    await tester.tap(find.byType(LckBuffBadge));
    await tester.pumpAndSettle();

    // 4 clean weeks (2 diamonds), ×2.0 → +100% XP.
    expect(find.textContaining('4 clean weeks'), findsOneWidget);
    expect(find.textContaining('+100% XP'), findsOneWidget);
  });

  testWidgets('uses singular week phrasing at one clean week', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LckBuffBadge(multiplier: 1.5, lck: 1)),
      ),
    );
    await tester.tap(find.byType(LckBuffBadge));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 clean week'), findsOneWidget);
    expect(find.textContaining('+50% XP'), findsOneWidget);
  });
}

void _expectImageAsset(WidgetTester tester, Key key, String expectedAsset) {
  final image = tester.widget<Image>(
    find.descendant(of: find.byKey(key), matching: find.byType(Image)),
  );
  final provider = image.image;
  expect(provider, isA<AssetImage>());
  expect((provider as AssetImage).assetName, expectedAsset);
}
