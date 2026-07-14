import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/target_body_preview.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(backgroundColor: kBg, body: Center(child: child)),
  );

  testWidgets('shows a TARGETS line naming the primary muscles', (tester) async {
    await tester.pumpWidget(
      host(
        const TargetBodyPreview(
          primaryMuscles: {'chest', 'triceps'},
          secondaryMuscles: {'front_delt'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('TARGETS:'), findsOneWidget);
    expect(find.textContaining('CHEST'), findsWidgets);
    expect(find.textContaining('TRICEPS'), findsWidgets);
  });

  testWidgets('exposes the targets as a Semantics label (non-color a11y)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TargetBodyPreview(
          primaryMuscles: {'chest'},
          secondaryMuscles: {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r"Today's targets: .*CHEST")),
      findsOneWidget,
    );
  });

  testWidgets('empty selection → calm prompt, no targets line', (tester) async {
    await tester.pumpWidget(
      host(
        const TargetBodyPreview(primaryMuscles: {}, secondaryMuscles: {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Pick exercises to light'), findsOneWidget);
    expect(find.textContaining('TARGETS:'), findsNothing);
  });

  testWidgets('golden — front + back, primary bright / secondary dim', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        const TargetBodyPreview(
          primaryMuscles: {'chest', 'lats', 'biceps'},
          secondaryMuscles: {'triceps', 'rear_delt'},
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final el in find.byType(Image).evaluate()) {
        await precacheImage((el.widget as Image).image, el);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TargetBodyPreview),
      matchesGoldenFile('_target_body_preview.png'),
    );
  });
}
