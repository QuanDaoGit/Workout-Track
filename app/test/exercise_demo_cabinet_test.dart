import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:workout_track/data/exercise_demos.dart';
import 'package:workout_track/services/workout_defaults_service.dart';
import 'package:workout_track/widgets/exercise_demo_cabinet.dart';

import 'helpers/fake_video_platform.dart';

const _demo = ExerciseDemo('a.mp4', 'a_poster.webp');

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late FakeVideoPlayerPlatform fake;

  setUp(() {
    fake = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('cabinet renders strip and opens PAUSED with controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ExerciseDemoCabinet(demo: _demo, exerciseName: 'Bench')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('FORM DEMO'), findsOneWidget);
    expect(find.text('LOOP'), findsOneWidget);
    expect(find.text('HIDE'), findsOneWidget);
    // Opens paused: no play() on mount, and the strip shows the play control
    // (the stage also shows the big glyph, so scope to the InkWell button).
    expect(fake.log, isNot(contains('play')));
    expect(
      find.widgetWithIcon(InkWell, Icons.play_arrow_sharp),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.pause_sharp), findsNothing);

    await unmount(tester);
  });

  testWidgets('strip button starts playback, then pauses', (tester) async {
    await tester.pumpWidget(
      _host(const ExerciseDemoCabinet(demo: _demo, exerciseName: 'Bench')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Opens paused → strip shows a play control (scope to the InkWell button;
    // the stage shows its own glyph too).
    final stripPlay = find.widgetWithIcon(InkWell, Icons.play_arrow_sharp);
    expect(stripPlay, findsOneWidget);

    await tester.tap(stripPlay);
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.log, contains('play'));
    // Playing → strip flips to the pause control.
    expect(find.byIcon(Icons.pause_sharp), findsOneWidget);

    fake.log.clear();
    await tester.tap(find.byIcon(Icons.pause_sharp));
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.log, contains('pause'));
    expect(
      find.widgetWithIcon(InkWell, Icons.play_arrow_sharp),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('HIDE collapses to the strip, persists, SHOW restores', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ExerciseDemoCabinet(demo: _demo, exerciseName: 'Bench')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('HIDE'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SHOW'), findsOneWidget);
    expect(find.text('LOOP'), findsNothing);
    expect(find.byIcon(Icons.pause_sharp), findsNothing);
    expect(await WorkoutDefaultsService().getExerciseDemoHidden(), isTrue);

    await tester.tap(find.text('SHOW'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('HIDE'), findsOneWidget);
    expect(find.text('LOOP'), findsOneWidget);
    expect(await WorkoutDefaultsService().getExerciseDemoHidden(), isFalse);

    await unmount(tester);
  });

  testWidgets('persisted hidden state starts the cabinet collapsed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'exercise_demo_hidden_v1': true});
    await tester.pumpWidget(
      _host(const ExerciseDemoCabinet(demo: _demo, exerciseName: 'Bench')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SHOW'), findsOneWidget);
    expect(find.text('LOOP'), findsNothing);

    await unmount(tester);
  });

  group('fullscreen viewer', () {
    Future<void> openViewer(WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => openExerciseDemoFullscreen(
                  context,
                  demo: _demo,
                  exerciseName: 'Barbell Bench Press',
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.close_sharp), findsOneWidget);
    }

    testWidgets('tapping the backdrop dismisses (zoom-out bug regression)', (
      tester,
    ) async {
      await openViewer(tester);

      // Top-left corner — outside the centered 16:9 clip, on the backdrop.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.close_sharp), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('tapping the close button dismisses', (tester) async {
      await openViewer(tester);

      await tester.tap(find.byIcon(Icons.close_sharp));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.close_sharp), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('LOOP opens fullscreen with its own player and resumes on '
        'return', (tester) async {
      await tester.pumpWidget(
        _host(const ExerciseDemoCabinet(demo: _demo, exerciseName: 'Bench')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // The cabinet opens paused; start it so the fullscreen handoff has
      // playback to pause on the way in and resume on the way back.
      await tester.tap(find.widgetWithIcon(InkWell, Icons.play_arrow_sharp));
      await tester.pump(const Duration(milliseconds: 100));
      fake.log.clear();

      await tester.tap(find.text('LOOP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.close_sharp), findsOneWidget);
      // Cabinet paused itself, fullscreen's own player started.
      expect(fake.log, contains('pause'));
      expect(fake.log, contains('play'));

      fake.log.clear();
      await tester.tap(find.byIcon(Icons.close_sharp));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Back on the cabinet, playback resumed.
      expect(fake.log, contains('play'));
      expect(find.text('LOOP'), findsOneWidget);

      await unmount(tester);
    });
  });
}
