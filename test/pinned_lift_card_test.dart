import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/services/strength_trend_service.dart';
import 'package:workout_track/services/unit_settings_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/pinned_lift_card.dart';

/// The pinned "anchor lift" card — the one rich surface (verdict word + sparkline
/// + PR marker + mastery line), with a distinct tap (history) and pin-icon
/// (unpin).
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
    lastDate: DateTime(2026, 1, 5),
  );
}

final _newBest = _trend('Barbell Bench Press', const [180, 188, 192, 196]);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Units.weight = WeightUnit.kg;
  });

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onTap,
    VoidCallback? onUnpin,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: kBg,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PinnedLiftCard(
              trend: _newBest,
              onTap: onTap ?? () {},
              onUnpin: onUnpin ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the rich read (word, mastery count, est max)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('NEW BEST'), findsOneWidget); // the WORD, unlike the rows
    expect(find.textContaining('trained 4×'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_sharp), findsOneWidget);
  });

  testWidgets('the pin icon unpins; the body opens history', (tester) async {
    var unpinned = false;
    var opened = false;
    await pump(
      tester,
      onTap: () => opened = true,
      onUnpin: () => unpinned = true,
    );

    await tester.tap(find.byIcon(Icons.push_pin_sharp));
    expect(unpinned, isTrue);
    expect(opened, isFalse); // the pin tap did not bubble to the card tap

    await tester.tap(find.text('Barbell Bench Press'));
    expect(opened, isTrue);
  });

  testWidgets('long-press unpins (mirrors hold-a-row-to-pin)', (tester) async {
    var unpinned = false;
    await pump(tester, onUnpin: () => unpinned = true);
    await tester.longPress(find.byType(PinnedLiftCard));
    expect(unpinned, isTrue);
  });

  testWidgets('pinned card golden', (tester) async {
    tester.view.physicalSize = const Size(430, 220);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pump(tester);
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PinnedLiftCard),
      matchesGoldenFile('goldens/pinned_lift_card.png'),
    );
  });
}
