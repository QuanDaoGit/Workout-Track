import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../services/sfx_service.dart';
import '../services/ui_sound.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

/// The center Train action's visual/behavioural state.
/// Precedence (decided by the shell): [live] > [armedReady] > [armedLocked] > [idle].
enum TrainButtonMode {
  /// No session, no draft — the resting sword keycap.
  idle,

  /// A draft selection is open but invalid (0 exercises) — dim, no lure.
  armedLocked,

  /// A valid draft (≥1 exercise) — breathing "charged" glow that invites the press.
  armedReady,

  /// A live session — dark face, mm:ss timer, marching ring + breathing glow.
  live,
}

/// The center Train action — a pixel-stepped, cut-corner "keycap" with a
/// pressable bottom depth face (no round/flat-diagonal edges). The face content
/// and motion are driven by [mode]; all motion freezes under reduced motion, and
/// each mode carries an explicit Semantics label so the control is usable
/// without perceiving the animation.
class TrainNavButton extends StatefulWidget {
  const TrainNavButton({
    super.key,
    required this.mode,
    required this.onTap,
    this.elapsedLabel,
  });

  final TrainButtonMode mode;
  final VoidCallback onTap;

  /// mm:ss (or h:mm:ss) shown on the keycap while [mode] is [TrainButtonMode.live].
  final String? elapsedLabel;

  @override
  State<TrainNavButton> createState() => _TrainNavButtonState();
}

