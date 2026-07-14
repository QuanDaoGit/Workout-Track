import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'bit_core_engine.dart';

/// BIT's faceless **drone-core** for the onboarding cold-open boot. The shared
/// sprite engine (grids, palettes, plate ring, painters) lives in
/// [bit_core_engine.dart]; this widget owns the **boot choreography** — BIT lies
/// slumped on the floor, the user taps, it flickers awake, gathers, flies up to
/// its hover home, and the plates spin out as it speaks — on its own `Ticker`
/// clock. The inset screen is deliberately **faceless** (the eyes/gaze are saved
/// for the start gate). Reduced motion → a static settled+lit frame.
class BitBootCore extends StatefulWidget {
  const BitBootCore({
    super.key,
    this.width = 264,
    this.height = 264,
    this.boot = 1,
    this.freezeBob = false,
  });

  final double width;
  final double height;

  /// Boot progress 0..1. `0` = DORMANT (BIT slumped on the floor, dark, plates
  /// clamped, a pulsing standby ember). The parent animates it to 1 as the user
  /// wakes BIT: accelerating flicker → gather → fly up to its hover home →
  /// plates spin out as it speaks (`kBitSpeakAt`) → settle (`kBitSettleAt`).
  /// Defaults to 1 (fully booted, hovering) for standalone use.
  final double boot;

  /// When true, the settled idle bob/breathe are pinned to 0 (a held, still
  /// frame). The cold open sets this once BIT is settled so its resting frame is
  /// deterministic and the BitBootCore→BitMoodCore hand-off at the problem cut
  /// stays pixel-identical (no ≤1px bob/breathe pop).
  final bool freezeBob;

  @override
  State<BitBootCore> createState() => _BitBootCoreState();
}

class _BitBootCoreState extends State<BitBootCore>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker; // perpetual idle: standby ember, bob, scan, cursor
  final ValueNotifier<double> _time = ValueNotifier<double>(5.0);
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _ticker?.stop();
      _time.value = 5.0; // frozen idle frame
    } else {
      _ticker ??= createTicker((d) {
        _time.value = d.inMicroseconds / 1e6;
      });
      if (!_ticker!.isActive) _ticker!.start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final off = widget.boot <= 0;
    return Semantics(
      button: off,
      label: off ? 'Power on BIT' : 'BIT, your companion',
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _BitBootPainter(
            time: _time,
            boot: widget.boot,
            reduceMotion: _reduce,
            freezeBob: widget.freezeBob,
          ),
        ),
      ),
    );
  }
}

// ── boot phases (driven by the `boot` 0..1 progress) ────────────────────────
// The wake is one ordered sequence sampled by `boot`:
//   DORMANT 0 · STIR (0, _kFlickerEnd] · GATHER (_kFlickerEnd, _kGatherEnd] ·
//   FLY UP (_kGatherEnd, kBitSpeakAt] · SPIN+SPEAK (kBitSpeakAt, kBitSettleAt] ·
//   SETTLE (kBitSettleAt, 1]
/// Plates spin out and the spoken greeting starts here — exported so the cold
/// open syncs the line to the spin.
const double kBitSpeakAt = 0.58;

/// BIT reaches its hover home and idles; the cold open reveals its chrome here.
const double kBitSettleAt = 0.92;

// Re-budgeted for a slower spin: flicker/gather/rise keep their absolute timing
// at the cold open's 3000ms controller; the extra time all goes to the stretch.
const double _kFlickerEnd = 0.33; // accelerating flicker fills (0, this]
const double _kGatherEnd = 0.38; // brief anticipation crouch before the launch

const double _stuckRadius = 10.0; // plates clamped to the body (grounded)
const double _detachedRadius = plateRadius + dockGap; // 14 — orbiting dock

const double _groundDrop = 28.0; // native units BIT rests below its hover home
const double _restTilt = 0.20; // rad (~11°) slump while dormant; rights on launch
const double _crouchDepth = 2.5; // extra dip during the gather (anticipation)
const double _backOvershoot = 1.0; // easeOutBack strength on the rise

/// BIT's heartbeat coming online: an accelerating CRT flicker across STIR
/// (`f` 0..1). Blinks start **super slow and bunch faster** (phase grows
/// quadratically) and the dark troughs **lift** as it warms — a strengthening
/// pulse, never a failing/erroring device — before fusing to steady light.
/// Pure function of `f` ⇒ deterministic for goldens.
double _stirLevel(double f) {
  if (f >= 0.85) return 1; // caught — steady lit
  final phase = 10.0 * f * f; // quadratic ⇒ accelerating blink cadence
  final blink = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
  final floorLevel = lerp(0.06, 0.55, f); // troughs rise as it stirs
  return (floorLevel + (1 - floorLevel) * math.pow(blink, 2.2).toDouble())
      .clamp(0.0, 1.0);
}

