import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Faithful port of the **Guild Hall** animated backdrop
/// (`assets/guild/design_handoff_guild_hall/Guild Hall.dc.html` — the canvas
/// engine is the authority; `README.md` is prose). A static stone-hall pixel
/// scene (`guild_hall_base540.png`) over which the two torch flames warp +
/// flicker (the extracted `flame_diff540.png` displaced row-by-row), teal
/// indicator lights breathe/stutter, and embers + dust drift — all composited
/// **additively** at the handoff's ~14fps cadence (70ms tick).
///
/// Reduced motion (`disableAnimations || accessibleNavigation`, the app's union
/// gate — a faithful superset of the handoff's `prefers-reduced-motion`) renders
/// the handoff's own computed static frame: un-warped flames at brightness 0.96,
/// indicator lights at p=0.6, no embers, no dust. The ticker is not started.
///
/// Design space is 540×324; everything paints in those coordinates and the
/// canvas is uniformly scaled to the container (nearest-neighbour), matching the
/// source's `image-rendering: pixelated` upscale. This is the room backdrop
/// ONLY — the crest/UI are layered in front by callers (the centre bay is left
/// intentionally empty).
class GuildHallBackdrop extends StatefulWidget {
  const GuildHallBackdrop({
    super.key,
    this.animate = true,
    this.flicker = true,
    this.embers = true,
    this.glow = 1.0,
    this.lights = true,
    this.dust = true,
  });

  /// Whether the ambient loop runs. False freezes a clean static frame — used to
  /// pause the hall while its tab is off-screen (the handoff's "stop the loop
  /// off-viewport" note). Reduced motion freezes it regardless.
  final bool animate;

  /// Torch flame warp + brightness flicker (also gates embers). Handoff default on.
  final bool flicker;

  /// Rising ember particles. Handoff default on.
  final bool embers;

  /// Torch glow strength multiplier (handoff range 0–1.6, default 1).
  final double glow;

  /// Teal indicator lights. Handoff default on.
  final bool lights;

  /// Drifting dust motes. Handoff default on.
  final bool dust;

  @override
  State<GuildHallBackdrop> createState() => _GuildHallBackdropState();
}

// Design-space dimensions (the canvas internal resolution).
const double _kW = 540;
const double _kH = 324;

/// Torch table (540×324 coords) — `componentDidMount this.flames`.
class _Flame {
  const _Flame(this.sx, this.sy, this.w, this.h, this.cx, this.phase);
  final double sx, sy, w, h, cx, phase;
}

const List<_Flame> _flames = [
  _Flame(60, 64, 30, 44, 76, 0.0),
  _Flame(450, 64, 30, 44, 466, 3.1),
];

/// Teal indicator-light table — `componentDidMount this.lights`. `fl` marks a
/// flicker light (electronic stutter); the rest breathe on a smooth sine.
class _Light {
  const _Light({
    required this.x,
    required this.y,
    required this.r,
    required this.ph,
    this.sp = 0,
    required this.base,
    required this.amp,
    this.fl = false,
  });
  final double x, y, r, ph, sp, base, amp;
  final bool fl;
}

const List<_Light> _lights = [
  _Light(x: 15, y: 220, r: 8, ph: 0.0, sp: 0.10, base: 0.14, amp: 0.22),
  _Light(x: 524, y: 220, r: 8, ph: 1.7, sp: 0.11, base: 0.14, amp: 0.22),
  _Light(x: 137, y: 37, r: 6, ph: 2.4, base: 0.05, amp: 0.32, fl: true),
  _Light(x: 403, y: 37, r: 6, ph: 0.8, base: 0.05, amp: 0.32, fl: true),
  _Light(x: 36, y: 201, r: 5, ph: 3.1, base: 0.05, amp: 0.28, fl: true),
  _Light(x: 157, y: 201, r: 5, ph: 1.1, sp: 0.14, base: 0.08, amp: 0.14),
  _Light(x: 384, y: 201, r: 5, ph: 2.0, base: 0.05, amp: 0.28, fl: true),
  _Light(x: 504, y: 201, r: 5, ph: 0.4, sp: 0.13, base: 0.08, amp: 0.14),
];

