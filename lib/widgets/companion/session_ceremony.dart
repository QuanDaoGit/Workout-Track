import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/haptic_service.dart';
import '../../services/sfx_service.dart';
import '../../theme/tokens.dart';
import 'bit_companion.dart';

/// The **Session Complete ceremony** — a faithful port of
/// `assets/design_handoff_session_ceremony/reference/Session Complete.html`.
///
/// A full-screen overlay that plays before the workout summary's stat reveal:
/// BIT (200px) sits dormant in the dark → inhales (anticipation coil) → bursts
/// into an amber cheer (flood + spark ring + shake + chime) → holds → flies a
/// 1.5s **banked flight** (pull-back → accelerate → 4% overshoot → settle, 72px
/// bow, ±6° bank, one full plate orbit) down into the 72px seat at the top of
/// the summary column, then hands off (`onSettled` → the app's staged reveal).
///
/// One clock drives every beat; each side effect is threshold-gated and
/// fired-once so **tap-to-skip is idempotent** (jump to the end state, mark all
/// effects fired, land the touchdown beat). All particles are 2px squares on a
/// half-resolution grid (`canvas.scale(2)`, integer coords, no anti-aliasing).
///
/// The parent must NOT build this under reduced motion (the handoff: no
/// ceremony at all — straight to seated + revealed); a guard here calls the
/// callbacks immediately if it is built anyway.
class SessionCeremony extends StatefulWidget {
  const SessionCeremony({
    super.key,
    required this.seatKey,
    required this.onSurge,
    required this.onSettled,
    required this.onFinished,
  });

  /// Key on the 72×72 seat box at the top of the summary column — the flight
  /// target. Measured lazily at liftoff (t=1050ms, layout long settled); if the
  /// measurement fails the ceremony skips cleanly to the seated end state
  /// rather than flying to a guessed coordinate.
  final GlobalKey seatKey;

  /// The surge release (t=500ms) — the parent fires its device shake here
  /// (±2px × 120ms). Haptic + chime are owned by the ceremony itself.
  final VoidCallback onSurge;

  /// Touchdown (t=2550ms, or skip): the seat becomes visible, its cheer flash
  /// fires, and the summary's staged reveal may begin. Fired exactly once.
  final VoidCallback onSettled;

  /// The overlay is fully inert (touchdown done, last particles drained) — the
  /// parent should remove it from the tree. Fired exactly once, after
  /// [onSettled].
  final VoidCallback onFinished;

  @override
  State<SessionCeremony> createState() => _SessionCeremonyState();
}

// ── easing (verbatim from the prototype) ─────────────────────────────────────
double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _easeInQuad(double v) => v * v;
double _easeOutCubic(double v) => 1 - math.pow(1 - v, 3).toDouble();
double _easeInOutCubic(double v) =>
    v < 0.5 ? 4 * v * v * v : 1 - math.pow(-2 * v + 2, 3).toDouble() / 2;

/// Flight progress: pull-back (−4%) → accelerate → 4% overshoot → settle.
double _flightProg(double p) {
  if (p < 0.14) return -0.04 * math.sin((p / 0.14) * math.pi * 0.5);
  if (p < 0.82) return -0.04 + 1.08 * _easeInOutCubic((p - 0.14) / 0.68);
  return 1.04 - 0.04 * _easeOutCubic((p - 0.82) / 0.18);
}

// ── ceremony-specific art colors (handoff spec; like the sprite palettes,
//    these are procedural scene art, not brand tokens) ────────────────────────
const Color _scrimInner = Color(0xFF0B1220);
const Color _scrimOuter = Color(0xFF07070F);
const List<Color> _amberSparks = [
  Color(0xFFFFD21F),
  Color(0xFFFFEC8C),
  Color(0xFFFFA500),
];
const List<Color> _dustColors = [
  Color(0xFF17D6CC),
  Color(0xFF3A5A78),
  Color(0xFF45437A),
];
const List<Color> _puffColors = [
  Color(0xFF45437A),
  Color(0xFF17D6CC),
  Color(0xFF6E6E92),
];
const Color _bracketColor = Color(0xFF17D6CC);

