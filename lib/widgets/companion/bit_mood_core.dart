import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'bit_core_engine.dart';

/// BIT's faceless mood, expressed by **body language only** — posture, vertical
/// motion, slump, and glow. Faceless by default (`reveal` 0); `reveal` 0→1 opens
/// the eyes for the Solution-screen face reveal (screen 3), so BIT reads as the
/// same companion that woke in the cold open.
///
/// - **cheer** — plates spread + lifted, buoyant bob, bright lamps/glow.
/// - **rest** — plates drawn in + sunk, a slump tilt, slow bob, dimmed.
/// - **neutral** — level, steady, medium glow; its silhouette matches
///   [BitBootCore]'s settled frame so the cold-open → problem cut is seamless.
///
/// Changing [pose] eases between states; reduced motion snaps to the target and
/// freezes the idle clock (a still, legible posed frame).
enum BitPose { cheer, neutral, rest }

// ── motion tuning (native units; on-device feel knobs) ───────────────────────
/// Gentle follow-through on the rest→cheer surge (default easeOutBack `s` is
/// 1.70158 — too springy for a *weighty* power-up; the wind-up is carried by
/// [BitMoodCore.anticipation], not the curve).
const double _kBurstBack = 1.0;

/// Slow plate breathe amplitude, on a period decoupled from the bob so they
/// never lock (≈4s vs the bob's ≈4.2s) — keeps the idle organic, not mechanical.
const double _kBreatheAmp = 0.4;

/// Anticipation coil depths (full `anticipation` = 1): BIT sinks [_kAnticSink],
/// draws its plates in [_kAnticDraw], and dims by [_kAnticDim] — the "inhale".
const double _kAnticSink = 4.0;
const double _kAnticDraw = 1.5;
const double _kAnticDim = 0.45;

class BitMoodCore extends StatefulWidget {
  const BitMoodCore({
    super.key,
    this.pose = BitPose.neutral,
    this.size = 264,
    this.freezeBob = false,
    this.reveal = 0,
    this.blink = false,
    this.anticipation = 0,
    this.idleAmp = 1,
  });

  final BitPose pose;
  final double size;

  /// When true, the idle bob + breathe are pinned to 0 (a held, still frame).
  /// The problem screen sets this during the entry/drift window so BIT's first
  /// frames are deterministic and the cut from the cold open's settled
  /// BitBootCore stays pixel-identical.
  final bool freezeBob;

  /// The "inhale" before the screen-3 surge: 0 = none, 1 = full coil. The
  /// painter applies a **bounded, in-domain** gather — BIT sinks, draws its
  /// plates in, and dims — so the burst reads as a wind-up → release rather than
  /// a cold launch. Driven by the Solution timeline; 0 everywhere else.
  final double anticipation;

  /// Idle amplitude 0..1 for the bob + breathe — ramped 0→1 (instead of a hard
  /// unfreeze) so the float fades in after the burst's hitstop hold with no step
  /// pop. 1 (full idle) by default; gated to 0 by [freezeBob]/reduced motion.
  final double idleAmp;

  /// Face-reveal progress: **0 = faceless calm dot** (screens 1–2), **1 = the
  /// full neutral face** (eyes open). Drives the screen-3 "BIT opens its eyes"
  /// beat; left at 0 everywhere else, so the faceless mood is unchanged.
  final double reveal;

  /// Forces a single blink — the reveal's "sign of life" punctuation. Once
  /// [reveal] is settled BIT also blinks on its own idle cadence.
  final bool blink;

  @override
  State<BitMoodCore> createState() => _BitMoodCoreState();
}

