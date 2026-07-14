import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/bit_hologram.dart';

/// Locks the hologram **ignition envelope** to the handoff's `holo-bit.js`
/// `igniteEnv` — the struggling-tube power-on (the layer-1 control model). The
/// exact keyframe levels and the ≥900ms plateau are the spec; a transcription
/// slip here is exactly the failure the port discipline guards against.
void main() {
  // Verbatim from holo-bit.js `igniteEnv` K-table: [ms, level].
  const keyframes = <List<double>>[
    [0, 0.0],
    [50, 0.9],
    [110, 0.04],
    [180, 0.62],
    [250, 0.0],
    [300, 0.72],
    [380, 0.08],
    [440, 1.0],
    [520, 0.18],
    [600, 0.92],
    [700, 0.4],
    [820, 1.0],
    [900, 1.0],
  ];

  test('igniteEnv hits every source keyframe exactly', () {
    for (final kf in keyframes) {
      expect(
        BitHologramPainter.igniteEnv(kf[0]),
        closeTo(kf[1], 1e-9),
        reason: 'ignition level at ${kf[0]}ms must match holo-bit.js',
      );
    }
  });

  test('igniteEnv interpolates linearly between keyframes', () {
    // 80ms sits halfway between [50,0.9] and [110,0.04] → 0.47.
    expect(BitHologramPainter.igniteEnv(80), closeTo(0.47, 1e-9));
    // 340ms is halfway between [300,0.72] and [380,0.08] → 0.40.
    expect(BitHologramPainter.igniteEnv(340), closeTo(0.40, 1e-9));
  });

  test('igniteEnv is fully online (1.0) at and past 900ms', () {
    expect(BitHologramPainter.igniteEnv(900), 1.0);
    expect(BitHologramPainter.igniteEnv(1200), 1.0);
    expect(BitHologramPainter.igniteEnv(5000), 1.0);
  });

  test('a null ignition start renders the steady projection (online)', () {
    // The painter with no ignitionStartSeconds is the steady "online" hologram
    // the static golden locks — ign collapses to 1.0, so nothing about the
    // online render changes.
    final clock = ValueNotifier<double>(2.0);
    addTearDown(clock.dispose);
    final painter = BitHologramPainter(time: clock, reduceMotion: false);
    expect(painter.ignitionStartSeconds, isNull);
    // Repaints when an ignition start is introduced (the gap → flicker flip).
    final igniting = BitHologramPainter(
      time: clock,
      reduceMotion: false,
      ignitionStartSeconds: 2.0,
    );
    expect(igniting.shouldRepaint(painter), isTrue);
  });
}