/// A transient FX particle in half-res units.
class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.color, this.size);
  double x, y;
  final double vx, vy;
  final double life;
  double age = 0;
  final Color color;
  final int size; // 1 or 2 units (2px or 4px on screen)
}

class _Dust {
  _Dust(this.x, this.y, this.v, this.tw, this.color);
  double x, y, tw;
  final double v;
  final Color color;
}

class _SessionCeremonyState extends State<SessionCeremony>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  /// The one ceremony clock, ms. Every layer repaints off this notifier.
  final ValueNotifier<double> _t = ValueNotifier<double>(0);

  /// Threshold-gated side effects that already fired (skip idempotency).
  final Set<String> _fired = {};

  // FX state (half-res units), mutated in the tick, painted by the painter.
  final List<_Spark> _sparks = [];
  final List<_Dust> _dust = [];
  final math.Random _rand = math.Random(0xB17);
  double _brkInset = 58; // bracket inset from BIT center, units
  double _brkAlpha = 0;
  double _dustAlpha = 0;

  Size? _size; // overlay size, captured at first layout
  bool _flightOn = false;
  Offset? _flightTarget; // seat center, overlay-local px
  Offset _flightPos = Offset.zero; // BIT center now, overlay-local px
  Matrix4 _flightXform = Matrix4.identity();
  bool _touchedDown = false;
  bool _finishedFired = false;
  double _touchdownAtMs = -1;

  static const double _bitPx = 200;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Belt-and-braces: the parent should never build the ceremony under
    // reduced motion; if it did, settle immediately (no motion, no sounds).
    if (MediaQuery.of(context).disableAnimations && !_touchedDown) {
      _fired.addAll(const [
        'tick', 'wake1_h', 'wake2_h', 'surge', 'liftoff',
        'land_sfx', 'land_h', 'puff',
      ]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _skipToEnd();
      });
    }
  }

  @override
  void dispose() {
    // Backing out mid-flight must not leave the motor running.
    HapticService.instance.stopBuzz();
    _ticker?.dispose();
    _t.dispose();
    super.dispose();
  }

  // ── clock ──────────────────────────────────────────────────────────────────
  void _onTick(Duration elapsed) {
    final dt = math.min(
      60.0,
      (elapsed - _lastTick).inMicroseconds / 1000.0,
    );
    _lastTick = elapsed;
    if (dt <= 0) return;
    _t.value += dt;
    _evaluate(_t.value);
    _stepFx(dt);
    // Fully inert: touchdown delivered and the last puff/trail spark drained.
    if (_touchedDown &&
        _sparks.isEmpty &&
        _t.value - _touchdownAtMs > 600 &&
        !_finishedFired) {
      _finishedFired = true;
      _ticker?.stop();
      widget.onFinished();
    }
  }

  void _once(String key, VoidCallback fn) {
    if (_fired.contains(key)) return;
    _fired.add(key);
    fn();
  }

  /// The beat evaluator — thresholds and windows verbatim from the prototype's
  /// `evaluate(t)`.
  void _evaluate(double t) {
    // Ambient dust alpha.
    _dustAlpha = t < 150
        ? (t / 150) * 0.55
        : t < 1050
        ? 0.55
        : t < 1900
        ? 0.55 * (1 - (t - 1050) / 850)
        : 0.0;
    // Arrival brackets blink in @90 (α→0.5 over 160ms); the burst zeroes them.
    if (t >= 90 && t < 500) {
      _brkAlpha = math.min(0.5, (t - 90) / 160 * 0.5);
    }
    // Brackets tighten with the inhale.
    if (t < 500) _brkInset = 58 - math.max(0.0, _anticAt(t)) * 5;

    if (t >= 150) _once('tick', SfxService.instance.playCeremonyTick);
    // The double "sign of life" blink, made tactile — two of the subtlest
    // ticks, exactly on the blink beats.
    if (t >= 380) _once('wake1_h', HapticService.instance.selection);
    if (t >= 455) _once('wake2_h', HapticService.instance.selection);
    if (t >= 500) {
      _once('surge', () {
        _burst();
        SfxService.instance.playCeremonyChime();
        // The device shake is "the haptic made visible" — mediumImpact.
        HapticService.instance.success();
        widget.onSurge();
      });
    }
    if (t >= 1050) {
      _once('liftoff', () {
        _flightTarget = _measureSeat();
        final size = _size;
        if (_flightTarget == null || size == null) {
          // Never fly to a guessed coordinate — settle cleanly instead.
          _skipToEnd();
        } else {
          _flightOn = true;
          _flightPos = _origin(size);
          // The flight's sound + touch: a thrust swoosh (fades to silence
          // before the landing hit) and the shaped haptic swell — both fire only
          // when the flight actually happens (never on the fallback settle).
          SfxService.instance.playCeremonyFlight();
          HapticService.instance.flightSwell();
        }
      });
    }
    // The flight transform is computed here (like the prototype's evaluate →
    // stepFX order) so the thrust trail spawns from THIS frame's position.
    if (_flightOn && !_touchedDown && _size != null) {
      _flightXform = _flightMatrix(_size!, _clamp01((t - 1050) / 1500));
    }
    if (t >= 2550) _once('swap', _touchdown);
  }

  /// Anticipation curve: inhale → overshoot release → settle (pure function).
  double _anticAt(double t) {
    if (t >= 150 && t < 500) return _easeInQuad((t - 150) / 350);
    if (t >= 500 && t < 640) {
      return 1 + (-0.35 - 1) * _easeOutCubic((t - 500) / 140);
    }
    if (t >= 640 && t < 820) return -0.35 * (1 - (t - 640) / 180);
    return 0;
  }

  double _idleAmpAt(double t) => t < 500 ? 0 : _clamp01((t - 500) / 400);

  /// The double "sign of life" blink @380/@455 (110ms each, so they chain).
  bool _blinkAt(double t) =>
      (t >= 380 && t < 490) || (t >= 455 && t < 565);

  double _scrimOpAt(double t) => t < 150
      ? (t / 150) * 0.96
      : t < 1050
      ? 0.96
      : t < 2550
      ? 0.96 * (1 - _easeOutCubic((t - 1050) / 1500))
      : 0.0;

  double _floodOpAt(double t) {
    if (t < 500) return 0;
    if (t < 560) return 0.34 * (t - 500) / 60;
    if (t < 1050) return 0.34 - 0.24 * (t - 560) / 490;
    if (t < 2550) return 0.10 * (1 - (t - 1050) / 1500);
    return 0;
  }

  // ── geometry ───────────────────────────────────────────────────────────────
  Offset _origin(Size size) => Offset(size.width / 2, size.height * 0.51);

  /// Seat center in this overlay's coordinate space, or null when it cannot be
  /// measured safely (Codex F2: unmounted, no size, detached — never guess).
  Offset? _measureSeat() {
    try {
      final seatCtx = widget.seatKey.currentContext;
      final selfObj = context.findRenderObject();
      if (seatCtx == null || selfObj is! RenderBox || !selfObj.hasSize) {
        return null;
      }
      final seatBox = seatCtx.findRenderObject();
      if (seatBox is! RenderBox || !seatBox.hasSize || !seatBox.attached) {
        return null;
      }
      final global = seatBox.localToGlobal(
        seatBox.size.center(Offset.zero),
      );
      return selfObj.globalToLocal(global);
    } catch (_) {
      return null;
    }
  }

  /// Flight transform at progress [p] (0..1 across the 1.5s window) — the
  /// prototype's `handoffTransform`, CSS `translate → rotate → scale` about the
  /// element center.
  Matrix4 _flightMatrix(Size size, double p) {
    final origin = _origin(size);
    final target = _flightTarget ?? origin;
    final e = _flightProg(p);
    final ec = _clamp01(e);
    final bow = -math.sin(ec * math.pi) * 72;
    final dx = (target.dx - origin.dx) * e + bow;
    final dy = (target.dy - origin.dy) * e;
    final bank = -math.sin(ec * math.pi) * 6 * math.pi / 180;
    final sc = 1 + (0.36 - 1) * e;
    _flightPos = origin + Offset(dx, dy);
    return Matrix4.translationValues(dx, dy, 0)
      ..rotateZ(bank)
      ..scaleByDouble(sc, sc, 1, 1);
  }

  // ── particles ──────────────────────────────────────────────────────────────
  void _initDust(Size size) {
    if (_dust.isNotEmpty) return;
    final uw = size.width / 2, uh = size.height / 2;
    for (var i = 0; i < 16; i++) {
      _dust.add(
        _Dust(
          _rand.nextDouble() * uw,
          _rand.nextDouble() * uh,
          0.004 + _rand.nextDouble() * 0.009,
          _rand.nextDouble() * 6.28,
          _dustColors[i % 3],
        ),
      );
    }
  }

  void _spark(
    double x,
    double y,
    double vx,
    double vy,
    double life,
    Color c, [
    int size = 1,
  ]) {
    _sparks.add(_Spark(x, y, vx, vy, life, c, size));
  }

  /// The surge burst: 12-spark amber ring + the 4 brackets flying outward.
  void _burst() {
    final size = _size;
    if (size == null) return;
    final cx = _origin(size).dx / 2, cy = _origin(size).dy / 2;
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * 6.283;
      final sp = 0.055 + _rand.nextDouble() * 0.05;
      _spark(
        cx,
        cy,
        math.cos(a) * sp,
        math.sin(a) * sp,
        360 + _rand.nextDouble() * 120,
        _amberSparks[i % 3],
      );
    }
    for (final d in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      _spark(
        cx + d.$1 * _brkInset,
        cy + d.$2 * _brkInset,
        d.$1 * 0.05,
        d.$2 * 0.05,
        300,
        const Color(0xFFFFD21F),
        2,
      );
    }
    _brkAlpha = 0;
  }

  void _puff(double x, double y) {
    for (var i = 0; i < 6; i++) {
      _spark(
        x + (_rand.nextDouble() * 10 - 5),
        y + 16,
        _rand.nextDouble() * 0.06 - 0.03,
        -0.005 - _rand.nextDouble() * 0.02,
        300 + _rand.nextDouble() * 120,
        _puffColors[i % 3],
      );
    }
  }

  void _stepFx(double dt) {
    final size = _size;
    if (size == null) return;
    final uw = size.width / 2, uh = size.height / 2;
    if (_dustAlpha > 0.01) {
      for (final d in _dust) {
        d.y -= d.v * dt;
        d.tw += dt * 0.004;
        if (d.y < -2) {
          d.y = uh + 2;
          d.x = _rand.nextDouble() * uw;
        }
      }
    }
    // Thrust trail while flying: ~45% chance per frame, mostly amber.
    if (_flightOn && !_touchedDown && _rand.nextDouble() < 0.45) {
      _spark(
        _flightPos.dx / 2 + (_rand.nextDouble() * 6 - 3),
        _flightPos.dy / 2 + 8 + _rand.nextDouble() * 4,
        0.015 + _rand.nextDouble() * 0.02,
        0.02 + _rand.nextDouble() * 0.02,
        240,
        _rand.nextDouble() < 0.75
            ? _amberSparks[_rand.nextInt(3)]
            : _dustColors[0],
      );
    }
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final p = _sparks[i];
      p.age += dt;
      if (p.age >= p.life) {
        _sparks.removeAt(i);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }

  // ── endings ────────────────────────────────────────────────────────────────
  /// Touchdown: hide the overlay BIT + scrim, puff + landing thud at the seat,
  /// hand off to the summary. Fired exactly once (threshold or skip).
  void _touchdown() {
    _touchedDown = true;
    _touchdownAtMs = _t.value;
    _flightOn = false;
    _dustAlpha = 0;
    _brkAlpha = 0;
    final seat = _flightTarget ?? _measureSeat();
    if (seat != null) {
      _once('puff', () => _puff(seat.dx / 2, seat.dy / 2));
    }
    _once('land_sfx', SfxService.instance.playCeremonyLand);
    // The touchdown, felt: one firm thump synced with the blip + puff. Any
    // still-running flight swell yields to it first.
    _once('land_h', () {
      HapticService.instance.stopBuzz();
      HapticService.instance.landThump();
    });
    widget.onSettled();
    if (mounted) setState(() {});
  }

  /// Tap-to-skip / measurement fallback: jump straight to the seated + fully
  /// revealed state. Idempotent — pending one-shots are marked fired (silently,
  /// like the prototype's `finishNow`), then the touchdown beat lands.
  void _skipToEnd() {
    if (_touchedDown) return;
    _fired.addAll(const ['tick', 'wake1_h', 'wake2_h', 'surge', 'liftoff']);
    // A live flight swell must not outlast the skipped flight.
    HapticService.instance.stopBuzz();
    _sparks.clear();
    // Jump the clock to the touchdown threshold; it keeps advancing after
    // (the post-touchdown windows are all zeros, and the drain timer needs it).
    _t.value = 2550;
    _once('swap', _touchdown);
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_size != null && _size != size && !_touchedDown) {
          // The stage resized mid-ceremony (rotation, window resize): the
          // measured flight would land wrong — settle cleanly instead.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _skipToEnd();
          });
        }
        _size = size;
        _initDust(size);
        final origin = _origin(size);
        return IgnorePointer(
          ignoring: _touchedDown,
          // haptic-ok: full-screen skip catcher, fires selection() in-handler
          child: GestureDetector(
            key: const ValueKey('ceremony_skip'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticService.instance.selection();
              _skipToEnd();
            },
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final t = _t.value;
                return Stack(
                  children: [
                    // Scrim + amber flood (z 8–9).
                    if (!_touchedDown)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CeremonyBackdropPainter(
                            scrimOp: _scrimOpAt(t),
                            floodOp: _floodOpAt(t),
                          ),
                        ),
                      ),
                    // Pixel FX — dust, brackets, sparks (z 10).
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CeremonyFxPainter(
                          sparks: _sparks,
                          dust: _dust,
                          dustAlpha: _dustAlpha,
                          brkAlpha: _brkAlpha,
                          brkInset: _brkInset,
                          center: Offset(origin.dx / 2, origin.dy / 2),
                        ),
                      ),
                    ),
                    // BIT (z 11), flight-transformed about its center.
                    if (!_touchedDown)
                      Positioned(
                        left: origin.dx - _bitPx / 2,
                        top: origin.dy - _bitPx / 2,
                        width: _bitPx,
                        height: _bitPx,
                        child: Transform(
                          transform: _flightOn
                              ? _flightXform
                              : Matrix4.identity(),
                          alignment: Alignment.center,
                          child: CustomPaint(
                            size: const Size(_bitPx, _bitPx),
                            painter: _CeremonyBitPainter(
                              tms: t,
                              surgedForMs: t - 500,
                              antic: _anticAt(t),
                              idleAmp: _idleAmpAt(t),
                              spinT: _flightOn
                                  ? _clamp01((t - 1050) / 1500)
                                  : 0,
                              blink: _blinkAt(t),
                            ),
                          ),
                        ),
                      ),
                    // Skip hint (z 12).
                    if (!_touchedDown)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 26,
                        child: Text(
                          'TAP TO SKIP',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 7,
                            letterSpacing: 0.5,
                            color: kDim,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Scrim (dark radial) + amber flood, alpha-scaled per beat.
class _CeremonyBackdropPainter extends CustomPainter {
  _CeremonyBackdropPainter({required this.scrimOp, required this.floodOp});

  final double scrimOp;
  final double floodOp;

  @override
  void paint(Canvas canvas, Size size) {
    // Clip first: the gradient rects are oversized (the ellipse scale trick).
    canvas.clipRect(Offset.zero & size);
    if (scrimOp > 0.004) {
      // radial-gradient(70% 46% at 50% 50%, #0B1220 0%, #07070F 68%)
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(1, (size.height * 0.46) / (size.width * 0.7));
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 4,
          height: size.width * 4,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [
              _scrimInner.withValues(alpha: scrimOp),
              _scrimOuter.withValues(alpha: scrimOp),
            ],
            stops: const [0.0, 0.68],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: size.width * 0.7),
          ),
      );
      canvas.restore();
    }
    if (floodOp > 0.004) {
      // radial-gradient(62% 46% at 50% 51%, amber .5 → amber-dark .12 → 0)
      final center = Offset(size.width / 2, size.height * 0.51);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, (size.height * 0.46) / (size.width * 0.62));
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 4,
          height: size.width * 4,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [
              kAmber.withValues(alpha: 0.5 * floodOp),
              const Color(0xFFFFA500).withValues(alpha: 0.12 * floodOp),
              const Color(0x00000000),
            ],
            stops: const [0.0, 0.42, 0.68],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: size.width * 0.62),
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CeremonyBackdropPainter old) =>
      old.scrimOp != scrimOp || old.floodOp != floodOp;
}

