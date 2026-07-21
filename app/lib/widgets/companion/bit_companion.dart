import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/haptic_service.dart';
import '../../services/sfx_service.dart';
import '../../services/ui_sound.dart';
import 'bit_core_engine.dart';

/// BIT as the room's living companion — a fully-painted, animated port of the
/// prototype's `bit.js` (the companion engine, distinct from the faceless
/// `bit_boot.dart`). Core + four detached plates + a glowing screen-face that
/// carries the [mood]. Idle = hover-bob + plate-breathe + blink; **tap →** the
/// plates flare to cheer, run one full orbit (950ms) still flared, then clack
/// back to neutral in quick whole-pixel steps (~280ms, a stutter not a glide)
/// while breathing resumes. Zero image assets.
///
/// Reduced motion → a still, lit, legible pose (no bob/spin) — still tappable
/// with its Semantics label. BIT is the single brightest thing in the room
/// (handoff GUARDRAILS #2): the pad's cyan is deliberately held dimmer.
///
/// The metal/screen palettes and pixel grids come from `bit_core_engine.dart`
/// — the single source of BIT's drawing — canonical procedural sprite-art, not
/// brand tokens.
class BitCompanion extends StatefulWidget {
  const BitCompanion({
    super.key,
    this.mood = BitMood.neutral,
    this.size = 92,
    this.cheerTick = 0,
    this.flashTick = 0,
    this.spamRestArmed = true,
    this.onRestEasterEgg,
  });

  /// The resting mood. Tap flips to [BitMood.cheer] for the spin, then returns.
  final BitMood mood;
  final double size;

  /// Bump this (any new value) to fire BIT's tap-spin programmatically — the
  /// exact flare→orbit→stepped-stutter the user gets by tapping him, reused by
  /// the COLLECT cheer. A no-op under reduced motion (the collect routes on
  /// instantly there, so a flash would only flicker).
  final int cheerTick;

  /// Bump this to fire a one-shot cheer **flash only** — bit.js `cheer()`
  /// (`_cheer = 1`, no orbit): the screen washes white and decays over 650ms.
  /// The ceremony's touchdown beat (the orbit stays reserved for a press).
  /// A no-op under reduced motion, like [cheerTick].
  final int flashTick;

  /// Arms the spam-tap easter egg: five rapid taps (≤350ms apart) tire BIT out
  /// — he slumps to a smooth REST pose, sighs once, holds ~3s, then perks back.
  /// The caller arms it only where it's appropriate (home/idle), so the gag can
  /// never override a more important state (a waiting haul, an away status).
  final bool spamRestArmed;

  /// Fired when the spam-rest episode begins (`true`) and ends (`false`), so the
  /// host can swap BIT's voice bubble to the "I guess bro..." sigh and back.
  final ValueChanged<bool>? onRestEasterEgg;

  @override
  State<BitCompanion> createState() => _BitCompanionState();
}

