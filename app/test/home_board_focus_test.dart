// NOTE: HomePage tests run one scenario per file (one isolate each): a
// HomePage teardown can strand the process-wide prefs KeyedLock chain
// mid-critical-section, deadlocking any later in-process Home test (see
// home_room_camera_test.dart).
//
// The board camera's SERIAL beats (2026-07-22 scroll-focus design, sequencing
// user-directed 2026-07-23): a board tap from a scrolled-down Home first
// TRACKS the scroll so the board rests near the viewport center (starting on
// tap — the response is still instant), and only then fires the push + dolly.
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
    'scrolled-down board tap: the scroll tracks the board to center FIRST, '
    'then the push + dolly fire (serial beats)',
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
      // SERIAL contract (user-directed 2026-07-23): during the pre-scroll
      // track the push has NOT fired and the camera is NOT engaged yet —
      // only the scroll moves.
      await tester.pump(const Duration(milliseconds: 150));
      final midTrack = offsetOf(tester);
      expect(midTrack, lessThan(before),
          reason: 'the track starts on tap (instant response)');
      expect(boardCalls, 0,
          reason: 'the push waits for the track to finish (serial beats)');
      expect(find.byKey(const ValueKey('room_camera_zoom')), findsNothing,
          reason: 'the dolly waits for the track to finish (serial beats)');
      // Track complete (kBoardTrackMs = 340) → push + dolly fire (one real
      // frame with elapsed time so the dolly leaves identity and the lens
      // layer actually paints).
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 100));
      expect(boardCalls, 1);
      expect(find.byKey(const ValueKey('room_camera_zoom')), findsOneWidget,
          reason: 'the dolly engages once the board is centered');
      // Let the dolly finish before teardown.
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
