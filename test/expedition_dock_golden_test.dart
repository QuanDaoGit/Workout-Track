import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/bit_room_copy.dart';
import 'package:workout_track/models/adventure_models.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/room/room_scene.dart';
import 'package:workout_track/widgets/room/world_window.dart';

RoomAdventureView _view({
  required AdventurePhase phase,
  int charges = 0,
  bool canDispatch = false,
  bool haulReady = false,
  bool greeted = false,
  String? routeName,
  Color? routeAccent,
  int? backInHours,
}) => RoomAdventureView(
  phase: phase,
  charges: charges,
  canDispatch: canDispatch,
  haulReady: haulReady,
  routeName: routeName,
  routeAccent: routeAccent,
  backInHours: backInHours,
  voice: BitRoomVoice.select(
    phase: phase,
    haulReady: haulReady,
    greeted: greeted,
    adviceIndex: 0,
    routeName: routeName,
    backInHours: backInHours,
  ),
);

/// Rendered-artifact + regression lock for the pad's Expedition-dock states
/// (the Flutter web preview can't screenshot here). Deterministic under reduced
/// motion. The *aesthetic* (does `out` read as "coming back", neon contrast on
/// the pool) still needs on-device sign-off — these only prove the states render
/// cleanly and pin them against regressions. Regenerate with
/// `flutter test --update-goldens`.
void main() {
  Future<void> shot(
    WidgetTester tester, {
    required RoomAdventureView adv,
    required String file,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: SizedBox(
                width: 390,
                child: HomeRoomScene(
                  height: 700,
                  name: 'VALEN',
                  level: 7,
                  title: 'KNIGHT',
                  timeOfDay: RoomTimeOfDay.evening,
                  adventure: adv,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(HomeRoomScene),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets(
    'ready',
    (t) => shot(
      t,
      adv: _view(
        phase: AdventurePhase.idle,
        charges: 2,
        canDispatch: true,
      ),
      file: 'expedition_dock_ready.png',
    ),
  );

  testWidgets(
    'out',
    (t) => shot(
      t,
      adv: _view(
        phase: AdventurePhase.out,
        greeted: true, // the steady away state (scouting); greeting is its own golden
        routeName: 'SKY TRACER',
        routeAccent: kCyan,
        backInHours: 5,
      ),
      file: 'expedition_dock_out.png',
    ),
  );

  testWidgets(
    'returned',
    (t) => shot(
      t,
      adv: _view(
        phase: AdventurePhase.returned,
        haulReady: true,
        routeName: 'SKY TRACER',
        routeAccent: kCyan,
      ),
      file: 'expedition_dock_returned.png',
    ),
  );

  testWidgets(
    'haul (settled idle + coffer)',
    (t) => shot(
      t,
      adv: _view(
        phase: AdventurePhase.idle,
        charges: 2,
        haulReady: true,
        routeName: 'SKY TRACER',
        routeAccent: kCyan,
      ),
      file: 'expedition_dock_haul.png',
    ),
  );
}
