import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/room/bit_pad_beam.dart';

/// Rendered-artifact lock for the send-off beam: it brightens **in place**
/// (scale) and withdraws into the emitter (topY01) — it must NOT extend past
/// BIT. Three states at a fixed clock. Regenerate with `--update-goldens`.
void main() {
  Future<void> shot(
    WidgetTester t, {
    required double scale,
    required double topY01,
    required String file,
  }) async {
    final clock = ValueNotifier<double>(1.0);
    addTearDown(clock.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('beam'),
              child: SizedBox(
                width: 120,
                height: 156, // 20:26 cell aspect
                child: CustomPaint(
                  painter: BitPadBeamPainter(
                    time: clock,
                    reduceMotion: true, // steady frame
                    scale: scale,
                    topY01: topY01,
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
      find.byKey(const ValueKey('beam')),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('rest', (t) => shot(t, scale: 1.0, topY01: 0, file: 'beam_rest.png'));
  testWidgets('send-off bright', (t) => shot(t, scale: 1.15, topY01: 0, file: 'beam_sendoff.png'));
  testWidgets('collapse withdraw', (t) => shot(t, scale: 0.4, topY01: 0.6, file: 'beam_collapse.png'));
}
