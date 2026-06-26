import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/body_map_regions.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/pages/exercise_history_page.dart';
import 'package:workout_track/services/muscle_coverage_service.dart';
import 'package:workout_track/services/strength_trend_service.dart';
import 'package:workout_track/services/unit_settings_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/muscle_body_map.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Units.weight = WeightUnit.kg;
  });

  MuscleContributor c(String id, String name, double sets) =>
      MuscleContributor(exerciseId: id, exerciseName: name, sets: sets);

  StrengthTrend st(String id, String name, List<double> pts) => StrengthTrend(
    exerciseId: id,
    exerciseName: name,
    e1rmPoints: pts,
    sessionCount: pts.length,
    firstE1rm: pts.first,
    bestE1rm: pts.reduce(max),
    lastE1rm: pts.last,
    lastDate: DateTime(2026, 6, 20),
  );

  // CHEST has a strength roster; OBLIQUES intentionally has none (empty dossier).
  final strengthSample = <String, List<StrengthTrend>>{
    'chest': [
      st('bench', 'Bench Press', [80, 85, 90]),
      st('fly', 'Cable Fly', [20, 22]),
    ],
  };

  void bigView(WidgetTester t) {
    t.view.physicalSize = const Size(820, 2600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  // Groups are collapsed by default; reveal a section's meter rows by tapping
  // its header (scroll it into view first for the default-size hosts).
  Future<void> expandGroup(WidgetTester t, String title) async {
    await t.ensureVisible(find.text(title).first);
    await t.pumpAndSettle();
    await t.tap(find.text(title).first);
    await t.pumpAndSettle();
  }

  // Front + back keys; OBLIQUES intentionally has none (the empty-drill case).
  final sample = <String, List<MuscleContributor>>{
    'front_delt': [c('ohp', 'Overhead Press', 13)],
    'biceps': [c('curl', 'Barbell Curl', 6)],
    'forearms': [c('hammer', 'Hammer Curl', 9)],
    'chest': [c('bench', 'Bench Press', 14), c('fly', 'Cable Fly', 3)],
    'rectus_abdominis': [c('crunch', 'Crunches', 19)],
    'quadriceps': [c('squat', 'Back Squat', 16)],
    'adductors': [c('add', 'Adductor Machine', 3)],
    'calves': [c('calf', 'Calf Raise', 12)],
    'lats': [c('pulldown', 'Lat Pulldown', 16)],
    'traps': [c('shrug', 'Barbell Shrug', 7)],
    'lower back': [c('dl', 'Deadlift', 11)],
    'rear_delt': [c('facepull', 'Face Pull', 13)],
    'triceps': [c('pushdown', 'Triceps Pushdown', 5)],
    'glutes': [c('hipthrust', 'Hip Thrust', 18)],
    'hamstrings': [c('rdl', 'Romanian Deadlift', 22)],
  };

  Widget host({bool reduceMotion = false}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: kBg,
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MuscleBodyMap(contributors: sample),
          ),
        ),
      ),
    ),
  );

  Widget dossierHost() => MaterialApp(
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
              strengthByMuscle: strengthSample,
            ),
          ),
        ),
      ),
    ),
  );

  Widget windowedHost({
    CoverageWindow window = CoverageWindow.week,
    double effectiveWeeks = 1,
    ValueChanged<CoverageWindow>? onWindowChanged,
    bool reduceMotion = true,
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: kBg,
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MuscleBodyMap(
              contributors: sample,
              window: window,
              effectiveWeeks: effectiveWeeks,
              onWindowChanged: onWindowChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> loadImages(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('back view renders after toggle', (tester) async {
    tester.view.physicalSize = const Size(820, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(reduceMotion: true));
    await loadImages(tester);
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();
    await loadImages(tester);

    await expectLater(
      find.byType(MuscleBodyMap),
      matchesGoldenFile('_body_map_back.png'),
    );
  });

  testWidgets('a Semantics label exists per muscle row', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pumpAndSettle();
    await expandGroup(tester, 'CHEST · CORE');
    expect(
      find.bySemanticsLabel(RegExp(r'CHEST, .* weekly sets, ON TRACK')),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion: renders a legible static map', (tester) async {
    tester.view.physicalSize = const Size(820, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.byType(MuscleBodyMap), findsOneWidget);
    expect(find.text('FRONT'), findsOneWidget);
    await expandGroup(tester, 'CHEST · CORE');
    expect(
      find.bySemanticsLabel(RegExp(r'CHEST, .* weekly sets')),
      findsOneWidget,
    );
  });

  testWidgets('groups are collapsed by default; tapping a header reveals rows', (
    tester,
  ) async {
    bigView(tester);
    await tester.pumpWidget(dossierHost());
    await tester.pumpAndSettle();
    // Collapsed → the CHEST meter row isn't in the tree yet.
    expect(find.bySemanticsLabel(RegExp(r'CHEST, .* weekly sets')), findsNothing);
    await expandGroup(tester, 'CHEST · CORE');
    expect(
      find.bySemanticsLabel(RegExp(r'CHEST, .* weekly sets')),
      findsOneWidget,
    );
  });

  testWidgets('tap a muscle opens its strength dossier (lifts + momentum)', (
    tester,
  ) async {
    bigView(tester);
    await tester.pumpWidget(dossierHost());
    await tester.pumpAndSettle();
    await expandGroup(tester, 'CHEST · CORE');

    await tester.tap(find.bySemanticsLabel(RegExp(r'CHEST, .* weekly sets')));
    await tester.pumpAndSettle();

    // The dossier: coverage verdict in the header, the strength roster below.
    expect(find.text('CHEST'), findsWidgets);
    expect(find.textContaining('THIS WEEK'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cable Fly'), findsOneWidget);
    expect(find.textContaining('PLATEAU'), findsNothing);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('_body_map_dossier.png'),
    );
  });

  testWidgets('a muscle with no weighted lifts shows a calm empty dossier', (
    tester,
  ) async {
    bigView(tester);
    await tester.pumpWidget(dossierHost());
    await tester.pumpAndSettle();
    await expandGroup(tester, 'CHEST · CORE');

    await tester.tap(find.bySemanticsLabel(RegExp(r'OBLIQUES, .* weekly sets')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No weighted lifts here yet'), findsOneWidget);
  });

  testWidgets('no range selector when onWindowChanged is null (pure render)', (
    tester,
  ) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('RANGE'), findsNothing);
    expect(find.text('4-WK AVG'), findsNothing);
  });

  testWidgets('range selector renders 3 chips and reports the tapped window', (
    tester,
  ) async {
    bigView(tester);
    CoverageWindow? picked;
    await tester.pumpWidget(
      windowedHost(onWindowChanged: (w) => picked = w),
    );
    await tester.pumpAndSettle();

    expect(find.text('7-DAY'), findsOneWidget);
    expect(find.text('4-WK AVG'), findsOneWidget);
    expect(find.text('12-WK AVG'), findsOneWidget);

    await tester.tap(find.text('4-WK AVG'));
    await tester.pumpAndSettle();
    expect(picked, CoverageWindow.fourWeek);
  });

  testWidgets('average window labels the unit "avg/wk" in caption + Semantics', (
    tester,
  ) async {
    bigView(tester);
    await tester.pumpWidget(
      windowedHost(window: CoverageWindow.fourWeek, effectiveWeeks: 4),
    );
    await tester.pumpAndSettle();
    await expandGroup(tester, 'CHEST · CORE');

    expect(find.text('AVG SETS/WK · LAST 4 WK'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'CHEST, .* average weekly sets, ON TRACK')),
      findsOneWidget,
    );
  });

  testWidgets('sparse-history caption shows the real span, not the nominal one', (
    tester,
  ) async {
    bigView(tester);
    await tester.pumpWidget(
      windowedHost(window: CoverageWindow.twelveWeek, effectiveWeeks: 2),
    );
    await tester.pumpAndSettle();
    expect(find.text('AVG SETS/WK · LAST 2 WK'), findsOneWidget);
  });

  testWidgets('7-day window keeps the raw "weekly sets" Semantics + 7-day caption', (
    tester,
  ) async {
    await tester.pumpWidget(windowedHost());
    await tester.pumpAndSettle();
    expect(find.text('SETS · LAST 7 DAYS'), findsOneWidget);
    await expandGroup(tester, 'CHEST · CORE');
    expect(
      find.bySemanticsLabel(RegExp(r'CHEST, .* weekly sets, ON TRACK')),
      findsOneWidget,
    );
  });

  testWidgets('F3: dossier lift → history → back returns to the map, no sheet', (
    tester,
  ) async {
    bigView(tester);
    await tester.pumpWidget(dossierHost());
    await tester.pumpAndSettle();
    await expandGroup(tester, 'CHEST · CORE');

    await tester.tap(find.bySemanticsLabel(RegExp(r'CHEST, .* weekly sets')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    // Sheet is gone, history is pushed over the map.
    expect(find.text('Cable Fly'), findsNothing);
    expect(find.byType(ExerciseHistoryPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MuscleBodyMap), findsOneWidget);
    expect(find.byType(ExerciseHistoryPage), findsNothing);
  });
}
