import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:workout_track/data/exercise_demos.dart';
import 'package:workout_track/widgets/exercise_demo_player.dart';

import 'helpers/fake_video_platform.dart';

const _demo = ExerciseDemo('a.mp4', 'a_poster.webp');

void main() {
  late FakeVideoPlayerPlatform fake;

  setUp(() {
    fake = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
  });

  testWidgets('autoplays after init, tap pauses, tap resumes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 400,
            child: ExerciseDemoPlayer(demo: _demo),
          ),
        ),
      ),
    );
    // Let init microtask + event propagate.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.log, contains('loop:true'));
    expect(fake.log, contains('play'));
    // Playing → chromeless, no glyph.
    expect(find.byIcon(Icons.play_arrow_sharp), findsNothing);

    // Tap → pause: glyph appears, platform got the pause call.
    await tester.tap(find.byType(ExerciseDemoPlayer), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.play_arrow_sharp), findsOneWidget);
    expect(fake.log, contains('pause'));

    // Tap again → resumes: glyph gone.
    await tester.tap(find.byType(ExerciseDemoPlayer), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.play_arrow_sharp), findsNothing);

    // Dispose the player (cancels the controller's position timer).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