class _Ember {
  double x = 0, y = 0, vx = 0, vy = 0, life = 0, max = 1, top = 0;
}

class _Mote {
  double x = 0, y = 0, vx = 0, vy = 0, life = 0, max = 1, a = 0;
}

/// JS `Math.round` rounds .5 toward +∞; Dart `double.round()` rounds .5 away
/// from zero — they diverge for negative ties. The flame row offset can be
/// negative, so reproduce JS rounding exactly (a recurring port-handoff gotcha).
int _jsRound(double v) => (v + 0.5).floor();

class _GuildHallBackdropState extends State<GuildHallBackdrop> {
  ui.Image? _base;
  ui.Image? _flame;
  Ticker? _ticker;
  final math.Random _rng = math.Random();
  final List<_Ember> _embers = [];
  final List<_Mote> _dust = [];
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  Duration _lastStep = Duration.zero;
  bool _reduced = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final base = await _decode('assets/guild/guild_hall_base540.png');
    final flame = await _decode('assets/guild/flame_diff540.png');
    if (!mounted) return;
    _initEmbers();
    _initDust();
    setState(() {
      _base = base;
      _flame = flame;
      _loaded = true;
    });
    _maybeStart();
  }

  Future<ui.Image> _decode(String key) async {
    final data = await rootBundle.load(key);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.maybeOf(context);
    final reduced =
        mq != null && (mq.disableAnimations || mq.accessibleNavigation);
    if (reduced != _reduced) {
      _reduced = reduced;
      _maybeStart();
      if (mounted && _loaded) setState(() {}); // rebuild painter with new `moving`
    } else {
      _maybeStart();
    }
  }

  bool get _animating => _loaded && !_reduced && widget.animate;

  void _maybeStart() {
    if (!_animating) {
      _ticker?.stop();
      return; // static frame; painter reads t=0 / moving=false
    }
    _ticker ??= Ticker(_onTick);
    if (!_ticker!.isActive) {
      _lastStep = Duration.zero;
      _ticker!.start();
    }
  }

  @override
  void didUpdateWidget(GuildHallBackdrop old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) {
      _maybeStart();
      if (mounted && _loaded) setState(() {}); // repaint with new `moving`
    }
  }

  // Throttle to ~14fps: advance one tick + step particles only when ≥70ms have
  // passed (`if (ts-last<70) return; last=ts;` — note `last=now`, not `+=70`,
  // so it skips under load rather than catching up).
  void _onTick(Duration elapsed) {
    if ((elapsed - _lastStep).inMilliseconds < 70) return;
    _lastStep = elapsed;
    _tick.value++; // notifies the painter (super.repaint)
    if (widget.flicker) _updateEmbers();
    if (widget.dust) _updateDust();
  }

  // ---- embers (8) ----------------------------------------------------------
  void _initEmbers() {
    _embers.clear();
    for (var i = 0; i < 8; i++) {
      final e = _Ember();
      _spawnEmber(e);
      _embers.add(e);
    }
  }

  void _spawnEmber(_Ember e) {
    final f = _flames[_rng.nextInt(_flames.length)];
    e.x = f.cx + (_rng.nextDouble() * 6 - 3);
    e.y = f.sy + 10 + _rng.nextDouble() * 12;
    e.vx = _rng.nextDouble() * 0.6 - 0.3;
    e.vy = -(0.25 + _rng.nextDouble() * 0.4);
    e.life = 0;
    e.max = 18 + _rng.nextDouble() * 22;
    e.top = f.sy;
  }

  void _updateEmbers() {
    for (final e in _embers) {
      e.x += e.vx;
      e.y += e.vy;
      e.life++;
      e.vx += _rng.nextDouble() * 0.16 - 0.08;
      if (e.life > e.max || e.y < e.top - 18) _spawnEmber(e);
    }
  }

  // ---- dust (16) -----------------------------------------------------------
  void _initDust() {
    _dust.clear();
    for (var i = 0; i < 16; i++) {
      final m = _Mote();
      _spawnDust(m);
      m.life = _rng.nextDouble() * m.max; // seed so they don't fade in unison
      _dust.add(m);
    }
  }

  void _spawnDust(_Mote m) {
    final f = _flames[_rng.nextInt(_flames.length)];
    m.x = f.cx + (_rng.nextDouble() * 80 - 40);
    m.y = 56 + _rng.nextDouble() * 78;
    m.vx = _rng.nextDouble() * 0.3 - 0.15;
    m.vy = -(0.04 + _rng.nextDouble() * 0.12);
    m.life = 0;
    m.max = 130 + _rng.nextDouble() * 130;
    m.a = 0.10 + _rng.nextDouble() * 0.16;
  }

  void _updateDust() {
    for (final m in _dust) {
      m.x += m.vx;
      m.y += m.vy;
      m.life++;
      m.vx += _rng.nextDouble() * 0.05 - 0.025;
      if (m.life > m.max || m.y < 28) _spawnDust(m);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: _kW / _kH,
        child: (!_loaded)
            ? const ColoredBox(color: Color(0xFF0D0F17)) // canvas bg while loading
            : CustomPaint(
                size: Size.infinite,
                painter: _HallPainter(
                  base: _base!,
                  flame: _flame!,
                  embers: _embers,
                  dust: _dust,
                  tick: _tick,
                  moving: !_reduced && widget.animate,
                  flicker: widget.flicker,
                  drawEmbers: widget.embers,
                  glow: widget.glow,
                  lights: widget.lights,
                  drawDust: widget.dust,
                ),
              ),
      ),
    );
  }
}

