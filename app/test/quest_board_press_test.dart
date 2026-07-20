import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/quest_board.dart';
import 'package:workout_track/widgets/room/room_scene.dart';

void main() {
  Widget host({VoidCallback? onTap}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuestBoard(
              width: 65,
              height: 72,
              total: 5,
              filled: 3,
              ready: 0,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      );

  QuestBoardPainter painterOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is QuestBoardPainter));
    return paint.painter! as QuestBoardPainter;
  }

  testWidgets('pointer-down lights the board; release relaxes it after a beat',
      (tester) async {
    await tester.pumpWidget(host());
    expect(painterOf(tester).press, isFalse);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(QuestBoard)));
    await tester.pump();
    expect(painterOf(tester).press, isTrue,
        reason: 'the screen answers the finger immediately');

    await gesture.up();
    await tester.pump();
    // Held lit for a short legibility beat even on an instant tap...
    expect(painterOf(tester).press, isTrue);
    // ...then relaxes.
    await tester.pump(const Duration(milliseconds: 120));
    expect(painterOf(tester).press, isFalse);
  });

  test('focal helpers track the room layout math', () {
    const size = Size(340, 400);
    final a = HomeRoomScene.anchorsFor(size.width, size.height);
    expect(a.kx, 1.0);
    // padCenterY = clamp(200 + 102, 102, 400 - 92) = 302 (under the 308 cap).
    expect(a.padCenterY, 302);
    expect(a.padTopY, 276);
    // bitCenterY = (302 - 26 + 4) - 80 = 200.
    expect(a.bitCenterY, 200);
    final board = HomeRoomScene.boardFocal(size);
    // board center x = (40 + 32.5)·kx = 72.5 → (72.5/340)·2 − 1 ≈ −0.5735
    expect(board.x, closeTo(-0.5735, 0.001));
    // board center y = 200 − 16 + 36 = 220 → (220/400)·2 − 1 = 0.1
    expect(board.y, closeTo(0.1, 0.001));
    final pad = HomeRoomScene.padFocal(size);
    expect(pad.x, 0);
    // pad center y = 302 → (302/400)·2 − 1 = 0.51
    expect(pad.y, closeTo(0.51, 0.001));
  });
}