// ── painter ─────────────────────────────────────────────────────────────────
class _BitBootPainter extends CustomPainter {
  _BitBootPainter({
    required this.time,
    required this.boot,
    required this.reduceMotion,
    required this.freezeBob,
  }) : super(repaint: time);

  final ValueNotifier<double> time; // perpetual idle clock
  final double boot; // 0..1 boot progress (OFF → flicker → spin → settled)
  final bool reduceMotion;
  final bool freezeBob; // pin settled bob/breathe to 0 for a deterministic seam

  static const int _gx = 2, _gy = 2;
  static const double _cx = bitCoreCx, _cy = bitCoreCy; // core centre (native)

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44.0;
    final t = reduceMotion ? 5.0 : time.value; // idle clock
    final b = boot.clamp(0.0, 1.0);
    final off = b <= 0;

    // Screen level: dark when off; an accelerating flicker across STIR; then a
    // steady live shimmer once it's caught.
    final double lvl;
    if (off) {
      lvl = 0;
    } else if (b < _kFlickerEnd) {
      lvl = _stirLevel(b / _kFlickerEnd);
    } else {
      lvl = 0.92 + 0.08 * math.sin(t * 22);
    }
    // Loading bar + corner brackets fill during the flicker/stir.
    final bar = (b / _kFlickerEnd).clamp(0.0, 1.0);

    // Rise: BIT lies on the floor (vShift = _groundDrop), crouches through the
    // gather, then launches to its hover home (vShift → 0) with an
    // overshoot-settle. The slump tilt rights itself across the same window.
    final rise = phaseProgress(b, _kGatherEnd, kBitSpeakAt);
    final riseEased = easeOutBack(rise, _backOvershoot);
    final gather = phaseProgress(b, _kFlickerEnd, _kGatherEnd);
    final crouch = _crouchDepth * math.sin(math.pi * gather);
    final vShift = lerp(_groundDrop, 0.0, riseEased) + crouch;
    final airborne = riseEased.clamp(0.0, 1.0); // 0 grounded → 1 risen
    final tilt = lerp(
      _restTilt,
      0.0,
      easeInOutQuad(phaseProgress(b, _kFlickerEnd, kBitSpeakAt)),
    );

    // Plate spin: clamped until kBitSpeakAt, then one slow, strongly-eased
    // revolution out to the detached dock — a deliberate "warm-up stretch", not
    // a whip (lands crisp at 2π ≡ 0).
    final sp = b <= kBitSpeakAt
        ? 0.0
        : phaseProgress(b, kBitSpeakAt, kBitSettleAt);
    final spinAngle = Curves.easeInOutCubic.transform(sp) * 2 * math.pi;
    final spinExpand = 5 * math.sin(math.pi * sp);
    final spinFade = math.sin(math.pi * sp);

    // Boot complete → idle: fade the loading UI to the calm faceless glow.
    final settle = ((b - kBitSettleAt) / (1.0 - kBitSettleAt)).clamp(0.0, 1.0);
    // Settled idle: smooth sub-pixel float + a slow, decoupled **bidirectional**
    // plate breathe, faded in with the settle (no pop) and zeroed when frozen /
    // reduced-motion (a clean still home, not a `.round()`-stepped frozen sample).
    final idle = (freezeBob || reduceMotion) ? 0.0 : settle;
    final bob = idle * math.sin(t * 1.5);
    final breathe = idle * math.sin(t * 1.6 + 1.3) * 0.6;
    final radius = lerp(_stuckRadius, _detachedRadius, sp) + spinExpand + breathe;
    final pal = lvl > 0.3 ? metal : dim;
    final cy = _cy + bob + vShift;

    // Ground contact-glow + launch dust — flat on the floor (outside the slump
    // tilt) so BIT reads as resting on, then lifting off, its own pooled light.
    _drawGroundFx(canvas, s, t, b, airborne);