class _HallPainter extends CustomPainter {
  _HallPainter({
    required this.base,
    required this.flame,
    required this.embers,
    required this.dust,
    required this.tick,
    required this.moving,
    required this.flicker,
    required this.drawEmbers,
    required this.glow,
    required this.lights,
    required this.drawDust,
  }) : super(repaint: tick);

  final ui.Image base;
  final ui.Image flame;
  final List<_Ember> embers;
  final List<_Mote> dust;
  final ValueListenable<int> tick;
  final bool moving;
  final bool flicker;
  final bool drawEmbers;
  final double glow;
  final bool lights;
  final bool drawDust;

  // Additive radial light — `rGlow(cx,cy,R,rgb,alpha)`. Gradient stops 0 / 0.5 / 1
  // (the SOURCE uses 0.5; the README prose says 0.45 — source is authority).
  void _rGlow(Canvas canvas, double cx, double cy, double r, int red, int green,
      int blue, double alpha) {
    if (r <= 0 || alpha <= 0) return;
    final c = Color.fromRGBO(red, green, blue, 1);
    final shader = ui.Gradient.radial(Offset(cx, cy), r, [
      c.withValues(alpha: alpha.clamp(0.0, 1.0)),
      c.withValues(alpha: (alpha * 0.45).clamp(0.0, 1.0)),
      c.withValues(alpha: 0.0),
    ], [
      0.0,
      0.5,
      1.0,
    ]);
    canvas.drawRect(
      Rect.fromLTWH(cx - r, cy - r, r * 2, r * 2),
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  double _hash(double a, double b) {
    final s = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
    return s - s.floorToDouble();
  }

  double _techFlicker(double t, _Light l) {
    var v = 0.74 + 0.26 * math.sin(t * 0.09 + l.ph);
    final g = _hash((t / 4).floorToDouble() + l.ph * 7, l.ph * 3.3 + 1);
    if (g > 0.9) {
      v *= 0.18;
    } else if (g > 0.82) {
      v *= 0.55;
    }
    v *= 0.9 + 0.1 * math.sin(t * 1.4 + l.ph * 2);
    return v.clamp(0.08, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _kW;
    canvas.save();
    canvas.scale(s);

    // layer 0: base art, source-over, nearest-neighbour
    canvas.drawImageRect(
      base,
      Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
      const Rect.fromLTWH(0, 0, _kW, _kH),
      Paint()..filterQuality = FilterQuality.none,
    );

    final t = moving ? tick.value.toDouble() : 0.0;
    final flameOn = moving && flicker;

    // ---- torches: breathing glow + warped flame rows (additive) ----
    for (final f in _flames) {
      final flick = flameOn
          ? (0.8 + 0.2 * (math.sin(t * 0.9 + f.phase) * 0.5 + 0.5))
          : 0.96;
      final gr = (11 + 5 * (math.sin(t * 0.7 + f.phase) * 0.5 + 0.5)) * glow;
      _rGlow(canvas, f.cx, f.sy + f.h * 0.42, gr, 255, 140, 64,
          0.16 * glow * flick);

      // globalAlpha = flick + composite 'lighter' over the row blits:
      // composite the rows in an additive layer at opacity `flick`.
      final rowsBounds = Rect.fromLTWH(f.sx - 4, f.sy, f.w + 8, f.h);
      canvas.saveLayer(
        rowsBounds,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 255, 255, flick.clamp(0.0, 1.0)),
      );
      final rowPaint = Paint()..filterQuality = FilterQuality.none;
      for (var r = 0; r < f.h; r++) {
        final topness = 1 - r / f.h;
        var off = 0;
        if (flameOn) {
          off = _jsRound(math.sin(t * 0.45 + f.phase + r * 0.42) * 2.0 * topness +
              math.sin(t * 0.95 + f.phase) * 1.0 * topness);
        }
        final yy = f.sy + r;
        canvas.drawImageRect(
          flame,
          Rect.fromLTWH(f.sx, yy, f.w, 1),
          Rect.fromLTWH(f.sx + off, yy, f.w, 1),
          rowPaint,
        );
      }
      canvas.restore();
    }

    // ---- embers (additive, gated on flameOn) ----
    if (flameOn && drawEmbers) {
      final p = Paint()..blendMode = BlendMode.plus;
      for (final e in embers) {
        final k = 1 - e.life / e.max;
        p.color = k > 0.6
            ? const Color(0xFFFFE9B0)
            : k > 0.3
                ? const Color(0xFFFFC24A)
                : const Color(0xFFFF9A3A);
        canvas.drawRect(
          Rect.fromLTWH(
              _jsRound(e.x).toDouble(), _jsRound(e.y).toDouble(), 1, 1),
          p,
        );
      }
    }

    // ---- teal indicator lights (additive) ----
    if (lights) {
      for (final l in _lights) {
        final double p;
        if (!moving) {
          p = 0.6;
        } else if (l.fl) {
          p = _techFlicker(t, l);
        } else {
          p = 0.5 + 0.5 * math.sin(t * l.sp + l.ph);
        }
        _rGlow(canvas, l.x, l.y, l.r * (0.8 + 0.35 * p), 55, 214, 207,
            l.base + l.amp * p);
      }
    }

    // ---- dust (additive, gated on moving) ----
    if (moving && drawDust) {
      final p = Paint()..blendMode = BlendMode.plus;
      for (final m in dust) {
        final k = math.sin(math.pi * math.min(1.0, m.life / m.max));
        p.color =
            const Color(0xFFFFD9A0).withValues(alpha: (m.a * k).clamp(0.0, 1.0));
        canvas.drawRect(
          Rect.fromLTWH(
              _jsRound(m.x).toDouble(), _jsRound(m.y).toDouble(), 1, 1),
          p,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HallPainter old) =>
      old.moving != moving ||
      old.glow != glow ||
      old.flicker != flicker ||
      old.drawEmbers != drawEmbers ||
      old.lights != lights ||
      old.drawDust != drawDust ||
      old.base != base ||
      old.flame != flame;
}
