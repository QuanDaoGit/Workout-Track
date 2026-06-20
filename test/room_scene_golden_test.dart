import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/room/room_scene.dart';
import 'package:workout_track/widgets/room/world_window.dart';

/// Rendered-artifact proof for the composed Home Room across the device sizes
/// that broke v1 (the Flutter web preview cannot screenshot here). Each is
/// pinned to an explicit width/height/text-scale + an explicit time of day, so
/// the scene is deterministic under reduced motion. The window image falls back
/// to its colored stand-in in the test bundle, which keeps the golden stable.
/// Regenerate with `flutter test --update-goldens`.
void main() {
  Future<void> shot(
    WidgetTester tester, {
    required double w,
    required double h,
    double textScale = 1.0,
    required String file,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: SizedBox(
                width: w,
                child: HomeRoomScene(
                  height: h,
                  name: 'VALEN',
                  level: 7,
                  title: 'KNIGHT',
                  timeOfDay: RoomTimeOfDay.evening,
                  questWeeklyTotal: 5,
                  questWeeklyFilled: 3,
                  questClaimable: 1,
                  onViewQuests: () {},
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

  testWidgets('phone', (t) => shot(t, w: 390, h: 700, file: 'home_room_phone.png'));
  testWidgets('wide', (t) => shot(t, w: 543, h: 760, file: 'home_room_wide.png'));
  testWidgets('short', (t) => shot(t, w: 360, h: 420, file: 'home_room_short.png'));
  testWidgets(
    'large text',
    (t) => shot(t, w: 390, h: 700, textScale: 1.4, file: 'home_room_large_text.png'),
  );
}
