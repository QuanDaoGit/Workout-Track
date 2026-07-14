import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../models/character.dart';
import '../../services/haptic_service.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/arcade_tap.dart';
import '../../widgets/companion/bit_mood_core.dart';
import '../../widgets/companion/bit_speech_bubble.dart';
import '../../widgets/motion/ambient_drift.dart';
import '../../widgets/pixel_button.dart';
import 'charge_ritual_screen.dart';
import 'start_gate_screen.dart';

/// The **gift reveal** — a once-only beat after the reminders primer. BIT fills
/// the screen (huge, neutral) offering a gift; on **YES** he flies a banked arc
/// down into his seat and the screen fades into the Charge Ritual; on **skip**
/// he flies to his gate seat and the screen fades into the Start Gate. The
/// within-screen flight (arc · bank · overshoot-settle · thrust trail · shaped
/// haptic swell) reuses the Session-Complete ceremony's motion, but BIT stays
/// **neutral** throughout (no cheer burst). Reduced motion: no flight, a plain
/// navigate.
class GiftRevealScreen extends StatefulWidget {
  const GiftRevealScreen({
    super.key,
    required this.character,
    this.avatarSpec = AvatarSpec.fallback,
  });

  final Character character;
  final AvatarSpec avatarSpec;

  @override
  State<GiftRevealScreen> createState() => _GiftRevealScreenState();
}

// ── flight easing (verbatim from session_ceremony) ───────────────────────────
double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _easeOutCubic(double v) => 1 - math.pow(1 - v, 3).toDouble();
double _easeInOutCubic(double v) =>
    v < 0.5 ? 4 * v * v * v : 1 - math.pow(-2 * v + 2, 3).toDouble() / 2;

/// Pull-back (−4%) → accelerate → 4% overshoot → settle.
double _flightProg(double p) {
  if (p < 0.14) return -0.04 * math.sin((p / 0.14) * math.pi * 0.5);
  if (p < 0.82) return -0.04 + 1.08 * _easeInOutCubic((p - 0.14) / 0.68);
  return 1.04 - 0.04 * _easeOutCubic((p - 0.82) / 0.18);
}

class _Trail {
  _Trail(this.pos, this.color);
  final Offset pos;
  final Color color;
  double age = 0; // frames
}

