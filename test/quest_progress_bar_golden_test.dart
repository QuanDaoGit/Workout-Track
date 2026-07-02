import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/pages/quests_page.dart';
import 'package:workout_track/theme/tokens.dart';

/// Faithful (dark-theme) rendered proof of the quest section progress meter:
/// the segmented [ArcadeBar] filling toward the reward-chest end-cap, in both
/// states the page can show — INCOMPLETE (chest muted/locked) and COMPLETE
/// (chest amber + bloom). The page-level `quests_board.png` golden renders on
/// Material's default light theme, so it can't judge these tints; this one paints
/// on `kBg` at 3× so the chest's real colour is verifiable. Regenerate with
/// `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<ByteData> font(String path) async =>
        ByteData.view((await File(path).readAsBytes()).buffer);
    await (FontLoader('ShareTechMono')
          ..addFont(font('fonts/sharetechmono/ShareTechMono-Regular.ttf')))
        .load();
    await (FontLoader('PressStart2P')
          ..addFont(font('fonts/pressstart2p/PressStart2P-Regular.ttf')))
        .load();
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    required int lit,
    required int total,
  }) async {
    tester.view.physicalSize = const Size(480, 128);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ColoredBox(
            color: kBg,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QuestProgressBar(
                  litCells: lit,
                  totalCells: total,
                  bonusGems: 25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The chest sprites decode asynchronously — precache (real bytes via the test
    // bundle) before capturing or the chest renders its painted fallback.
    await tester.runAsync(() async {
      final el = tester.element(find.byType(QuestProgressBar));
      await precacheImage(
        const AssetImage('assets/icons/control/chest/chest_closed.png'),
        el,
      );
      await precacheImage(
        const AssetImage('assets/icons/control/chest/chest_open.png'),
        el,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('progress bar — incomplete (locked chest)', (tester) async {
    await pumpBar(tester, lit: 1, total: 3);
    await expectLater(
      find.byType(QuestProgressBar),
      matchesGoldenFile('goldens/quest_progress_bar_incomplete.png'),
    );
  });

  testWidgets('progress bar — complete (amber reward chest)', (tester) async {
    await pumpBar(tester, lit: 3, total: 3);
    await expectLater(
      find.byType(QuestProgressBar),
      matchesGoldenFile('goldens/quest_progress_bar_complete.png'),
    );
  });
}
