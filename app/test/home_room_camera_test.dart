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

  testWidgets('locked board tap: notice path fires, camera never engages',
      (tester) async {
    // A fresh install with a LOADED (not absent) gate snapshot: no completed
    // workouts → quests genuinely locked. (An unloaded snapshot fails toward
    // unlocked by design, so the lock must be loaded explicitly.)
    SharedPreferences.setMockInitialValues({});
    await FeatureGateService().load();
    addTearDown(FeatureGateService.resetForTest);
    expect(FeatureGateService.isUnlockedSync(FeatureGate.quests), isFalse,
        reason: 'test premise: the quests gate must start locked');

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

    expect(find.byType(QuestBoard), findsOneWidget);
    await tester.tap(find.byType(QuestBoard), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 60));

    expect(plainCalls, 1,
        reason: 'locked → the plain callback (the shell shows the notice)');
    expect(boardCalls, 0,
        reason: 'the dolly push path must not run while locked');
    expect(lensTransform(), findsNothing,
        reason: 'a locked tap must never engage the camera (Codex F2/F4)');
  });
}