class _TrainNavButtonState extends State<TrainNavButton>
    with TickerProviderStateMixin {
  static const double _w = 48;
  static const double _faceH = 44;
  static const double _depth = 4;
  static const double _step = 4;

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  // Armed-ready: faint motes drift slowly up the face — a low-salience "alive /
  // ready when you are" cue that doesn't pull focus from exercise selection.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  bool _pressed = false;
  bool _reduceMotion = false;

  bool get _glows => widget.mode == TrainButtonMode.live;
  bool get _marches => widget.mode == TrainButtonMode.live;
  bool get _driftsMotes => widget.mode == TrainButtonMode.armedReady;

  String get _caption =>
      widget.mode == TrainButtonMode.armedReady ? 'START' : 'TRAIN';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _sync();
  }

  @override
  void didUpdateWidget(TrainNavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _sync();
  }

  void _sync() {
    if (_glows && !_reduceMotion) {
      if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
    } else {
      _breathe.stop();
      _breathe.value = _reduceMotion && _glows ? 0.5 : 0;
    }
    if (_marches && !_reduceMotion) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      _sweep.stop();
    }
    if (_driftsMotes && !_reduceMotion) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
      _drift.value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _breathe.dispose();
    _drift.dispose();
    super.dispose();
  }

  String get _semanticsLabel => switch (widget.mode) {
    TrainButtonMode.idle => 'Start training',
    TrainButtonMode.armedLocked => 'Pick at least one exercise to start',
    TrainButtonMode.armedReady => 'Start selected workout',
    TrainButtonMode.live => 'Resume workout',
  };

  @override
  Widget build(BuildContext context) {
    final Widget content = widget.mode == TrainButtonMode.live
        ? Text(
            widget.elapsedLabel ?? '0:00',
            style: AppFonts.shareTechMono(color: kNeon, fontSize: 9),
          )
        : ImageIcon(
            const AssetImage('assets/icons/control/icon_sword.png'),
            color: widget.mode == TrainButtonMode.armedLocked ? kMutedText : kBg,
            size: 22,
          );

    return Semantics(
      button: true,
      label: _semanticsLabel,
      // Bespoke keycap: onTapDown/Up/Cancel drive the press-depth animation.
      // haptic-ok: wrappers don't expose those; fires HapticService.tap() inline.
      child: GestureDetector(
        onTap: () {
          // The hero action gets a light press tap (the keystone bar's lone CTA)
          // + part 2 of its "heavy keycap" signature — the dyad ENGAGE at
          // commit (part 1, the thunk, fired at tap-down). One owner: no
          // generic tick on the hero key.
          HapticService.instance.tap();
          SfxService.instance.playUi(UiSound.trainUp);
          widget.onTap();
        },
        onTapDown: (_) {
          // Signature part 1: the felt down-thunk, synced with the keycap sink.
          SfxService.instance.playUi(UiSound.trainDown);
          setState(() => _pressed = true);
        },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -14),
              child: SizedBox(
                width: _w,
                height: _faceH + _depth,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_sweep, _breathe, _drift]),
                        builder: (_, _) => CustomPaint(
                          painter: _KeycapPainter(
                            mode: widget.mode,
                            pressed: _pressed,
                            sweep: _sweep.value,
                            glow: _breathe.value,
                            drift: _drift.value,
                            step: _step,
                            depth: _depth,
                            faceH: _faceH,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _pressed ? _depth : 0,
                      height: _faceH,
                      child: Center(child: content),
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Text(
                _caption,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  // Caption is identity-white, never neon — the neon belongs to
                  // the keycap face alone (the lone hero in the bar). The
                  // TRAIN→START text swap still carries the armed-ready cue.
                  color: widget.mode == TrainButtonMode.armedLocked
                      ? kMutedText
                      : kText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeycapPainter extends CustomPainter {
  _KeycapPainter({
    required this.mode,
    required this.pressed,
    required this.sweep,
    required this.glow,
    required this.drift,
    required this.step,
    required this.depth,
    required this.faceH,
  });

  final TrainButtonMode mode;
  final bool pressed;
  final double sweep;
  final double glow;
  final double drift;
  final double step;
  final double depth;
  final double faceH;

  static const Color _idleDepth = Color(0xFF0A7A4D); // darker neon = keycap base
  static const Color _lockedFace = Color(0xFF143B2B); // muted = not ready
  static const Color _lockedDepth = Color(0xFF0C2418);
  static const Color _liveFace = Color(0xFF0C1712);
  static const Color _liveDepth = Color(0xFF052017);

  /// A square with 2-step pixel-staircase corners (no diagonal/round edges).
  Path _facePath(Rect r, double s) {
    final l = r.left, t = r.top, rr = r.right, b = r.bottom;
    final c = 2 * s;
    return Path()
      ..moveTo(l + c, t)
      ..lineTo(rr - c, t)
      ..lineTo(rr - s, t)
      ..lineTo(rr - s, t + s)
      ..lineTo(rr, t + s)
      ..lineTo(rr, t + c)
      ..lineTo(rr, b - c)
      ..lineTo(rr, b - s)
      ..lineTo(rr - s, b - s)
      ..lineTo(rr - s, b)
      ..lineTo(rr - c, b)
      ..lineTo(l + c, b)
      ..lineTo(l + s, b)
      ..lineTo(l + s, b - s)
      ..lineTo(l, b - s)
      ..lineTo(l, b - c)
      ..lineTo(l, t + c)
      ..lineTo(l, t + s)
      ..lineTo(l + s, t + s)
      ..lineTo(l + s, t)
      ..close();
  }

  bool get _glows => mode == TrainButtonMode.live;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final faceTop = pressed ? depth : 0.0;
    final mainPath = _facePath(Rect.fromLTWH(0, faceTop, w, faceH), step);

    // Pressable depth base — hidden once the keycap is pressed onto it.
    if (!pressed) {
      final depthColor = switch (mode) {
        TrainButtonMode.live => _liveDepth,
        TrainButtonMode.armedLocked => _lockedDepth,
        _ => _idleDepth,
      };
      canvas.drawPath(
        _facePath(Rect.fromLTWH(0, depth, w, faceH), step),
        Paint()
          ..isAntiAlias = false
          ..color = depthColor,
      );
    }

    // Keycap face.
    final faceColor = switch (mode) {
      TrainButtonMode.live => _liveFace,
      TrainButtonMode.armedLocked => _lockedFace,
      _ => kNeon,
    };
    canvas.drawPath(
      mainPath,
      Paint()
        ..isAntiAlias = false
        ..color = faceColor,
    );

    // Dark seating bezel — a crisp dark frame (darker than the kCard bar) so the
    // bright cap reads as a physical key *seated* in the bar (figure/ground),
    // not a flat neon fill flush with it. On the dark live/locked faces it just
    // merges; it earns its keep on the bright idle/armed-ready neon face. Drawn
    // under the live halo/ring so those state signals still win.
    canvas.drawPath(
      mainPath,
      Paint()
        ..isAntiAlias = false
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = kBg,
    );

    // Breathing phosphor halo (armedReady + live) — the "lure"/"alive" cue.
    if (_glows) {
      canvas.drawPath(
        mainPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = kNeon.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + glow * 5.0),
      );
    }

    // Live only: dim base ring + marching segmented neon ring (the sweep).
    if (mode == TrainButtonMode.live) {
      canvas.drawPath(
        mainPath,
        Paint()
          ..isAntiAlias = false
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = kNeon.withValues(alpha: 0.25),
      );
      final metric = mainPath.computeMetrics().first;
      final len = metric.length;
      const seg = 6.0, gap = 5.0, period = seg + gap;
      final phase = sweep * period;
      final segPaint = Paint()
        ..isAntiAlias = false
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.butt
        ..color = kNeon;
      for (double d = -phase; d < len; d += period) {
        final start = math.max(0.0, d);
        final end = math.min(len, d + seg);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), segPaint);
        }
      }
    }

    // Armed-ready: faint motes drift slowly up the face (clipped to it) — a
    // low-salience "ready" cue, distinct from the live marching ring.
    if (mode == TrainButtonMode.armedReady) {
      canvas.save();
      canvas.clipPath(mainPath);
      // Dark green flecks rise through the bright neon face. On a light fill
      // luminance contrast (dark-on-bright), not a pale tint, is what makes
      // particles legible — so these are near-black-green, not white.
      const xs = [0.18, 0.34, 0.5, 0.66, 0.82];
      const phases = [0.0, 0.32, 0.58, 0.16, 0.74];
      final motePaint = Paint()..isAntiAlias = false;
      for (var i = 0; i < 5; i++) {
        final local = (drift + phases[i]) % 1.0;
        final y = faceTop + faceH - local * faceH;
        final op = (math.sin(local * math.pi) * 0.85).clamp(0.0, 0.85);
        motePaint.color = const Color(0xFF052A1C).withValues(alpha: op);
        canvas.drawRect(Rect.fromLTWH(w * xs[i], y, 3, 3), motePaint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_KeycapPainter old) =>
      old.mode != mode ||
      old.pressed != pressed ||
      old.sweep != sweep ||
      old.glow != glow ||
      old.drift != drift;
}
