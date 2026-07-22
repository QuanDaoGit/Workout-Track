// NOTE: HomePage tests run one scenario per file (one isolate each): a
// HomePage teardown can strand the process-wide prefs KeyedLock chain
// mid-critical-section, deadlocking any later in-process Home test (see
// home_room_camera_test.dart).
//
// The dolly's scroll half (2026-07-22 camera scroll-focus design): a board
// tap from a scrolled-down Home glides the scroll so the board rests near
// the viewport center, CONCURRENT with the camera dolly (motion starts on
// tap — never a serial scroll-then-zoom).
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
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          // The room arms the board tap only when BOTH are wired (the plain
          // callback is the fallback the board's null-check gates on).
          onViewQuests: onViewQuests,
          onViewQuestsFromBoard: onViewQuestsFromBoard,
        ),
      ),
    );
    for (
      var i = 0;
      i < 30 && find.byType(HomeRoomScene).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.byType(HomeRoomScene),
      findsOneWidget,
      reason: 'the home room must finish loading before the test proceeds',
    );
  }

  double offsetOf(WidgetTester tester) => tester
      .widget<CustomScrollView>(find.byType(CustomScrollView))
      .controller!
      .offset;

  testWidgets(
    'scrolled-down board tap: the scroll glides the board toward center, '
    'concurrent with the dolly',
    (tester) async {
      // No loaded snapshot → gates fail toward unlocked; the board is powered.
      SharedPreferences.setMockInitialValues({});
      addTearDown(FeatureGateService.resetForTest);

      var boardCalls = 0;
      await pumpHome(
        tester,
        onViewQuests: () {},
        onViewQuestsFromBoard: () {
          boardCalls++;
          return true;
        },
      );

      // Deterministic placement (a gesture drag flings — physics would carry
      // the room off-screen and the board out of tap reach).
      tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!
          .jumpTo(150);
      await tester.pump();
      final before = offsetOf(tester);
      expect(before, greaterThan(50));

      await tester.tap(find.byType(QuestBoard), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dolly window
      expect(boardCalls, 1);
      expect(
        offsetOf(tester),
        lessThan(before),
        reason: 'the scroll half of the dolly glides the board back toward '
            'the viewport center (clamped to the extents)',
      );
      // Let the scroll + dolly controllers finish before teardown.
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