class _BitCompanionState extends State<BitCompanion>
    with TickerProviderStateMixin {
  Ticker? _idle;
  final ValueNotifier<double> _time = ValueNotifier<double>(5.0);
  // Tap = two phases. _spin flares the plates and runs one full orbit with them
  // held flared; when it finishes, _retract clacks them back to neutral in
  // whole-pixel steps (a deliberate stutter, not a glide).
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..addStatusListener(_onSpinStatus);
  late final AnimationController _retract = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..addStatusListener(_onRetractStatus);
  // One-shot cheer FLASH (no orbit) — bit.js cheer(): value 0→1 over the 650ms
  // decay window; the painter reads flash intensity as (1 − value).
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _reduce = false;
  late BitMood _mood = widget.mood;

  // Spam-tap easter egg. Poke BIT five times fast (≤350ms apart) and he tires
  // of it: [_restMorph] eases him neutral→rest (0→1) — a smooth slump — he sighs
  // through the room bubble, holds ~3s, then reverses home. [_resting] gates all
  // further taps for the whole episode so poking a tired BIT does nothing.
  late final AnimationController _restMorph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340), // sink into rest (an exhale)
    reverseDuration: const Duration(milliseconds: 300), // perk back up
  )..addStatusListener(_onRestMorphStatus);
  bool _resting = false;
  int _spamTaps = 0;
  int _lastTapMs = 0;
  Timer? _restHoldTimer;

  static const int _spamThreshold = 5; // the 5th rapid tap triggers rest
  static const int _spamGapMs = 350; // presses ≤350ms apart count as spamming
  static const Duration _restHold = Duration(seconds: 3);

  void _onSpinStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _spin.reset();
      // Orbit done with plates still flared — drop the face to its resting mood
      // and stutter the plates home.
      setState(() => _mood = widget.mood);
      _retract.forward(from: 0);
    }
  }

  void _onRetractStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _retract.reset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _idle?.stop();
      _time.value = 5.0; // frozen idle frame
    } else {
      _idle ??= createTicker((d) => _time.value = d.inMicroseconds / 1e6);
      if (!_idle!.isActive) _idle!.start();
    }
  }

  @override
  void didUpdateWidget(BitCompanion old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood && !_spin.isAnimating && !_resting) {
      setState(() => _mood = widget.mood);
    }
    // External cheer trigger (COLLECT) — fire the same orbit. Reduced motion is
    // a deliberate no-op: collect routes instantly, a flash would only flicker.
    // Suppressed mid-rest so a stray cheer can't override the slump.
    if (widget.cheerTick != old.cheerTick && !_reduce && !_resting) {
      _fireCheer();
    }
    // Flash-only trigger (touchdown): the screen wash without the orbit.
    if (widget.flashTick != old.flashTick && !_reduce && !_resting) {
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _restHoldTimer?.cancel();
    _idle?.dispose();
    _spin.dispose();
    _retract.dispose();
    _flash.dispose();
    _restMorph.dispose();
    _time.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_resting) return; // poking a tired BIT does nothing until he recovers
    // BIT's press signature — a spoken "bi-di-bip?" beside a shaped haptic
    // PURR (the orbit's tactile twin — a creature response, not a UI click).
    // The purr carries its own in-flight guard, so tap-mashing never restarts
    // the motor mid-envelope. A resting BIT stays silent (guarded above).
    unawaited(HapticService.instance.bitPurr());
    SfxService.instance.playUi(UiSound.bitChirp);
    if (widget.spamRestArmed) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _spamTaps = (now - _lastTapMs <= _spamGapMs) ? _spamTaps + 1 : 1;
      _lastTapMs = now;
      if (_spamTaps >= _spamThreshold) {
        _spamTaps = 0;
        _enterRest();
        return;
      }
    }
    if (_reduce) {
      // No orbit when motion is off — a brief cheer flash only.
      setState(() => _mood = BitMood.cheer);
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted && !_resting) setState(() => _mood = widget.mood);
      });
      return;
    }
    _fireCheer();
  }

  /// The flare→orbit→stepped-stutter, shared by a user tap and the external
  /// [BitCompanion.cheerTick] (COLLECT). Caller guarantees motion is on.
  void _fireCheer() {
    _retract.reset(); // re-tap mid-retract restarts cleanly
    setState(() => _mood = BitMood.cheer);
    _spin.forward(from: 0);
  }

  /// Spam-tap easter egg — enter REST: cancel any cheer (he deflates), slump to
  /// rest (smoothly, or instantly under reduced motion), tell the host to show
  /// the "I guess bro..." sigh, and arm the 3s recovery.
  void _enterRest() {
    _restHoldTimer?.cancel();
    // Stop the orbit but KEEP _mood (cheer) as the morph's "from", so the slump
    // eases cheer→rest directly — no one-frame flash of neutral in between.
    _spin.reset();
    _retract.reset();
    setState(() => _resting = true);
    widget.onRestEasterEgg?.call(true);
    if (_reduce) {
      _restMorph.value = 1.0; // instant slump — still a legible rest pose
    } else {
      _restMorph.forward(from: 0);
    }
    _restHoldTimer = Timer(_restHold, _exitRest);
  }

  /// Recovery after the hold: flip the host bubble back to advice now, then perk
  /// BIT back to neutral (smoothly, or instantly under reduced motion). [_resting]
  /// clears when the reverse morph fully dismisses (see [_onRestMorphStatus]).
  void _exitRest() {
    if (!mounted) return;
    widget.onRestEasterEgg?.call(false);
    // Perk back up: set the morph's "from" to the resting mood so the reverse
    // eases rest→neutral (he recovers to neutral, never back through cheer).
    if (_reduce) {
      setState(() {
        _mood = widget.mood;
        _resting = false;
      });
      _restMorph.value = 0.0;
    } else {
      setState(() => _mood = widget.mood);
      _restMorph.reverse();
    }
  }

  void _onRestMorphStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _resting) {
      setState(() => _resting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'BIT, your companion',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _BitCompanionPainter(
              time: _time,
              spin: _spin,
              retract: _retract,
              flash: _flash,
              restMorph: _restMorph,
              mood: _mood,
              reduceMotion: _reduce,
            ),
          ),
        ),
      ),
    );
  }
}

