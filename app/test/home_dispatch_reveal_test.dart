// NOTE: HomePage tests run one scenario per file (one isolate each): a
// HomePage teardown can strand the process-wide prefs KeyedLock chain
// mid-critical-section, deadlocking any later in-process Home test (see
// home_room_camera_test.dart).
//
// The dispatch-reveal staging contract (Codex F1/F2 of the 2026-07-22
// expedition-return design): a live dispatch that lands while Home is
// scrolled down must snap the scroll home and deliver the idle→out flip to
// the SAME mounted room State (a didUpdateWidget flip — the only path that
// plays the launch send-off), never a cold remount.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/adventure_models.dart';
import 'package:workout_track/pages/home.dart';
import 'package:workout_track/services/adventure_service.dart';
import 'package:workout_track/services/feature_gate_service.dart';
import 'package:workout_track/widgets/room/room_scene.dart';

void main() {
  Future<void> seed(AdventureState state) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'combat_stats',
      '{"STR":10,"AGI":10,"END":10,"VIT":50,"LCK":0}',
    );
    await prefs.setString('workout_sessions', '[]');
    await prefs.setString(
      AdventureService.stateKey,
      jsonEncode(state.toJson()),
    );
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
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
    'live dispatch while scrolled: scroll snaps home and the mounted room '
    'receives the idle→out flip (launch contract)',
    (tester) async {
      await seed(AdventureState(charges: 1));
      addTearDown(FeatureGateService.resetForTest);
      await pumpHome(tester);

      // Scroll down deterministically (a gesture drag flings — physics could
      // carry the room past cacheExtent and unmount it; the identity
      // assertion below needs the pre-flip State object to stay alive).
      tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!
          .jumpTo(250);
      await tester.pump();
      final scrolled = offsetOf(tester);
      expect(scrolled, greaterThan(50));

      final roomStateBefore = tester.state(find.byType(HomeRoomScene));

      // A dispatch happens elsewhere (the map / the ceremony path), then Home
      // reloads on the pop return. The dispatch chains on the service's
      // process-wide serial queue, where Home's own post-frame settle may
      // still be in flight in THIS (fake-async) zone — so kick it off here
      // and drive it with the poll; awaiting it inside runAsync would
      // deadlock on that fake-zone predecessor.
      Expedition? dispatched;
      var dispatchDone = false;
      // ignore: unawaited_futures
      AdventureService().dispatchExpedition('iron_vault').then((e) {
        dispatched = e;
        dispatchDone = true;
      });
      for (var i = 0; i < 40 && !dispatchDone; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(dispatched, isNotNull, reason: 'test premise: dispatch works');
      final home = tester.state<HomePageState>(find.byType(HomePage));
      // ignore: unawaited_futures
      home.reload();

      // Bounded poll: reload is real-async prefs work AND the staging awaits
      // one real frame (endOfFrame) between the scroll snap and the commit.
      AdventurePhase? phase() => tester
          .widget<HomeRoomScene>(find.byType(HomeRoomScene))
          .adventure
          ?.phase;
      for (
        var i = 0;
        i < 40 && phase() != AdventurePhase.out;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(phase(), AdventurePhase.out);
      expect(
        offsetOf(tester),
        lessThan(1.0),
        reason: 'the room must be on stage for the send-off',
      );
      expect(
        identical(roomStateBefore, tester.state(find.byType(HomeRoomScene))),
        isTrue,
        reason: 'the flip must reach the SAME mounted room State '
            '(didUpdateWidget — the only path that plays the launch), '
            'never a cold remount',
      );
      // Let the 2000ms send-off run out so no controller is mid-flight at
      // teardown (the launch is a one-shot, not a perpetual ticker).
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}
