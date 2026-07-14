import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/room_scene.dart';

/// The room's scroll parallax: it drifts the soft background when scrolled, and
/// is **inert under reduced motion** (the WCAG 2.3.3 a11y gate). The drift lives
/// on a keyed `Transform`; reduced motion drops it entirely.
void main() {
  Widget harness({required bool reduce, required ValueListenable<double> off}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 600,
              child: HomeRoomScene(
                height: 600,
                name: 'WARRIOR',
                level: 7,
                title: 'BRUISER',
                scrollOffset: off,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('background drifts when scrolled (normal motion)', (tester) async {
    final off = ValueNotifier<double>(240);
    addTearDown(off.dispose);
    await tester.pumpWidget(harness(reduce: false, off: off));
    await tester.pump();

    final t = tester.widget<Transform>(
      find.byKey(const ValueKey('room_parallax_shell')),
    );
    // 240 * 0.3 = 72, capped at the 48px max-travel.
    expect(t.transform.getTranslation().y, 48);
  });

  testWidgets('parallax is inert under reduced motion (a11y gate)', (
    tester,
  ) async {
    final off = ValueNotifier<double>(240);
    addTearDown(off.dispose);
    await tester.pumpWidget(harness(reduce: true, off: off));
    await tester.pump();

    // No drift transform at all under reduced motion — the static room renders.
    expect(find.byKey(const ValueKey('room_parallax_shell')), findsNothing);
  });
}