// ── engine-sourced sprite data ───────────────────────────────────────────────
// The palette, grids, mood face tables, and easing all live in
// `bit_core_engine.dart` — the single BIT drawing mechanic. This file keeps
// only the companion's choreography. The companion positions plates by
// home-offset + spread direction (bit.js's model); the offsets below are the
// engine's docked seats ([plateRadius] from the core centre (20,20)) expressed
// in that model.
class _Plate {
  _Plate(this.grid, this.nvx, this.nvy, this.dirX, this.dirY)
    : hw = grid[0].length / 2,
      hh = grid.length / 2;
  final List<List<String>> grid;
  final double hw, hh;
  final double nvx, nvy; // home offset from core centre
  final double dirX, dirY; // spread direction
}

final List<_Plate> _platesC = [
  _Plate(plates[0].grid, 0, -plateRadius, 0, -1), // top
  _Plate(plates[1].grid, 0, plateRadius, 0, 1), // bottom
  _Plate(plates[2].grid, -plateRadius, 0, -1, 0), // left
  _Plate(plates[3].grid, plateRadius, 0, 1, 0), // right
];

double _noise(double t) {
  final s = math.sin(t * 12.9898) * 43758.5453;
  return s - s.floorToDouble();
}

/// Deterministic 0..1 hash noise, exported so the hologram can decide
/// glitch/jitter frames as a pure function of time (never `Random` in paint).
double bitNoise(double t) => _noise(t);

/// Paint a metal grid (core / a plate) at native scale [s], origin in native
/// cells. Top-level so both the companion painter and the hologram render the
/// **identical** BIT sprite. `sil` paints a flat silhouette.
void drawBitGrid(
  Canvas canvas,
  List<List<String>> grid,
  double s,
  double oxN,
  double oyN, {
  bool sil = false,
}) {
  final paint = Paint()..isAntiAlias = false;
  for (var y = 0; y < grid.length; y++) {
    final row = grid[y];
    for (var x = 0; x < row.length; x++) {
      final col = sil ? const Color(0xFF08080E) : metal[row[x]];
      if (col == null) continue;
      paint.color = col;
      canvas.drawRect(Rect.fromLTWH((oxN + x) * s, (oyN + y) * s, s, s), paint);
    }
  }
}

