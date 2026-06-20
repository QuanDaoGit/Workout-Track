import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/adventure_routes.dart';
import '../../theme/tokens.dart';
import 'bit_route_walker.dart';

/// The expedition diorama: a continuously-scrolling parallax scene built
/// from a route's three still layers (sky static, far at ~30% speed, ground
/// at full speed wrapping seamlessly) with [BitRouteWalker] hover-gliding on
/// top. Backdrops are authored at 480×270 / 480×96 native pixel art and
/// scaled with nearest-neighbor ([FilterQuality.none]) so pixels stay crisp.
///
/// Degrades gracefully (Codex finding): every layer has an errorBuilder
/// fallback to token-palette gradients, so a missing/corrupt PNG renders an
/// abstract scene instead of crashing. Reduced motion (or [animate] false)
/// freezes the scene — same assets, zero movement.
class RouteDiorama extends StatefulWidget {
  const RouteDiorama({
    super.key,
    required this.route,
    this.height = 200,
    this.animate = true,
    this.showWalker = true,
    this.framed = false,
    this.darkened = false,
  });

  final AdventureRouteDef route;
  final double height;

  /// Scroll the parallax layers + particles. Exactly one diorama on a screen
  /// should animate at a time (the armed or active route).
  final bool animate;

  /// Render the traveling character. Decoupled from [animate] so a selection
  /// backdrop can scroll *without* a sprite (armed preview), and the active
  /// route can scroll *with* it (on expedition).
  final bool showWalker;

  /// Draw a decorative pixel frame (border + corner ticks) around the scene.
  final bool framed;

  /// Dim the scene with a scrim (locked / inspect states).
  final bool darkened;

  // Native art dimensions.
  static const _nativeW = 480.0;
  static const _nativeH = 270.0;
  static const _groundNativeH = 96.0;

  /// BIT renders at this multiple of the world pixel-density — a deliberate
  /// foreground-emphasis so the focal protagonist reads at a glance (1×
  /// world-scale was too small). Chosen by eye against the live backdrop.
  static const _bitDensity = 3.5;

  @override
  State<RouteDiorama> createState() => _RouteDioramaState();
}

class _RouteDioramaState extends State<RouteDiorama>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    // One long repeating clock; offsets derive from elapsed time so speed
    // stays frame-rate independent.
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncClock(); // handles reduced-motion / MediaQuery changes
  }

  @override
  void didUpdateWidget(RouteDiorama old) {
    super.didUpdateWidget(old);
    // `animate` is a widget prop, so a parent flipping the single animation
    // owner (re-arm A→B, armed→out) must restart/stop the clock here —
    // didChangeDependencies does NOT fire on a prop change (Codex plan #2).
    if (old.animate != widget.animate) _syncClock();
  }

  void _syncClock() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (widget.animate && !reduceMotion) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      if (_clock.isAnimating) _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kCardRadius),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = widget.height;
            final scale = h / RouteDiorama._nativeH;
            final groundH = RouteDiorama._groundNativeH * scale;
            return AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                final reduceMotion = MediaQuery.of(context).disableAnimations;
                final t = _clock.lastElapsedDuration?.inMilliseconds ?? 0;
                final seconds = t / 1000.0;
                final groundShift = seconds * route.scrollSpeed * scale;
                final farShift = groundShift * 0.3;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Sky — static base.
                    _layerImage(
                      route.skyAsset,
                      fit: BoxFit.cover,
                      fallbackTop: kBg,
                      fallbackBottom: route.accent.withValues(alpha: 0.12),
                    ),
                    // Far silhouettes — slow scroll.
                    _ScrollingLayer(
                      asset: route.farAsset,
                      shift: farShift,
                      tileWidth: RouteDiorama._nativeW * scale,
                      height: h,
                      bottom: 0,
                      fallbackTop: Colors.transparent,
                      fallbackBottom: kCard.withValues(alpha: 0.6),
                    ),
                    // Ground strip — full-speed seamless wrap.
                    _ScrollingLayer(
                      asset: route.groundAsset,
                      shift: groundShift,
                      tileWidth: RouteDiorama._nativeW * scale,
                      height: groundH,
                      bottom: 0,
                      fallbackTop: kCard,
                      fallbackBottom: kBg,
                    ),
                    // BIT, hover-gliding near the left of the route with his
                    // body above the walk line (only when this diorama owns the
                    // sprite — selection backdrops hide it). His native y29
                    // contact line anchors on the route's walk line.
                    if (widget.showWalker)
                      Positioned(
                        left: w * 0.08,
                        top: (route.walkLineNative -
                                29 * RouteDiorama._bitDensity) *
                            scale,
                        child: BitRouteWalker(
                          tMs: reduceMotion ? 0 : t.toDouble(),
                          accent: route.accent,
                          speed: (widget.animate && !reduceMotion)
                              ? route.scrollSpeed
                              : 0,
                          scale: scale * RouteDiorama._bitDensity,
                        ),
                      ),
                    // Route particles (embers / motes / rune dust).
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ParticlePainter(
                            seconds: seconds,
                            color: route.accent,
                            seed: route.id.hashCode,
                          ),
                        ),
                      ),
                    ),
                    // Scanline pass — the CRT unifier.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _ScanlinePainter()),
                      ),
                    ),
                    // Dim scrim for locked / inspect states.
                    if (widget.darkened)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: kBg.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    // Decorative frame (border + corner ticks).
                    if (widget.framed)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _FramePainter(route.accent),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _layerImage(
    String asset, {
    required BoxFit fit,
    required Color fallbackTop,
    required Color fallbackBottom,
  }) {
    return Image.asset(
      asset,
      fit: fit,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fallbackTop, fallbackBottom],
          ),
        ),
      ),
    );
  }
}