    // Settled hover under-glow — cross-fades in as the ground pool releases.
    final hoverPoolOp =
        (airborne *
                (0.32 + 0.26 * math.max(0.0, math.sin(t * 1.5))) *
                (0.35 + 0.65 * lvl))
            .clamp(0.0, 1.0);
    if (lvl > 0.01 && hoverPoolOp > 0.01) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_cx * s, 39 * s),
          width: 26 * s,
          height: 9 * s,
        ),
        Paint()
          ..color = bitGlow.withValues(alpha: hoverPoolOp * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2 * s),
      );
    }

    // Sprite transform: a one-shot power-up zoom + the slump tilt, both around
    // the (possibly grounded) core centre.
    canvas.save();
    final pivotX = _cx * s, pivotY = cy * s;
    canvas.translate(pivotX, pivotY);
    if (spinFade > 0.001) canvas.scale(1 + 0.04 * spinFade);
    if (tilt.abs() > 1e-4) canvas.rotate(tilt);
    canvas.translate(-pivotX, -pivotY);

    // Screen bloom halo — flares on the power-up (circle ⇒ tilt-invariant).
    final bloomOp = (lvl * 0.5 + 0.5 * spinFade).clamp(0.0, 1.0);
    if (bloomOp > 0.01) {
      canvas.drawCircle(
        Offset(_cx * s, cy * s),
        (11 + 4 * spinFade) * s,
        Paint()
          ..color = bitGlow.withValues(alpha: bloomOp)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (3.2 + 1.5 * spinFade) * s,
          ),
      );
    }

    // Plates — clamped to the body, or orbiting on the spin. No motion-blur
    // ghosts: the spin is now a slow, deliberate stretch, so the plates stay
    // crisp rather than smearing like a fast whip.
    for (final pl in plates) {
      orbitPlate(canvas, pl, s, radius, spinAngle, _cx, cy, pal, 1);
    }
    drawGrid(
      canvas,
      coreGrid,
      s,
      (_gx + 12).toDouble(),
      _gy + 12 + bob + vShift,
      pal,
    );
    if (off) {
      _drawOffScreen(canvas, s, (_gx + 15).toDouble(), _gy + 15 + bob + vShift, t);
    } else {
      _drawBootScreen(
        canvas,
        s,
        (_gx + 15).toDouble(),
        _gy + 15 + bob + vShift,
        lvl,
        bar,
        bar,
        settle,
        t,
      );
    }

    canvas.restore();
  }

  /// OFF/standby: a dim cyan ember slowly pulses at the centre of the dark
  /// screen — the "tap to power me on" sign.
  void _drawOffScreen(
    Canvas canvas,
    double s,
    double oxN,
    double oyN,
    double t,
  ) {
    final pulse = 0.3 + 0.3 * (0.5 + 0.5 * math.sin(t * 2.2));
    canvas.drawRect(
      Rect.fromLTWH((oxN + 4) * s, (oyN + 4) * s, 2 * s, 2 * s),
      Paint()
        ..color = bitGlow.withValues(alpha: pulse)
        ..isAntiAlias = false,
    );
  }

  /// Ground contact-glow + one-shot launch dust, painted flat on the floor
  /// (outside the sprite's tilt) so BIT reads as resting on — then lifting off —
  /// its own pooled light. [airborne] 0→1 releases the pool as BIT rises.
  void _drawGroundFx(
    Canvas canvas,
    double s,
    double t,
    double b,
    double airborne,
  ) {
    final groundY = _cy + _groundDrop + 17; // floor line under the resting core
    // Contact pool: faint + gently pulsing while dormant, brightening as it
    // stirs, then released as BIT lifts.
    final warm = b <= 0 ? 0.0 : (b / _kGatherEnd).clamp(0.0, 1.0);
    final pulse = b <= 0 ? 0.78 + 0.22 * math.sin(t * 2.2) : 1.0;
    final poolOp = (lerp(0.24, 0.38, warm) * pulse * (1 - airborne)).clamp(
      0.0,
      1.0,
    );
    if (poolOp > 0.01) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_cx * s, groundY * s),
          width: 26 * s,
          height: 8 * s,
        ),
        Paint()
          ..color = bitGlow.withValues(alpha: poolOp * 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2 * s),
      );
    }
    // Launch dust: a few pixels kicked sideways + down at the take-off point,
    // fading over the first part of the rise (secondary action).
    final dust = phaseProgress(b, _kGatherEnd, lerp(_kGatherEnd, kBitSpeakAt, 0.6));
    if (dust > 0 && dust < 1) {
      final op = (1 - dust) * 0.55;
      final dustPaint = Paint()
        ..color = bitGlow.withValues(alpha: op)
        ..isAntiAlias = false;
      for (var i = 0; i < 6; i++) {
        final dir = i.isEven ? 1 : -1;
        final spread = (i ~/ 2 + 1) * 3.0; // 3 pairs at widening offsets
        final dx = dir * spread * dust;
        final dy = dust * (2 + i ~/ 2); // drift down a touch
        canvas.drawRect(
          Rect.fromLTWH((_cx + dx) * s, (groundY - 1 + dy) * s, s, s),
          dustPaint,
        );
      }
    }
  }

  void _drawBootScreen(
    Canvas canvas,
    double s,
    double oxN,
    double oyN,
    double lvl,
    double boot,
    double brkIn,
    double settle,
    double t,
  ) {
    final a = lvl;
    if (a < 0.04) return;
    void px(double x, double y, double w, double h, Color col) {
      canvas.drawRect(
        Rect.fromLTWH((oxN + x) * s, (oyN + y) * s, w * s, h * s),
        Paint()
          ..color = col
          ..isAntiAlias = false,
      );
    }

    // Boot UI (glow wash, scanlines, corner brackets, loading bar, cursor) —
    // fades out as BIT settles into idle.
    final ui = 1 - settle;
    if (ui > 0.01) {
      px(0, 0, 10, 10, bitGlow.withValues(alpha: 0.16 * a * ui)); // glow wash
      for (var y = 0; y < 10; y += 2) {
        px(0, y.toDouble(), 10, 1, Color.fromRGBO(0, 0, 0, 0.22 * ui));
      }
      final bc = Color.fromRGBO(94, 232, 221, math.min(1.0, a) * brkIn * ui);
      px(0, 0, 2, 1, bc);
      px(0, 0, 1, 2, bc);
      px(8, 0, 2, 1, bc);
      px(9, 0, 1, 2, bc);
      px(0, 9, 2, 1, bc);
      px(0, 8, 1, 2, bc);
      px(8, 9, 2, 1, bc);
      px(9, 8, 1, 2, bc);
      px(1, 6, 8, 2, Color.fromRGBO(13, 63, 60, a * ui)); // loading bar bg
      final fw = (8 * boot).round();
      if (fw > 0) {
        px(1, 6, fw.toDouble(), 2, Color.fromRGBO(40, 206, 194, a * ui));
      }
      final cxp = 1 + math.min(7, math.max(0, fw - 1));
      px(cxp.toDouble(), 5, 1, 4, Color.fromRGBO(210, 255, 250, a * ui));
    }
    // Calm faceless idle glow — matches BitMoodCore's neutral screen (2×2 centred
    // turquoise, glow 0.7, same breathe) so the cut to the problem screen is
    // seamless.
    if (settle > 0.01) {
      final pulse = reduceMotion ? 0.0 : 0.5 + 0.5 * math.sin(t * 2.0);
      final dotA = (settle * (0.32 + 0.5 * 0.7) * (0.72 + 0.28 * pulse)).clamp(
        0.0,
        1.0,
      );
      px(4, 4, 2, 2, bitGlow.withValues(alpha: dotA));
    }
  }

  @override
  bool shouldRepaint(covariant _BitBootPainter old) =>
      old.reduceMotion != reduceMotion ||
      old.boot != boot ||
      old.freezeBob != freezeBob;
}