/// Paint BIT's 10×10 glowing screen-face at native scale [s].
///
/// [alpha] dims the whole screen (ramp + scanlines + face) — bit.js's
/// `drawScreen` `ctx.globalAlpha`, used by the ceremony's anticipation inhale.
/// The default 1.0 skips the layer entirely (the shipped paths are untouched).
void drawBitScreen(
  Canvas canvas,
  double s,
  double oxN,
  double oyN,
  List<Color> ramp,
  BitMood mood,
  bool blink,
  double cheer, {
  double alpha = 1.0,
}) {
  final dimmed = alpha < 1.0;
  if (dimmed) {
    canvas.saveLayer(
      Rect.fromLTWH(oxN * s, oyN * s, 10 * s, 10 * s),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
    );
  }
  final paint = Paint()..isAntiAlias = false;
  void px(double x, double y, double w, double h, Color c) {
    paint.color = c;
    canvas.drawRect(
      Rect.fromLTWH((oxN + x) * s, (oyN + y) * s, w * s, h * s),
      paint,
    );
  }

  for (var y = 0; y < 10; y++) {
    for (var x = 0; x < 10; x++) {
      final dx = x - 4.5, dy = y - 4.5;
      final d = math.sqrt(dx * dx + dy * dy);
      final idx = d < 1.5 ? 3 : (d < 2.9 ? 2 : (d < 4.2 ? 1 : 0));
      px(x.toDouble(), y.toDouble(), 1, 1, ramp[idx]);
    }
  }
  for (var y = 0; y < 10; y += 2) {
    px(0, y.toDouble(), 10, 1, const Color.fromRGBO(2, 8, 12, 0.18));
  }
  final eyeCol = bitMoodEyeColor[mood]!;
  for (final e in (blink ? bitMoodBlinkEyes[mood]! : bitMoodEyes[mood]!)) {
    px(e[0].toDouble(), e[1].toDouble(), 1, 1, eyeCol);
  }
  for (final m in bitMoodMouth[mood]!) {
    px(m[0].toDouble(), m[1].toDouble(), 1, 1, eyeCol);
  }
  if (cheer > 0.01) {
    px(0, 0, 10, 10, Color.fromRGBO(242, 255, 255, math.min(0.55, cheer * 0.65)));
  }
  if (dimmed) canvas.restore();
}

/// JS `Math.round` (ties toward +∞) — bit.js rounds `sink`/`bob`/`breathe`
/// this way, and Dart's `.round()` (ties away from zero) diverges on negative
/// half-values (the anticipation pop makes `sink` negative).
double _jsRound(double x) => (x + 0.5).floorToDouble();

