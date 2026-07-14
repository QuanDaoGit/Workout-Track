import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/body_map_regions.dart';
import 'package:workout_track/services/muscle_coverage_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/muscle_body_map.dart';

void main() {
  // Per-detailed-key sets → one synthetic contributor each (rolls up to the
  // same per-muscle totals the body map paints).
  Map<String, List<MuscleContributor>> contrib(Map<String, double> sets) => {
    for (final e in sets.entries)
      e.key: [
        MuscleContributor(exerciseId: e.key, exerciseName: e.key, sets: e.value),
      ],
  };

  final sample = contrib(const {
    'front_delt': 13.0,
    'biceps': 6.0,
    'forearms': 9.0,
    'chest': 14.0,
    'rectus_abdominis': 19.0,
    'obliques': 4.0,
    'quadriceps': 16.0,
    'adductors': 3.0,
    'calves': 12.0,
  });

  testWidgets('muscle body map — front view, sample coverage', (tester) async {
    tester.view.physicalSize = const Size(820, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: kBg,
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: MuscleBodyMap(contributors: sample),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MuscleBodyMap),
      matchesGoldenFile('_body_map_front.png'),
    );
  });

  testWidgets('muscle body map — 4-week average view with range selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: kBg,
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: MuscleBodyMap(
                  contributors: sample,
                  window: CoverageWindow.fourWeek,
                  effectiveWeeks: 4,
                  onWindowChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MuscleBodyMap),
      matchesGoldenFile('_body_map_4wk_avg.png'),
    );
  });
}
