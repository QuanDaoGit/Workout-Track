import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/stat_card.dart';

/// Rendered-artifact lock for the v4 "stat remaster" scale: 4-digit stat
/// values (B/A-band board) must fit the stat card's expanded detail rows,
/// radar labels, and NEXT-milestone line without truncation or overflow.
/// Regenerate with `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stat card renders a 4-digit remaster board', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: kBg,
          body: SingleChildScrollView(
            child: StatCard(
              // A mid-game board: STR high-B, AGI led (A), END mid-B — plus a
              // 5-digit near-cap check is deliberately NOT here (post-S boards
              // are years away; 4 digits is the common case).
              stats: const {
                'STR': 4830,
                'AGI': 6120,
                'END': 3410,
                'VIT': 70,
                'LCK': 4,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('[ SHOW DETAIL ]'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(StatCard),
      matchesGoldenFile('goldens/stat_card_remaster_scale.png'),
    );
  });
}
