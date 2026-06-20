import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/adventure/bit_route_walker.dart';

/// Rendered-artifact + determinism lock for BIT's side-view hover-glide — the
/// faithful port of `handoff_bit_route_walk/engine/bit-walk.js`. Captures the
/// bob extremes, the blink pose, and the thrust trail on/off. Motion (bob,
/// blink cadence, the streaming trail) is a function of the clock and can't be
/// proven by a static frame — that needs on-device sign-off.
/// Regenerate with `flutter test --update-goldens`.
void main() {
  const accent = Color(0xFFFF6A3D); // Iron Vault ember — tints the shimmer

  Future<void> shot(
    WidgetTester t,
    double tMs,
    double speed,
    String file,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('bit'),
              child: ColoredBox(
                color: kBg,
                child: BitRouteWalker(
                  tMs: tMs,
                  accent: accent,
                  speed: speed,
                  scale: 6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await expectLater(
      find.byKey(const ValueKey('bit')),
      matchesGoldenFile('goldens/$file'),
    );
  }

  // bob peak at t≈471 (sin=1), trough at t≈1414 (sin=-1); blink while tMs%3500<110.
  testWidgets('still / idle (no trail)', (t) => shot(t, 0, 0, 'bit_walk_still.png'));
  testWidgets('glide bob peak + trail', (t) => shot(t, 471, 40, 'bit_walk_glide_peak.png'));
  testWidgets('glide bob trough + trail', (t) => shot(t, 1414, 40, 'bit_walk_glide_trough.png'));
  testWidgets('blink pose', (t) => shot(t, 50, 0, 'bit_walk_blink.png'));
}
