import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/arcade_route.dart';

void main() {
  for (final motion in ArcadeRouteMotion.values) {
    testWidgets('arcadeRoute pushes ${motion.name} route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  arcadeRoute(
                    (_) => const Scaffold(body: Text('DESTINATION')),
                    motion: motion,
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('DESTINATION'), findsOneWidget);
    });
  }

  testWidgets('arcadeRoute reduced motion still pushes destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  arcadeRoute(
                    (_) => const Scaffold(body: Text('REDUCED')),
                    motion: ArcadeRouteMotion.reveal,
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('REDUCED'), findsOneWidget);
  });

  testWidgets('arcadeRoute reverse transition pops without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                arcadeRoute(
                  (_) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CLOSE'),
                    ),
                  ),
                  motion: ArcadeRouteMotion.flow,
                ),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('CLOSE'), findsOneWidget);

    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('CLOSE'), findsNothing);
  });
}