/// Paint one **ceremony** frame of BIT — the Session-Complete overlay's 200px
/// instance. A faithful transcription of bit.js `renderInst` for the ceremony's
/// instance state (`mood:'REST'` at mount, `setMood('CHEER')` at the surge),
/// driven entirely by the caller's clock so every frame is deterministic:
///
/// - [tms] — ceremony clock in ms (drives bob/breathe/glow shimmer).
/// - [surgedForMs] — ms since the surge (`setMood('CHEER')` at t=500); negative
///   before it. Derives the 200ms mood-ramp lerp, the face switch at ramp 0.5,
///   the cheer flash (1 → 0 over 650ms), the plate-spread follow (REST −1 →
///   CHEER 4, the continuous form of bit.js's `s += (T−s)·dt/120` Euler step),
///   and the REST droop.
/// - [antic] — `setAnticipation` value; may be **negative** (the overshoot pop:
///   BIT rises + plates spread; the glow/screen dims gate on `max(0, antic)`).
/// - [idleAmp] — `setIdleAmp` 0..1 (0 while dormant, ramped in after the surge).
/// - [spinT] — `spin(1500)` progress 0..1; eased `easeInOutCubic → 2π` here,
///   exactly like bit.js (plates land home at 1).
/// - [blink] — forced blink (the double "sign of life" @380/@455).
///
/// Ground glow (bit.js's blurred gradient div) is painted as a radial-gradient
/// ellipse at the same box (64%×16%, bottom 4%). Scanlines always on ('face'
/// screen). The caller owns the flight transform (translate/rotate/scale).
void paintCeremonyBit(
  Canvas canvas,
  Size size, {
  required double tms,
  required double surgedForMs,
  required double antic,
  required double idleAmp,
  required double spinT,
  required bool blink,
}) {
  final s = size.width / 44.0;
  final surged = surgedForMs >= 0;

  // Instance state (bit.js updateInst), as pure functions of the clock.
  final mt = surged ? (surgedForMs / 200).clamp(0.0, 1.0) : 0.0;
  final cheer = surged ? (1 - surgedForMs / 650).clamp(0.0, 1.0) : 0.0;
  final spread = surged ? 4 - 5 * math.exp(-surgedForMs / 120) : -1.0;
  final droop = surged ? 0.0 : 2.0; // _target === 'REST' ? 2 : 0
  final faceMood = mt >= 0.5 ? BitMood.cheer : BitMood.rest; // _mt >= 0.5

  final restR = bitMoodRamps[BitMood.rest]!, cheerR = bitMoodRamps[BitMood.cheer]!;
  final ramp = [
    for (var i = 0; i < 4; i++) Color.lerp(restR[i], cheerR[i], mt)!,
  ];
  final glowCol = Color.lerp(bitMoodGlow[BitMood.rest], bitMoodGlow[BitMood.cheer], mt)!;

  // renderInst geometry.
  final sink = _jsRound(antic * 3);
  final bob = _jsRound(math.sin(tms / 780) * idleAmp);
  final breathe = _jsRound(math.sin(tms / 610 + 1.3) * idleAmp);
  final anticDim = math.max(0.0, antic);

  // Ground glow — bit.js's div: width 64%, height 16%, bottom 4% of the host,
  // radial gradient glowCol → transparent at 70%, slight blur.
  final glowBase = surged ? 0.5 : 0.32; // REST base 0.32
  final glowOp = ((glowBase + 0.16 * math.sin(tms / 780)) * (1 - anticDim * 0.75))
      .clamp(0.0, 1.0);
  if (glowOp > 0.01) {
    final host = size.width;
    final gw = host * 0.64, gh = host * 0.16;
    final gc = Offset(host / 2, host * 0.96 - gh / 2);
    canvas.save();
    canvas.translate(gc.dx, gc.dy);
    canvas.scale(1, gh / gw);
    canvas.drawCircle(
      Offset.zero,
      gw / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [glowCol.withValues(alpha: glowOp), const Color(0x00000000)],
          stops: const [0.0, 0.7],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: gw / 2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    canvas.restore();
  }

  final spreadF = spread + breathe + cheer * 3 - antic * 3;
  final shake = cheer > 0.02 ? (_noise(tms / 20) - 0.5) * 2.4 * cheer : 0.0;
  final theta = spinT > 0 ? easeInOutCubic(spinT.clamp(0.0, 1.0)) * 2 * math.pi : 0.0;
  final cos = math.cos(theta), sin = math.sin(theta);
  const gx = 2.0, gy = 2.0;
  const ocx = gx + 20.0; // GX + CORE_CX
  final ocy = gy + 20.0 + bob + sink; // GY + CORE_CY + bob + sink

  for (final p in _platesC) {
    final ex = p.nvx + p.dirX * spreadF;
    final ey = p.nvy + p.dirY * spreadF;
    final rvx = ex * cos - ey * sin;
    final rvy = ex * sin + ey * cos;
    // bit.js drawGrid rounds its origin (JS Math.round) — chunky cell motion.
    drawBitGrid(
      canvas,
      p.grid,
      s,
      _jsRound(ocx + rvx - p.hw + shake),
      _jsRound(ocy + rvy - p.hh + droop),
    );
  }
  drawBitGrid(canvas, coreGrid, s, gx + 12, gy + 12 + bob + sink);
  // Screen: sa = appear² · (1 − max(0,antic)·0.55); appear is 1 here.
  drawBitScreen(
    canvas,
    s,
    gx + 15,
    gy + 15 + bob + sink,
    ramp,
    faceMood,
    blink,
    cheer,
    alpha: 1 - anticDim * 0.55,
  );
}

/// Paint BIT's **idle** sprite (no glow, no spin) at the given [opacity] — the
/// shared entry point the hologram post-processes. [tms] is time in ms (drives
/// bob/breathe/blink); pass `reduceMotion: true` to freeze a still pose. Plates
/// sit at the mood's resting spread; the core + screen carry [mood].
void paintBitSprite(
  Canvas canvas,
  double s, {
  required double tms,
  BitMood mood = BitMood.neutral,
  double opacity = 1.0,
  bool reduceMotion = false,
}) {
  final bob = reduceMotion ? 0.0 : 1.5 * math.sin(tms / 390);
  final breathe = reduceMotion ? 0 : math.sin(tms / 610 + 1.3).round();
  final blink = !reduceMotion && ((tms / 1000) % 3.4) < 0.11;
  final spreadF = (bitMoodSpread[mood] ?? 0).toDouble() + breathe;
  final droop = mood == BitMood.rest ? 2.0 : 0.0;
  const gx = 2, gy = 2, coreCx = 20.0, coreCy = 20.0;
  final ocx = gx + coreCx, ocy = gy + coreCy + bob;

  canvas.saveLayer(
    Rect.fromLTWH(0, 0, 44 * s, 44 * s),
    Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
  );
  for (final p in _platesC) {
    final ex = p.nvx + p.dirX * spreadF;
    final ey = p.nvy + p.dirY * spreadF;
    drawBitGrid(canvas, p.grid, s, ocx + ex - p.hw, ocy + ey - p.hh + droop);
  }
  drawBitGrid(canvas, coreGrid, s, (gx + 12).toDouble(), gy + 12 + bob);
  drawBitScreen(
    canvas,
    s,
    (gx + 15).toDouble(),
    gy + 15 + bob,
    bitMoodRamps[mood]!,
    mood,
    blink,
    0,
  );
  canvas.restore();
}

class _BitCompanionPainter extends CustomPainter {
  _BitCompanionPainter({
    required this.time,
    required this.spin,
    required this.retract,
    required this.flash,
    required this.restMorph,
    required this.mood,
    required this.reduceMotion,
  }) : super(repaint: Listenable.merge([time, spin, retract, flash, restMorph]));

  final ValueListenable<double> time;

  /// 0→1 over the tap orbit; plates stay flared the whole way.
  final Animation<double> spin;

  /// 0→1 right after the orbit; recedes the flared plates home in pixel steps.
  final Animation<double> retract;

  /// 0→1 over the flash-only cheer decay (bit.js `cheer()`); intensity is
  /// `1 − value` while running, 0 when dismissed — the default state changes
  /// nothing in the shipped paint.
  final Animation<double> flash;

  /// 0→1 neutral→rest for the spam-tap easter egg — a smooth slump. 0 leaves the
  /// base [mood] untouched (so the cheer orbit renders exactly as before).
  final Animation<double> restMorph;
  final BitMood mood;
  final bool reduceMotion;

  static const int _gx = 2, _gy = 2;
  static const double _coreCx = 20, _coreCy = 20;

  /// Plate flare (native px) held through the orbit, then stepped back to 0.
  static const double _flareSpread = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44.0;
    final t = reduceMotion ? 5.0 : time.value;
    final tms = t * 1000;
    final spinT = reduceMotion ? 0.0 : spin.value;
    final retractT = reduceMotion ? 0.0 : retract.value;
    final spinning = spinT > 0;
    // Status, not value>0: the retract's first frame is value 0 (still fully
    // flared), and it must count as retracting or the plates flick to neutral
    // for one frame before stepping home.
    final retracting =
        !reduceMotion && retract.status == AnimationStatus.forward;

    final bob = reduceMotion ? 0.0 : 1.5 * math.sin(tms / 390);
    final breathe = reduceMotion ? 0 : math.sin(tms / 610 + 1.3).round();

    final spinCheer = spinning
        ? (1 - spinT * 950 / 650).clamp(0.0, 1.0)
        : 0.0;
    // Flash-only cheer (touchdown): full wash at fire, decaying over 650ms.
    // Dismissed (the shipped default) contributes 0.
    final flashCheer =
        (!reduceMotion && flash.status == AnimationStatus.forward)
        ? (1 - flash.value).clamp(0.0, 1.0)
        : 0.0;
    final cheer = math.max(spinCheer, flashCheer);
    final blink = !reduceMotion && (t % 3.4) < 0.11;
    final theta = easeInOutCubic(spinT) * 2 * math.pi;
    final cos = math.cos(theta), sin = math.sin(theta);

    // Spam-tap easter egg: a smooth slump toward REST (eased). We lerp from the
    // CURRENT [mood] (cheer at entry / neutral on the way back) → rest, so the
    // transition never flashes through a stray frame of neutral; the discrete
    // eyes/mouth switch at the midpoint. Keyed off the controller STATUS (not
    // value>0) so the first forward frame — value 0 — still renders the from-mood,
    // not the resting base. Dismissed ⇒ no episode ⇒ the base mood verbatim (the
    // cheer orbit is unaffected).
    final morph = Curves.easeInOut.transform(restMorph.value.clamp(0.0, 1.0));
    final inRest = restMorph.status != AnimationStatus.dismissed;
    final List<Color> ramp;
    final Color glowCol;
    final BitMood faceMood;
    final double restSpread;
    final double droop;
    if (inRest) {
      final fromR = bitMoodRamps[mood]!, restR = bitMoodRamps[BitMood.rest]!;
      ramp = [
        for (var i = 0; i < 4; i++) Color.lerp(fromR[i], restR[i], morph)!,
      ];
      glowCol = Color.lerp(bitMoodGlow[mood], bitMoodGlow[BitMood.rest], morph)!;
      faceMood = morph >= 0.5 ? BitMood.rest : mood;
      final fromSpread = (bitMoodSpread[mood] ?? 0).toDouble();
      final toSpread = (bitMoodSpread[BitMood.rest] ?? -1).toDouble();
      restSpread = fromSpread + (toSpread - fromSpread) * morph;
      droop = 2.0 * morph; // BIT slumps
    } else {
      ramp = bitMoodRamps[mood]!;
      glowCol = bitMoodGlow[mood]!;
      faceMood = mood;
      restSpread = (bitMoodSpread[mood] ?? 0).toDouble();
      droop = mood == BitMood.rest ? 2.0 : 0.0;
    }

    // Plate flare: snap out and hold through the orbit, then recede home in
    // WHOLE-PIXEL steps (ceil) so it clacks back — a pixel stutter, not a glide.
    final double flare;
    if (spinning) {
      flare = _flareSpread;
    } else if (retracting) {
      flare = (_flareSpread * (1 - retractT)).ceilToDouble();
    } else {
      flare = restSpread;
    }
    final spreadF = flare + breathe;
    final shake = (cheer > 0.02 && !reduceMotion)
        ? (_noise(t * 50) - 0.5) * 2.4 * cheer
        : 0.0;

    final ocx = _gx + _coreCx; // 22
    final ocy = _gy + _coreCy + bob; // 22 + bob

    // Rim glow — BIT's own cyan halo (the drop-shadow in the web build).
    canvas.drawCircle(
      Offset(ocx * s, ocy * s),
      13 * s,
      Paint()
        ..color = glowCol.withValues(alpha: 0.16 + 0.40 * cheer)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 * s),
    );

    // Plates orbit the core (positional only — bit.js does not spin each plate).
    for (final p in _platesC) {
      final ex = p.nvx + p.dirX * spreadF;
      final ey = p.nvy + p.dirY * spreadF;
      final rvx = ex * cos - ey * sin;
      final rvy = ex * sin + ey * cos;
      drawBitGrid(
        canvas,
        p.grid,
        s,
        ocx + rvx - p.hw + shake,
        ocy + rvy - p.hh + droop,
      );
    }
    drawBitGrid(canvas, coreGrid, s, (_gx + 12).toDouble(), _gy + 12 + bob);
    drawBitScreen(
      canvas,
      s,
      (_gx + 15).toDouble(),
      _gy + 15 + bob,
      ramp,
      faceMood,
      blink,
      cheer,
    );
  }

  @override
  bool shouldRepaint(covariant _BitCompanionPainter old) =>
      old.reduceMotion != reduceMotion || old.mood != mood;
}
