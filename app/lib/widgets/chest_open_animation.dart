import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Reward chest — a faithful port of the `design_handoff_chest_open_animation`
/// handoff (`Chest Open Animation.dc.html` `draw(T)`). It shows the closed chest
/// while a quest section is unfinished, and plays a **one-shot** rattle → pop-open
/// + pixel-burst + amber bloom when the section is cleared, settling on the open
/// chest. The page fires the gem-flight from [onOpened] (the lid-pop instant).
///
/// DELTAS from the 300×341 standalone stage (delta contract, Codex F5): it renders
/// **inline at the end-of-bar slot** (no stage chrome / scanline), plays **once on
/// completion** (not the perpetual loop, no closed-idle bob), and the open triggers
/// the app's real gem-flight. All Layer-1 motion (phase timings, bottom-center pop
/// scale, closed→open alpha cross, bloom curve, ring/beams/sparkles/flash) is
/// ported verbatim in the 300×341 design space and `canvas.scale`d to the slot, so
/// the FX coords stay native. Reduced motion → a static open frame.
class ChestOpenAnimation extends StatefulWidget {
  const ChestOpenAnimation({
    super.key,
    required this.height,
    required this.open,
    this.play = false,
    this.onOpened,
  });

  /// Slot height in logical px; width follows the sprite's 300:341 aspect.
  final double height;

  /// Static end state when not [play]ing: open chest (section cleared) vs closed.
  final bool open;

  /// Flip false→true to fire the one-shot rattle→open once. Ignored under reduced
  /// motion (the chest just shows [open]).
  final bool play;

  /// Fired once at the lid-pop instant (open phase ~start) — the page launches the
  /// bonus gem-flight from the chest here. Not called under reduced motion.
  final VoidCallback? onOpened;

  /// Design-space dimensions (the handoff stage); the painter works in these and
  /// scales to the slot.
  static const double dsW = 300;
  static const double dsH = 341;

  /// One-shot duration = rattle (650) + open (2600); the closed-idle phase is
  /// dropped (the static closed chest is the resting state).
  static const Duration playDuration = Duration(milliseconds: 3250);
  static const int _rattleMs = 650;

  @override
  State<ChestOpenAnimation> createState() => _ChestOpenAnimationState();
}

