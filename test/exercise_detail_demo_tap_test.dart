import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/exercise_detail.dart';
import 'package:workout_track/widgets/exercise_demo_player.dart';

import 'helpers/fake_video_platform.dart';

/// Reproduces the reported bug surface: tapping the demo in the exercise info
/// page hero (FlexibleSpaceBar inside a pinned SliverAppBar).
const _squat = Exercise(
  id: 'Barbell_Squat',
  name: 'Barbell Squat',
  level: 'beginner',
  images: [],
);

void main() {
  late FakeVideoPlayerPlatform fake;

  setUp(() {
    fake = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('info-page hero: autoplay, tap pauses, tap resumes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ExerciseDetailPage(exercise: _squat)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      fake.log,
      contains('play'),
      reason: 'demo should autoplay on the info page',
    );

    final player = find.byType(ExerciseDemoPlayer);
    expect(player, findsOneWidget);

    await tester.tap(player, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      fake.log,
      contains('pause'),
      reason: 'tapping the hero demo should pause it',
    );

    fake.log.clear();
    await tester.tap(player, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      fake.log,
      contains('play'),
      reason: 'tapping again should resume it',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
