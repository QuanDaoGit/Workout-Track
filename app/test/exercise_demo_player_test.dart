import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/exercise_demos.dart';
import 'package:workout_track/widgets/exercise_demo_player.dart';

const _demo = ExerciseDemo('a.mp4', 'a_poster.webp');

void main() {
  testWidgets('uninitialized player renders the poster, no glyph (autoplay)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ExerciseDemoPlayer(demo: _demo),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == _demo.poster,
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.play_arrow_sharp), findsNothing);
  });

  testWidgets('autoPlay: false shows the play glyph over the poster', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ExerciseDemoPlayer(demo: _demo, autoPlay: false),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.play_arrow_sharp), findsOneWidget);
  });
}