class _ChestOpenAnimationState extends State<ChestOpenAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  ui.Image? _closed;
  ui.Image? _open;
  bool _firedOpened = false;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: ChestOpenAnimation.playDuration)
      ..addListener(_onTick);
    _loadSprites();
  }

  bool get _reduceMotion {
    final mq = MediaQuery.maybeOf(context);
    return (mq?.disableAnimations ?? false) || (mq?.accessibleNavigation ?? false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = _reduceMotion;
    if (widget.play && !_reduce && !_ctrl.isAnimating && _ctrl.value == 0) {
      _start();
    }
  }

  @override
  void didUpdateWidget(ChestOpenAnimation old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play && !_reduce) {
      _start();
    }
  }

  void _start() {
    _firedOpened = false;
    _ctrl.forward(from: 0);
  }

  // Fire onOpened once, at the open-phase start (the lid pops) — the gem-flight
  // launch instant. Driven off the controller's own listener (no parallel timer).
  void _onTick() {
    if (_firedOpened) return;
    final ms = _ctrl.value * ChestOpenAnimation.playDuration.inMilliseconds;
    if (ms >= ChestOpenAnimation._rattleMs) {
      _firedOpened = true;
      widget.onOpened?.call();
    }
  }

  Future<void> _loadSprites() async {
    final closed = await _decode('assets/icons/control/chest/chest_closed.png');
    final open = await _decode('assets/icons/control/chest/chest_open.png');
    if (!mounted) return;
    setState(() {
      _closed = closed;
      _open = open;
    });
  }

  Future<ui.Image?> _decode(String asset) async {
    try {
      final completer = Completer<ui.Image>();
      final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (e, _) {
          if (!completer.isCompleted) completer.completeError(e);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      return await completer.future;
    } catch (_) {
      return null; // a painted fallback covers a missing/undecodable sprite
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.height * ChestOpenAnimation.dsW / ChestOpenAnimation.dsH;
    return SizedBox(
      width: w,
      height: widget.height,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            size: Size(w, widget.height),
            painter: _ChestPainter(
              closed: _closed,
              open: _open,
              // playing only while the controller is mid-run; otherwise static.
              playT: (_ctrl.isAnimating && !_reduce) ? _ctrl.value : null,
              open01: widget.open,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChestPainter extends CustomPainter {
  _ChestPainter({
    required this.closed,
    required this.open,
    required this.playT,
    required this.open01,
  });

  final ui.Image? closed;
  final ui.Image? open;

  /// Null = static frame (draw [open01]); else the one-shot progress 0..1.
  final double? playT;
  final bool open01;

  static const double _dsW = ChestOpenAnimation.dsW;
  static const double _dsH = ChestOpenAnimation.dsH;

  // JS `Math.round` rounds ties toward +∞; Dart `.round()` rounds away from zero
  // — match the source exactly so pixel positions don't drift (porting learning).
  static int _r(double x) => (x + 0.5).floor();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _dsW, size.height / _dsH);

    final t = playT;
    if (t == null) {
      // Static frame: closed (unfinished) or open + a calm bloom (cleared).
      if (open01) {
        _chest(canvas, open, 1, 0, 0, 1, 0.28);
      } else {
        _chest(canvas, closed, 1, 0, 0, 1, 0);
      }
      canvas.restore();
      return;
    }

    // One-shot timeline: rattle (0..650ms) → open (0..2600ms). (The closed-idle
    // bob is dropped — see the class doc.)
    final ms = t * ChestOpenAnimation.playDuration.inMilliseconds;
    if (ms < ChestOpenAnimation._rattleMs) {
      _rattle(canvas, ms);
    } else {
      _open(canvas, ms - ChestOpenAnimation._rattleMs);
    }
    canvas.restore();
  }

  // ── phases (ported from draw()) ──────────────────────────────────────────

  void _rattle(Canvas canvas, double local) {
    const rattleMs = ChestOpenAnimation._rattleMs;
    final amp = 1 + _r(3 * (local / rattleMs));
    final dir = (local ~/ 70) % 2 == 1 ? -1 : 1;
    _chest(canvas, closed, 1, (amp * dir).toDouble(), 0, 1, 0);
  }

  void _open(Canvas canvas, double local) {
    const cx = 150.0, oy = 138.0;

    // closed sprite fades out over the first 110ms.
    if (local < 110) {
      _chest(canvas, closed, 1 - local / 110, 0, 0, 1, 0);
    }
    // open sprite: stepped pop about bottom-center + alpha ramp + amber bloom.
    final double sc = local < 90
        ? 0.9
        : local < 185
            ? 1.12
            : local < 285
                ? 0.98
                : 1.0;
    final oOp = (local / 100).clamp(0.0, 1.0);
    final bloom = 0.28 + 0.16 * math.sin(local / 240);
    _chest(canvas, open, oOp, 0, 0, sc, bloom);

    // expanding ring (0..540ms): 12 alternating amber/neon 8px blocks.
    if (local < 540) {
      final r = (local ~/ 52) * 9.0;
      final ro = (1 - local / 540).clamp(0.0, 1.0);
      for (var i = 0; i < 12; i++) {
        final a = i / 12 * math.pi * 2;
        _px(canvas, cx + math.cos(a) * r, oy + math.sin(a) * r, 8,
            i.isOdd ? kNeon : kAmber, ro);
      }
    }
    // light beams (0..620ms): three columns of stacked squares rising.
    if (local < 620) {
      final flick = (local ~/ 55) % 2 == 1 ? 1.0 : 0.5;
      final fade = (1 - local / 620).clamp(0.0, 1.0);
      const cols = [112.0, 150.0, 188.0];
      for (var bi = 0; bi < cols.length; bi++) {
        for (var k = 0; k < 6; k++) {
          final w = math.max(3, 7 - k).toDouble();
          _px(canvas, cols[bi], oy - 8 - k * 15, w,
              bi == 1 ? _amberLite : kAmber, fade * flick * (1 - k / 7));
        }
      }
    }
    // plus-sparkles: staggered "+" pops.
    const sparks = [
      [150.0, 58.0, 0.0],
      [104.0, 88.0, 55.0],
      [196.0, 88.0, 55.0],
      [120.0, 118.0, 115.0],
      [182.0, 114.0, 115.0],
      [150.0, 96.0, 175.0],
    ];
    const sparkColors = [kWhite, kAmber, kAmber, kNeon, kNeon, _amberLite];
    for (var i = 0; i < sparks.length; i++) {
      final lt = local - sparks[i][2];
      if (lt < 0 || lt > 330) continue;
      final k = lt / 330;
      final tri = k < 0.5 ? k / 0.5 : 1 - (k - 0.5) / 0.5;
      final arm = math.max(1, _r(4 * tri)).toDouble();
      _plus(canvas, sparks[i][0], sparks[i][1], arm, sparkColors[i], tri * 1.2);
    }
    // flat flash (0..140ms): a screen-blended full-stage amber wash.
    if (local < 140) {
      final fo = local < 55 ? 0.26 : (local < 100 ? 0.14 : 0.05);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _dsW, _dsH),
        Paint()
          ..color = _amberLite.withValues(alpha: fo)
          ..blendMode = BlendMode.screen,
      );
    }
  }

  // ── primitives ───────────────────────────────────────────────────────────

  /// Draw a chest sprite (or the painted fallback) with [alpha], a (tx,ty)
  /// translate, a [sc] scale about the bottom-center (so the lid "rises"), and an
  /// amber [bloomA] glow behind it.
  void _chest(Canvas canvas, ui.Image? img, double alpha, double tx, double ty,
      double sc, double bloomA) {
    if (alpha <= 0) return;
    canvas.save();
    canvas.translate(tx, ty);
    canvas.translate(150, _dsH);
    canvas.scale(sc, sc);
    canvas.translate(-150, -_dsH);
    final dst = const Rect.fromLTWH(0, 0, _dsW, _dsH);
    if (img != null) {
      final src = Rect.fromLTWH(
          0, 0, img.width.toDouble(), img.height.toDouble());
      if (bloomA > 0) {
        canvas.drawImageRect(
          img,
          src,
          dst,
          Paint()
            ..colorFilter = ColorFilter.mode(
                kAmber.withValues(alpha: (bloomA * alpha).clamp(0.0, 1.0)),
                BlendMode.srcATop)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.none
          ..color = kWhite.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    } else {
      _fallbackChest(canvas, open01 || (img == open), alpha);
    }
    canvas.restore();
  }

  // A painted pixel chest so a missing/undecoded sprite never blanks the slot
  // (asset-fallback discipline). Coarse, in the handoff's green ramp.
  void _fallbackChest(Canvas canvas, bool isOpen, double alpha) {
    final p = Paint()..isAntiAlias = false;
    void rc(double x, double y, double w, double h, Color c) {
      p.color = c.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), p);
    }

    const body = Color(0xFF43A866), lid = Color(0xFF8FE89C),
        outline = Color(0xFF161616), lock = kAmber;
    // body
    rc(70, 170, 160, 140, body);
    rc(70, 170, 160, 6, outline);
    if (isOpen) {
      // lid lifted + open interior
      rc(64, 90, 172, 60, lid);
      rc(64, 90, 172, 6, outline);
      rc(86, 186, 128, 40, const Color(0xFF04230F));
    } else {
      rc(64, 150, 172, 44, lid);
      rc(64, 150, 172, 6, outline);
    }
    rc(140, isOpen ? 196 : 188, 20, 26, lock); // latch
  }

  void _px(Canvas canvas, double x, double y, double s, Color color, double alpha) {
    if (alpha <= 0) return;
    canvas.drawRect(
      Rect.fromLTWH(
          _r(x - s / 2).toDouble(), _r(y - s / 2).toDouble(), s, s),
      Paint()
        ..isAntiAlias = false
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  void _plus(Canvas canvas, double x, double y, double a, Color c, double alpha) {
    _px(canvas, x, y, a, c, alpha);
    _px(canvas, x, y - a, a, c, alpha);
    _px(canvas, x, y + a, a, c, alpha);
    _px(canvas, x - a, y, a, c, alpha);
    _px(canvas, x + a, y, a, c, alpha);
  }

  @override
  bool shouldRepaint(covariant _ChestPainter old) =>
      old.playT != playT ||
      old.open01 != open01 ||
      old.closed != closed ||
      old.open != open;
}

/// Lighter amber for the flash/beam centre — an engine shade from the handoff's
/// sprite palette (`#FFE680`), the documented raw-`Color` exception (like the
/// arcade-bar / quest-board sprite consts); meter/label colours stay token-driven.
const Color _amberLite = Color(0xFFFFE680);