/// BIT's voice, made visible — a row of cyan bars that pulse while the boot
/// greeting types in (ported from `scene.jsx`'s `Waveform`). Reduced motion →
/// a static low row.
class BitVoiceWaveform extends StatefulWidget {
  const BitVoiceWaveform({
    super.key,
    this.width = 115,
    this.height = 34,
    this.intensity,
  });

  final double width;
  final double height;

  /// 0..1 speech loudness. When null, the bars use the legacy envelope (loud for
  /// the first ~1.6s after mount) the cold-open greeting relies on; when set, the
  /// bars track the caller's actual speech — loud while words reveal, calm in the
  /// pauses — so the "BIT is speaking" cue matches what BIT is saying.
  final double? intensity;

  @override
  State<BitVoiceWaveform> createState() => _BitVoiceWaveformState();
}

class _BitVoiceWaveformState extends State<BitVoiceWaveform>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(5.0);
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _ticker?.stop();
      _time.value = 5.0;
    } else {
      _ticker ??= createTicker((d) => _time.value = d.inMicroseconds / 1e6);
      if (!_ticker!.isActive) _ticker!.start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: _WaveformPainter(
          time: _time,
          reduceMotion: _reduce,
          intensity: widget.intensity,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.time,
    required this.reduceMotion,
    this.intensity,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final bool reduceMotion;
  final double? intensity;

  // HTML reference units: 15 bars, barW 5, gap 6 (totalW 159), maxH 46.
  static const int _n = 15;
  static const double _refW = 159, _refH = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final t = reduceMotion ? 0.0 : time.value;
    final sx = size.width / _refW;
    final sy = size.height / _refH;
    // Loudness: caller-driven speech intensity when provided, else the legacy
    // "loud for the first ~1.6s" envelope (the cold-open greeting type-in).
    final amp = reduceMotion
        ? 0.0
        : intensity != null
        ? (0.22 + 0.78 * intensity!.clamp(0.0, 1.0))
        : (t < 1.6 ? 1.0 : 0.22);
    final paint = Paint()..color = bitGlow;
    for (var i = 0; i < _n; i++) {
      final wob = reduceMotion
          ? 0.0
          : (math.sin(t * 9 + i * 0.8) * math.cos(t * 5.5 + i)).abs();
      final h = _refH * (0.14 + amp * (0.18 + 0.68 * wob));
      final x = i * (5 + 6) * sx;
      final rectH = h * sy;
      final y = (_refH * sy - rectH) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 5 * sx, rectH),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.reduceMotion != reduceMotion || old.intensity != intensity;
}
