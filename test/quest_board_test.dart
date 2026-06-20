import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/quest_board.dart';

/// Rendered + behavioural proof for the ported wall quest board
/// (`assets/design_handoff_home_room/quest-board/quest-board.js`): a flush
/// crate with QUESTS · a 5-seg cyan weekly bar · one gem pip, that tints amber
/// + breathes ONLY when a reward is ready. Goldens render the painter directly
/// (static frames) zoomed ×6. Regenerate with `flutter test --update-goldens`.
void main() {
  setUpAll(() async {
    Future<ByteData> font(String path) async =>
        ByteData.view((await File(path).readAsBytes()).buffer);
    await (FontLoader('PressStart2P')
          ..addFont(font('fonts/pressstart2p/PressStart2P-Regular.ttf')))
        .load();
  });

  Future<void> shot(
    WidgetTester t, {
    required int filled,
    required int ready,
    required double glow,
    required String file,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF11111F),
          body: Center(
            child: SizedBox(
              width: 65 * 6,
              height: 72 * 6,
              child: CustomPaint(
                painter: QuestBoardPainter(
                  total: 5,
                  filled: filled,
                  ready: ready,
                  glow: glow,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await expectLater(
      find.byType(CustomPaint).first,
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('quest board · idle steady-cyan (2/5, none ready)',
      (t) => shot(t, filled: 2, ready: 0, glow: 0, file: 'quest_board_idle.png'));
  testWidgets(
      'quest board · claimable amber rest (3/5, 2 ready, g=.6)',
      (t) => shot(
            t,
            filled: 3,
            ready: 2,
            glow: 0.6,
            file: 'quest_board_claimable.png',
          ));
  testWidgets(
      'quest board · claimable amber breathe peak (g=1)',
      (t) => shot(
            t,
            filled: 3,
            ready: 2,
            glow: 1.0,
            file: 'quest_board_claimable_peak.png',
          ));

  Future<void> pumpBoard(
    WidgetTester t, {
    required int filled,
    required int ready,
    VoidCallback? onTap,
    bool reduce = false,
  }) {
    final board = QuestBoard(
      width: 65,
      height: 72,
      total: 5,
      filled: filled,
      ready: ready,
      onTap: onTap,
    );
    return t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: reduce
                ? MediaQuery(
                    data: const MediaQueryData(disableAnimations: true),
                    child: board,
                  )
                : board,
          ),
        ),
      ),
    );
  }

  Finder semanticsContaining(String text) => find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label ?? '').contains(text),
      );

  testWidgets('tap routes via onTap', (t) async {
    var taps = 0;
    await pumpBoard(t, filled: 2, ready: 1, onTap: () => taps++);
    await t.tap(find.byType(QuestBoard));
    expect(taps, 1);
  });

  testWidgets('semantics label reflects the ready count', (t) async {
    await pumpBoard(t, filled: 3, ready: 2, onTap: () {});
    await t.pump();
    expect(semanticsContaining('2 rewards ready to claim'), findsOneWidget);
  });

  testWidgets('empty board reads as quiet — no reward claim in the label',
      (t) async {
    await pumpBoard(t, filled: 1, ready: 0, onTap: () {});
    await t.pump();
    expect(semanticsContaining('ready to claim'), findsNothing);
    expect(semanticsContaining('Quest board'), findsOneWidget);
  });

  testWidgets('reduced motion: a claimable board is static (no perpetual ticker)',
      (t) async {
    await pumpBoard(t, filled: 3, ready: 2, reduce: true);
    // If a breathe ticker ran, pumpAndSettle would time out.
    await t.pumpAndSettle();
  });

  testWidgets('idle (nothing ready) is static even with motion on', (t) async {
    await pumpBoard(t, filled: 2, ready: 0);
    await t.pumpAndSettle();
  });
}
