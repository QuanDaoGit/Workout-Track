import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/room/bit_hologram.dart';

/// Rendered-artifact lock for the away hologram (BIT's real sprite + the
/// projection rig). Two frames at a fixed clock: the normal projection and a
/// forced glitch slice (the band offset). A fixed `time` notifier ⇒ no ticker,
/// deterministic. Regenerate with `flutter test --update-goldens`.
void main() {
  Future<void> shot(
    WidgetTester t, {
    required bool glitch,
    required String file,
  }) async {
    final clock = ValueNotifier<double>(2.0);
    addTearDown(clock.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('holo'),
              child: SizedBox(
                width: 150,
                height: 250,
                child: CustomPaint(
                  painter: BitHologramPainter(
                    time: clock,
                    reduceMotion: false,
                    forceGlitch: glitch,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await expectLater(
      find.byKey(const ValueKey('holo')),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('hologram projection', (t) => shot(t, glitch: false, file: 'bit_hologram.png'));
  testWidgets('hologram glitch slice', (t) => shot(t, glitch: true, file: 'bit_hologram_glitch.png'));
}