/// The half-res pixel FX layer: every particle is an integer-cell square drawn
/// through `canvas.scale(2)` — chunky 2px (or 4px) pixels, never anti-aliased.
class _CeremonyFxPainter extends CustomPainter {
  _CeremonyFxPainter({
    required this.sparks,
    required this.dust,
    required this.dustAlpha,
    required this.brkAlpha,
    required this.brkInset,
    required this.center,
  });

  final List<_Spark> sparks;
  final List<_Dust> dust;
  final double dustAlpha;
  final double brkAlpha;
  final double brkInset;

  /// BIT's ceremony center in half-res units.
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.scale(2, 2);
    final paint = Paint()..isAntiAlias = false;
    if (dustAlpha > 0.01) {
      for (final d in dust) {
        final a = (dustAlpha * (0.35 + 0.3 * math.sin(d.tw))).clamp(0.0, 1.0);
        paint.color = d.color.withValues(alpha: a);
        canvas.drawRect(
          Rect.fromLTWH(d.x.roundToDouble(), d.y.roundToDouble(), 1, 1),
          paint,
        );
      }
    }
    if (brkAlpha > 0.01) {
      paint.color = _bracketColor.withValues(alpha: brkAlpha);
      final n = brkInset.roundToDouble();
      const l = 9.0;
      for (final d in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
        final x = center.dx + d.$1 * n, y = center.dy + d.$2 * n;
        canvas.drawRect(
          Rect.fromLTWH(d.$1 < 0 ? x : x - l + 1, y, l, 1),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(x, d.$2 < 0 ? y : y - l + 1, 1, l),
          paint,
        );
      }
    }
    for (final p in sparks) {
      paint.color = p.color.withValues(
        alpha: (1 - p.age / p.life).clamp(0.0, 1.0),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          p.x.roundToDouble(),
          p.y.roundToDouble(),
          p.size.toDouble(),
          p.size.toDouble(),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CeremonyFxPainter old) => true;
}

/// The overlay BIT frame — all bit.js semantics live in [paintCeremonyBit].
class _CeremonyBitPainter extends CustomPainter {
  _CeremonyBitPainter({
    required this.tms,
    required this.surgedForMs,
    required this.antic,
    required this.idleAmp,
    required this.spinT,
    required this.blink,
  });

  final double tms;
  final double surgedForMs;
  final double antic;
  final double idleAmp;
  final double spinT;
  final bool blink;

  @override
  void paint(Canvas canvas, Size size) {
    paintCeremonyBit(
      canvas,
      size,
      tms: tms,
      surgedForMs: surgedForMs,
      antic: antic,
      idleAmp: idleAmp,
      spinT: spinT,
      blink: blink,
    );
  }

  @override
  bool shouldRepaint(covariant _CeremonyBitPainter old) =>
      old.tms != tms ||
      old.surgedForMs != surgedForMs ||
      old.antic != antic ||
      old.idleAmp != idleAmp ||
      old.spinT != spinT ||
      old.blink != blink;
}
