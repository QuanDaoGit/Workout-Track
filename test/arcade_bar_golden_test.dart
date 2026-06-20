import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/arcade_bar.dart';

/// Rendered-artifact proof for the canonical [ArcadeBar] — the dimensional
/// segmented bar that replaces every flat fill. Reduced motion so cells are
/// static. Regenerate with `flutter test --update-goldens`.
void main() {
  testWidgets('arcade bar — states', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: SizedBox(
                key: const ValueKey('bars'),
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    ArcadeBar(value: 0.84, accent: kAmber, height: 12),
                    SizedBox(height: 18),
                    ArcadeBar(value: 0.5),
                    SizedBox(height: 18),
                    ArcadeBar.segments(litCells: 10, totalCells: 24),
                    SizedBox(height: 18),
                    ArcadeBar(value: 1, accent: kCyan, height: 12),
                    SizedBox(height: 18),
                    ArcadeBar(value: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey('bars')),
      matchesGoldenFile('goldens/arcade_bar.png'),
    );
  });
}