class _GiftRevealScreenState extends State<GiftRevealScreen>
    with TickerProviderStateMixin {
  static const double _bitPx = 200;
  static const int _flightMs = 1300;
  static const int _blackoutMs = 240;

  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _flightMs),
  );

  // A brief fade-through-black at the landing: both destinations start dark, so
  // covering the gift screen before the route swap hides BIT's approximate
  // seat→destination position handoff — there's no A/B comparison through a
  // plain crossfade (Codex F3).
  late final AnimationController _blackout = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _blackoutMs),
  );

  bool _flying = false;
  bool _toRitual = true;
  bool _routed = false;
  Size _size = Size.zero;
  Offset _bitPos = Offset.zero;
  final List<_Trail> _trail = [];

  bool get _reduceMotion {
    final m = MediaQuery.of(context);
    return m.disableAnimations || m.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _flight.addListener(_onFlightTick);
    _flight.addStatusListener((s) {
      if (s == AnimationStatus.completed) _startBlackout();
    });
    _blackout.addStatusListener((s) {
      if (s == AnimationStatus.completed) _navigate();
    });
  }

  @override
  void dispose() {
    HapticService.instance.stopBuzz();
    _flight.dispose();
    _blackout.dispose();
    super.dispose();
  }

  Offset _origin(Size s) => Offset(s.width / 2, s.height * 0.38);
  Offset _target(Size s) =>
      _toRitual ? Offset(s.width / 2, s.height * 0.60) : Offset(s.width / 2, s.height * 0.46);

  // Per-frame: track BIT's position + spawn/age the thrust trail.
  void _onFlightTick() {
    if (!_flying || _size == Size.zero) return;
    final p = _flight.value;
    final e = _flightProg(p);
    final ec = _clamp01(e);
    final origin = _origin(_size), target = _target(_size);
    final bow = -math.sin(ec * math.pi) * 64;
    _bitPos = origin + Offset((target.dx - origin.dx) * e + bow, (target.dy - origin.dy) * e);
    // Spawn a trail spark mid-flight; age + drain existing ones.
    if (p > 0.10 && p < 0.94) {
      _trail.add(_Trail(
        _bitPos + Offset((_flight.value * 97 % 7) - 3, 10),
        p.hashCode.isEven ? kAmber : kAmberDark,
      ));
    }
    for (var i = _trail.length - 1; i >= 0; i--) {
      _trail[i].age += 1;
      if (_trail[i].age > 14) _trail.removeAt(i);
    }
  }

  void _launch({required bool toRitual}) {
    if (_flying || _routed) return;
    _toRitual = toRitual;
    if (_reduceMotion) {
      _navigate();
      return;
    }
    setState(() => _flying = true);
    // Match the Session-Complete ceremony's flight beat exactly: the dash-fwoosh
    // SFX + the shaped amplitude swell fire together at launch.
    SfxService.instance.playCeremonyFlight();
    HapticService.instance.flightSwell();
    _flight.forward(from: 0);
  }

  // The flight has settled BIT into his seat — thump on impact, then fade to
  // black before swapping routes (see [_blackout]).
  void _startBlackout() {
    if (!mounted || _routed) return;
    // Ceremony land beat: cut the flight swell, then the impact thud + thump.
    HapticService.instance.stopBuzz();
    HapticService.instance.landThump();
    SfxService.instance.playCeremonyLand();
    _blackout.forward();
  }

  void _navigate() {
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => _toRitual
            ? ChargeRitualScreen(
                character: widget.character,
                avatarSpec: widget.avatarSpec,
              )
            : StartGateScreen(
                character: widget.character,
                avatarSpec: widget.avatarSpec,
              ),
        motion: ArcadeRouteMotion.fade,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.character.characterName;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBg,
        body: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: AmbientDrift())),
            LayoutBuilder(
              builder: (context, constraints) {
                _size = Size(constraints.maxWidth, constraints.maxHeight);
                final origin = _origin(_size);
                return AnimatedBuilder(
                  animation: _flight,
                  builder: (context, _) {
                    final p = _flight.value;
                    final e = _flightProg(p);
                    final ec = _clamp01(e);
                    final origin2 = origin;
                    final target = _target(_size);
                    final bow = -math.sin(ec * math.pi) * 64;
                    final dx = (target.dx - origin2.dx) * e + bow;
                    final dy = (target.dy - origin2.dy) * e;
                    final bank = -math.sin(ec * math.pi) * 6 * math.pi / 180;
                    final scale = 1 + (0.36 - 1) * ec;
                    final promptOp = (1 - (p / 0.12)).clamp(0.0, 1.0);
                    return Stack(
                      children: [
                        // Soft radial thrust glow + amber trail behind BIT.
                        if (_flying)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _TrailPainter(
                                  List.of(_trail),
                                  glowPos: _bitPos,
                                  glowAlpha: 0.5 * math.sin(ec * math.pi),
                                  glowRadius: (scale * _bitPx) * 0.5,
                                ),
                              ),
                            ),
                          ),
                        // BIT — huge, neutral, flying the banked arc.
                        Positioned(
                          left: origin2.dx - _bitPx / 2,
                          top: origin2.dy - _bitPx / 2,
                          width: _bitPx,
                          height: _bitPx,
                          child: Transform(
                            transform: Matrix4.translationValues(dx, dy, 0)
                              ..rotateZ(bank)
                              ..scaleByDouble(scale, scale, 1, 1),
                            alignment: Alignment.center,
                            // Glow is painted behind BIT (soft radial in the trail
                            // painter) — a box shadow here casts a boxy square.
                            child: const BitMoodCore(
                              pose: BitPose.neutral,
                              reveal: 1,
                              size: _bitPx,
                            ),
                          ),
                        ),
                        // The offer — fades out the instant the flight begins.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            ignoring: _flying,
                            child: Opacity(
                              opacity: promptOp,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  kSpace4,
                                  0,
                                  kSpace4,
                                  kSpace5,
                                ),
                                child: _Offer(
                                  name: name,
                                  reduceMotion: _reduceMotion,
                                  onYes: () => _launch(toRitual: true),
                                  onSkip: () => _launch(toRitual: false),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            // Fade-through-black at the landing — hides the seat→destination
            // position handoff (both destinations start dark).
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _blackout,
                  builder: (context, _) => _blackout.value <= 0
                      ? const SizedBox.shrink()
                      : Opacity(
                          opacity: _blackout.value,
                          child: const ColoredBox(color: kBg),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// BIT's line + the YES / skip pair.
class _Offer extends StatelessWidget {
  const _Offer({
    required this.name,
    required this.reduceMotion,
    required this.onYes,
    required this.onSkip,
  });

  final String name;
  final bool reduceMotion;
  final VoidCallback onYes;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A GIFT BEFORE YOU BEGIN',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 13,
            height: 1.4,
            color: kAmber,
          ),
        ),
        const SizedBox(height: kSpace3),
        BitSpeechBubble(
          text: "I saved you something, $name. Want to see it?",
          emphasis: name,
          tailDirection: BitTailDirection.none,
          typewriter: !reduceMotion,
          fontSize: 13,
        ),
        const SizedBox(height: kSpace4),
        Semantics(
          button: true,
          label: 'Yes, show me the gift',
          child: PixelButton(label: 'YES — SHOW ME', minHeight: 56, onPressed: onYes),
        ),
        const SizedBox(height: kSpace3),
        Semantics(
          button: true,
          label: 'Not now, take me to the start gate',
          child: ArcadeTap(
            onTap: onSkip,
            haptic: HapticIntent.selection,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'not now — take me to the start',
                textAlign: TextAlign.center,
                style: AppFonts.shareTechMono(color: kDim, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(
    this.trail, {
    this.glowPos,
    this.glowAlpha = 0,
    this.glowRadius = 0,
  });
  final List<_Trail> trail;
  final Offset? glowPos;
  final double glowAlpha;
  final double glowRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // Soft radial thrust glow behind BIT (round + soft — not a boxy shadow).
    final gp = glowPos;
    if (gp != null && glowAlpha > 0.01 && glowRadius > 0) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            kAmber.withValues(alpha: glowAlpha),
            kAmber.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: gp, radius: glowRadius));
      canvas.drawCircle(gp, glowRadius, glow);
    }
    final paint = Paint()..isAntiAlias = false;
    for (final t in trail) {
      final a = (1 - t.age / 14).clamp(0.0, 1.0);
      if (a <= 0.02) continue;
      paint.color = t.color.withValues(alpha: a * 0.9);
      final s = 3.0 + 2 * a;
      canvas.drawRect(
        Rect.fromCenter(center: t.pos, width: s, height: s),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => true;
}
