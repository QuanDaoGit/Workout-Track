// NOTE: the locked-path sibling lives in home_room_camera_test.dart. The two
// scenarios are deliberately in SEPARATE FILES (one isolate each): a HomePage
// teardown can strand the process-wide prefs KeyedLock chain mid-critical-
// section, deadlocking any later in-process test that loads Home.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/home.dart';
import 'package:workout_track/services/feature_gate_service.dart';
import 'package:workout_track/widgets/room/quest_board.dart';
import 'package:workout_track/widgets/room/room_scene.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    required VoidCallback onViewQuests,
    required bool Function() onViewQuestsFromBoard,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        onViewQuests: onViewQuests,
        onViewQuestsFromBoard: onViewQuestsFromBoard,
      ),
    ));
    // _loadData is real async work — poll (bounded) until the loading gate
    // lifts and the room is mounted, instead of guessing one fixed delay.
    for (var i = 0;
        i < 30 && find.byType(HomeRoomScene).evaluate().isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(HomeRoomScene), findsOneWidget,
        reason: 'the home room must finish loading before the test proceeds');
  }

  // The camera's own transform (the room's parallax also composes a Transform
  // inside the lens subtree, so the lens layer is found by its key).
  Finder lensTransform() => find.byKey(const ValueKey('room_camera_zoom'));

  testWidgets('unlocked board tap: dolly path fires and the camera engages',
      (tester) async {
    // No loaded snapshot → gates fail toward unlocked (the by-design default);
    // the board is powered and the tap is real travel.
    SharedPreferences.setMockInitialValues({});
    addTearDown(FeatureGateService.resetForTest);

    var plainCalls = 0;
    var boardCalls = 0;
    await pumpHome(
      tester,
      onViewQuests: () => plainCalls++,
      onViewQuestsFromBoard: () {
        boardCalls++;
        return true;
      },
    );

    await tester.tap(find.byType(QuestBoard), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(boardCalls, 1, reason: 'the board path owns the wall-board tap');
    expect(plainCalls, 0);
    expect(lensTransform(), findsOneWidget,
        reason: 'real travel engages the camera in the same tick');
    // Let the 280ms dolly finish so no controller is mid-flight at teardown.
    await tester.pump(const Duration(milliseconds: 300));
  });
}
