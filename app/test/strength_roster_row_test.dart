import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/services/strength_trend_service.dart';
import 'package:workout_track/services/unit_settings_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/strength_roster_row.dart';

/// The reworked roster row: a verdict GLYPH (not a word) per momentum, the amber
/// flourish reserved for a real new best, a body-neutral (never red) down state,
/// and a self-honest "estimated max" Semantics label.
StrengthTrend _trend(String name, List<double> pts) {
  var best = pts.first;
  for (final p in pts) {
    if (p > best) best = p;
  }
  return StrengthTrend(
    exerciseId: name,
    exerciseName: name,
    e1rmPoints: pts,
    sessionCount: pts.length,
    firstE1rm: pts.first,
    bestE1rm: best,
    lastE1rm: pts.last,
    lastDate: DateTime(2026, 1, 1),
  );
}

final _newBest = _trend('Romanian Deadlift', const [200, 210, 220, 234]);
final _rising = _trend('Incline Dumbbell Press', const [180, 200, 190, 195]);
final _holding = _trend('Dumbbell Shoulder Press', const [100, 101, 100, 100.5]);
final _rebuilding = _trend('Triceps Pushdown', const [120, 118, 116, 114]);
final _fresh = _trend('Barbell Squat', const [150]);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Units.weight = WeightUnit.kg;
  });

  Future<void> pumpRow(WidgetTester tester, StrengthTrend t) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: kBg,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StrengthRosterRow(trend: t, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('momentum maps to a distinct verdict glyph', (tester) async {
    await pumpRow(tester, _newBest);
    expect(find.byIcon(Icons.star_sharp), findsOneWidget);

    await pumpRow(tester, _rising);
    expect(find.byIcon(Icons.arrow_upward_sharp), findsOneWidget);

    await pumpRow(tester, _holding);
    expect(find.byIcon(Icons.remove_sharp), findsOneWidget);
    expect(find.text('holding steady'), findsOneWidget);
  });

  testWidgets('rebuilding is a muted down glyph — never red', (tester) async {
    await pumpRow(tester, _rebuilding);
    final glyph = tester.widget<Icon>(find.byIcon(Icons.arrow_downward_sharp));
    expect(glyph.color, kMutedText);
    expect(glyph.color, isNot(kDanger));
  });

  testWidgets('only a real new best gets the amber star + accent', (
    tester,
  ) async {
    await pumpRow(tester, _rising);
    expect(find.byIcon(Icons.star_sharp), findsNothing);
    await pumpRow(tester, _holding);
    expect(find.byIcon(Icons.star_sharp), findsNothing);
  });

  testWidgets('the row is one labelled button saying "estimated max"', (
    tester,
  ) async {
    await pumpRow(tester, _newBest);
    expect(
      find.bySemanticsLabel(
        RegExp(r'Romanian Deadlift, new best, estimated max'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('roster rows golden (all five momentum states)', (tester) async {
    tester.view.physicalSize = const Size(430, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: kBg,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              key: const ValueKey('roster'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in [_newBest, _rising, _holding, _rebuilding, _fresh])
                  Padding(
                    padding: const EdgeInsets.only(bottom: kSpace2),
                    child: StrengthRosterRow(trend: t, onTap: () {}),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('roster')),
      matchesGoldenFile('goldens/strength_roster_rows.png'),
    );
  });
}
