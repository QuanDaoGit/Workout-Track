import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/room_zoom_lens.dart';

void main() {
  testWidgets('identity camera adds no transform layer over the child',
      (tester) async {
    final camera = RoomCamera();
    addTearDown(camera.dispose);
    await tester.pumpWidget(RoomZoomLens(
      camera: camera,
      child: const SizedBox(width: 10, height: 10),
    ));
    expect(
      find.descendant(
          of: find.byType(RoomZoomLens), matching: find.byType(Transform)),
      findsNothing,
      reason: 'scale 1 must paint the child untouched (goldens/reduced-motion)',
    );
  });

  testWidgets('an engaged camera scales around its focal point, clipped',
      (tester) async {
    final camera = RoomCamera();
    addTearDown(camera.dispose);
    await tester.pumpWidget(RoomZoomLens(
      camera: camera,
      child: const SizedBox(width: 10, height: 10),
    ));
    camera.set(1.12, const Alignment(-0.5, 0.1));
    await tester.pump();
    final transform = tester.widget<Transform>(find.descendant(
        of: find.byType(RoomZoomLens), matching: find.byType(Transform)));
    expect(transform.alignment, const Alignment(-0.5, 0.1));
    expect(
      find.descendant(
          of: find.byType(RoomZoomLens), matching: find.byType(ClipRect)),
      findsOneWidget,
      reason: 'the zoomed layer must not bleed outside the room box',
    );
    // Disengage → identity again.
    camera.reset();
    await tester.pump();
    expect(
      find.descendant(
          of: find.byType(RoomZoomLens), matching: find.byType(Transform)),
      findsNothing,
    );
  });
}
