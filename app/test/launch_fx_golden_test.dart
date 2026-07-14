import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/room/launch_fx.dart';

/// Rendered-artifact + determinism lock for the send-off particle system
/// (seeded once, positions a pure function of elapsed). Three phases: the
/// ignition burst + core flash, the ascent (vapor trail + speed-streaks), and
/// the exit-pop at the top. Regenerate with `flutter test --update-goldens`.
void main() {
  Future<void> shot(WidgetTester t, double elapsed, String file) async {
    final sparks = generateLaunchSparks(
      seed: 7,
      emitterX: 200,
      emitterY: 400,
      exitY: 40,
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('fx'),
              child: SizedBox(
                width: 400,
                height: 460,
                child: CustomPaint(
                  painter: LaunchFxPainter(
                    sparks: sparks,
                    elapsedMs: elapsed,
                    emitterX: 200,
                    bitCenterY: 240,
                    bitSpan: 320,
                    kx: 1.0,
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
      find.byKey(const ValueKey('fx')),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('ignition burst + core', (t) => shot(t, 420, 'launch_fx_ignition.png'));
  testWidgets('ascent trail + streaks', (t) => shot(t, 820, 'launch_fx_ascent.png'));
  testWidgets('exit pop', (t) => shot(t, 1480, 'launch_fx_exit.png'));
}