/// A horizontally-wrapping image band: draws enough copies to cover the
/// width and translates by `shift % tileWidth`, so one seamless tile loops
/// forever.
class _ScrollingLayer extends StatelessWidget {
  const _ScrollingLayer({
    required this.asset,
    required this.shift,
    required this.tileWidth,
    required this.height,
    required this.bottom,
    required this.fallbackTop,
    required this.fallbackBottom,
  });

  final String asset;
  final double shift;
  final double tileWidth;
  final double height;
  final double bottom;
  final Color fallbackTop;
  final Color fallbackBottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      height: height,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (tileWidth <= 0) return const SizedBox.shrink();
            final copies = (constraints.maxWidth / tileWidth).ceil() + 1;
            // Snap to whole pixels so nearest-neighbor art never shimmers.
            final offset = -(shift % tileWidth).roundToDouble();
            return Stack(
              children: [
                for (var i = 0; i < copies; i++)
                  Positioned(
                    left: offset + i * tileWidth,
                    top: 0,
                    width: tileWidth,
                    height: height,
                    child: Image.asset(
                      asset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, _, _) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [fallbackTop, fallbackBottom],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Sparse drifting accent particles — embers, motes, rune dust — in the
/// route's accent color. Deterministic per route seed.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.seconds,
    required this.color,
    required this.seed,
  });

  final double seconds;
  final Color color;
  final int seed;

  static const _count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < _count; i++) {
      final speed = 6 + rng.nextDouble() * 14;
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height * 0.85;
      final phase = rng.nextDouble() * 100;
      final x = (baseX - (seconds * speed)) % size.width;
      final y = baseY + sin((seconds + phase) * 1.4) * 3;
      final alpha = 0.25 + 0.35 * ((sin((seconds + phase) * 2) + 1) / 2);
      paint.color = color.withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromLTWH(
          x < 0 ? x + size.width : x,
          y,
          i % 3 == 0 ? 2 : 1,
          i % 3 == 0 ? 2 : 1,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.seconds != seconds || old.color != color;
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kBg.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var y = 1.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => false;
}

/// A pixel frame: a thin inset border in the route accent plus brighter
/// L-shaped corner ticks — reads as an arcade cabinet bezel and separates the
/// three stacked backdrops.
class _FramePainter extends CustomPainter {
  _FramePainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 0.75;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = false
      ..color = accent.withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(kCardRadius)),
      border,
    );

    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = false
      ..color = accent.withValues(alpha: 0.9);
    const len = 10.0;
    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    // Four corner brackets.
    canvas.drawLine(Offset(l, t + len), Offset(l, t), tick);
    canvas.drawLine(Offset(l, t), Offset(l + len, t), tick);
    canvas.drawLine(Offset(r - len, t), Offset(r, t), tick);
    canvas.drawLine(Offset(r, t), Offset(r, t + len), tick);
    canvas.drawLine(Offset(l, b - len), Offset(l, b), tick);
    canvas.drawLine(Offset(l, b), Offset(l + len, b), tick);
    canvas.drawLine(Offset(r - len, b), Offset(r, b), tick);
    canvas.drawLine(Offset(r, b - len), Offset(r, b), tick);
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.accent != accent;
}