class _BitMoodCoreState extends State<BitMoodCore>
    with TickerProviderStateMixin {
  Ticker? _ticker; // perpetual idle: bob + glow shimmer
  final ValueNotifier<double> _time = ValueNotifier<double>(5.0);
  // Eases body language from the previous pose to the current one.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late _PoseSpec _from = _specFor(widget.pose);
  late _PoseSpec _to = _specFor(widget.pose);
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _ticker?.stop();
      _time.value = 5.0; // frozen idle frame
      _morph.value = 1; // snap to the target pose
    } else {
      _ticker ??= createTicker((d) => _time.value = d.inMicroseconds / 1e6);
      if (!_ticker!.isActive) _ticker!.start();
    }
  }

  @override
  void didUpdateWidget(BitMoodCore old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) {
      _from = _PoseSpec.blend(_from, _to, _morph.value); // current displayed
      _to = _specFor(widget.pose);
      if (_reduce) {
        _morph.value = 1;
      } else {
        _morph.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'BIT, your companion',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _morph,
          builder: (context, _) {
            // Bursting INTO cheer follows through with a *gentle* overshoot
            // (weighty, not bouncy — the wind-up comes from `anticipation`, not
            // the curve); every other morph (incl. the cheer→neutral settle)
            // eases out calmly.
            final morphT = widget.pose == BitPose.cheer
                ? easeOutBack(_morph.value, _kBurstBack)
                : Curves.easeOutCubic.transform(_morph.value);
            return CustomPaint(
              painter: _BitMoodPainter(
                time: _time,
                spec: _PoseSpec.blend(_from, _to, morphT),
                reduceMotion: _reduce,
                freezeBob: widget.freezeBob,
                reveal: widget.reveal,
                blink: widget.blink,
                anticipation: widget.anticipation,
                idleAmp: widget.idleAmp,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The body-language parameters for a pose (all lerp-able for smooth morphs).
@immutable
class _PoseSpec {
  const _PoseSpec({
    required this.radiusDelta,
    required this.yOffset,
    required this.tilt,
    required this.glow,
    required this.bobAmp,
    required this.cheer,
  });

  final double radiusDelta; // plate spread (+) / drawn-in (−), native units
  final double yOffset; // lift (−) / sink (+), native units
  final double tilt; // slump, radians
  final double glow; // 0..1 lamp/screen/bloom brightness
  final double bobAmp; // idle bob amplitude
  final double cheer; // 0 neutral (turquoise) … 1 cheer (amber + grin)

  static _PoseSpec blend(_PoseSpec a, _PoseSpec b, double t) => _PoseSpec(
    radiusDelta: lerp(a.radiusDelta, b.radiusDelta, t),
    yOffset: lerp(a.yOffset, b.yOffset, t),
    tilt: lerp(a.tilt, b.tilt, t),
    glow: lerp(a.glow, b.glow, t),
    bobAmp: lerp(a.bobAmp, b.bobAmp, t),
    cheer: lerp(a.cheer, b.cheer, t),
  );

  @override
  bool operator ==(Object other) =>
      other is _PoseSpec &&
      other.radiusDelta == radiusDelta &&
      other.yOffset == yOffset &&
      other.tilt == tilt &&
      other.glow == glow &&
      other.bobAmp == bobAmp &&
      other.cheer == cheer;

  @override
  int get hashCode =>
      Object.hash(radiusDelta, yOffset, tilt, glow, bobAmp, cheer);
}

_PoseSpec _specFor(BitPose pose) => switch (pose) {
  BitPose.cheer => const _PoseSpec(
    radiusDelta: 2.5, // plates burst wider (energy); easeOutBack overshoots it
    yOffset: -2,
    tilt: 0,
    glow: 1,
    bobAmp: 1.6,
    cheer: 1,
  ),
  BitPose.neutral => const _PoseSpec(
    radiusDelta: 0,
    yOffset: 0,
    tilt: 0,
    glow: 0.7,
    bobAmp: 1,
    cheer: 0,
  ),
  BitPose.rest => const _PoseSpec(
    radiusDelta: -1,
    yOffset: 3,
    tilt: 0.13,
    glow: 0.3,
    bobAmp: 0.5,
    cheer: 0,
  ),
};

class _BitMoodPainter extends CustomPainter {
  _BitMoodPainter({
    required this.time,
    required this.spec,
    required this.reduceMotion,
    required this.freezeBob,
    required this.reveal,
    required this.blink,
    required this.anticipation,
    required this.idleAmp,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final _PoseSpec spec;
  final bool reduceMotion;
  final bool freezeBob; // pin the idle bob + breathe to 0 (deterministic seam)
  final double reveal; // 0 = faceless dot, 1 = full neutral face
  final bool blink; // forced single blink (reveal punctuation)
  final double anticipation; // 0..1 wind-up coil before the surge
  final double idleAmp; // 0..1 bob/breathe amplitude (ramped to avoid a pop)

  static const int _gx = 2, _gy = 2;
  static const double _cx = bitCoreCx, _cy = bitCoreCy;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44.0;
    final t = reduceMotion ? 5.0 : time.value;
    final antic = anticipation.clamp(0.0, 1.0);
    // Glow dims through the anticipation inhale; clamped to 0..1 (the surge's
    // gentle overshoot can push the blended glow a hair past cheer's 1.0).
    final glow = (spec.glow * (1 - _kAnticDim * antic)).clamp(0.0, 1.0);
    // BIT's light lerps turquoise→amber as it cheers (the soft, circular bloom
    // that replaced the square StrobeFlash on screen 3). Gated by [reveal] so a
    // FACELESS cheer (screen 2's greeting, reveal 0) stays turquoise — only the
    // revealed cheer face on screen 3 glows amber.
    final faceGlow =
        Color.lerp(bitGlow, bitCheerGlow, (spec.cheer * reveal).clamp(0.0, 1.0))!;
    final pal = glow > 0.45 ? metal : dim;
    // Idle: smooth sub-pixel float + a slow, decoupled plate breathe (no
    // `.round()` → continuous), faded in via idleAmp (no resume pop) and zeroed
    // when frozen / reduced-motion (a clean still home, not a frozen sample).
    final amp = (freezeBob || reduceMotion) ? 0.0 : idleAmp.clamp(0.0, 1.0);
    final bob = amp * math.sin(t * 1.5) * spec.bobAmp;
    final breathe = amp * math.sin(t * 1.6 + 1.3) * _kBreatheAmp;
    // Anticipation coil: BIT sinks + draws its plates in (the "inhale") before
    // the surge; the same offset rides the core + face so they move as one body.
    final vy = spec.yOffset + _kAnticSink * antic + bob;
    final cy = _cy + vy;
    final radius =
        plateRadius + dockGap + spec.radiusDelta - _kAnticDraw * antic + breathe;

    // Hover under-glow pool — brightness tracks the mood.
    final poolOp =
        ((0.30 + 0.22 * math.max(0.0, math.sin(t * 1.5))) * glow).clamp(
          0.0,
          1.0,
        );
    if (poolOp > 0.01) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_cx * s, 39 * s),
          width: 26 * s,
          height: 9 * s,
        ),
        Paint()
          ..color = faceGlow.withValues(alpha: poolOp * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2 * s),
      );
    }

    // Sprite transform: the slump tilt around the core centre (clamped ≥0 so the
    // surge's overshoot never produces a reverse lean).
    canvas.save();
    final pivotX = _cx * s, pivotY = cy * s;
    canvas.translate(pivotX, pivotY);
    final tilt = math.max(0.0, spec.tilt);
    if (tilt > 1e-4) canvas.rotate(tilt);
    canvas.translate(-pivotX, -pivotY);

    // Screen bloom halo — brightness tracks the mood (circle ⇒ tilt-invariant).
    final bloomOp = (0.6 * glow).clamp(0.0, 1.0);
    if (bloomOp > 0.01) {
      canvas.drawCircle(
        Offset(_cx * s, cy * s),
        11 * s,
        Paint()
          ..color = faceGlow.withValues(alpha: bloomOp)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.2 * s),
      );
    }

    // Docked plates (no spin) at the mood radius, then the core + faceless
    // screen.
    for (final pl in plates) {
      orbitPlate(canvas, pl, s, radius, 0, _cx, cy, pal, 1);
    }
    drawGrid(
      canvas,
      coreGrid,
      s,
      (_gx + 12).toDouble(),
      _gy + 12 + vy,
      pal,
    );
    final pulse = reduceMotion ? 0.0 : 0.5 + 0.5 * math.sin(t * 2.0);
    // Once settled-revealed, BIT blinks on its own idle cadence; the caller can
    // also force the reveal's "sign of life" punctuation blink.
    final autoBlink = reveal > 0.95 && !reduceMotion && (t % 3.4) < 0.11;
    drawBitFace(
      canvas,
      s,
      (_gx + 15).toDouble(),
      _gy + 15 + vy,
      reveal: reveal,
      cheer: spec.cheer,
      blink: blink || autoBlink,
      glow: glow,
      pulse: pulse,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BitMoodPainter old) =>
      old.reduceMotion != reduceMotion ||
      old.spec != spec ||
      old.freezeBob != freezeBob ||
      old.reveal != reveal ||
      old.blink != blink ||
      old.anticipation != anticipation ||
      old.idleAmp != idleAmp;
}
