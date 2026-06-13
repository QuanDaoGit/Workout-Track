import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/adventure_routes.dart';
import '../../models/avatar_spec.dart';
import '../../models/character_class.dart';
import '../../theme/tokens.dart';
import 'pixel_walker.dart';

/// The expedition diorama: a continuously-scrolling parallax scene built
/// from a route's three still layers (sky static, far at ~30% speed, ground
/// at full speed wrapping seamlessly) with the user's walking character on
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
    required this.avatarSpec,
    this.characterClass,
    this.height = 200,
    this.animate = true,
  });

  final AdventureRouteDef route;
  final AvatarSpec avatarSpec;
  final CharacterClass? characterClass;
  final double height;
  final bool animate;

  // Native art dimensions.
  static const _nativeW = 480.0;
  static const _nativeH = 270.0;
  static const _groundNativeH = 96.0;

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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (widget.animate && !reduceMotion) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
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
                final t = _clock.lastElapsedDuration?.inMilliseconds ?? 0;
                final seconds = t / 1000.0;
                final groundShift = seconds * route.scrollSpeed * scale;
                final farShift = groundShift * 0.3;
                // Walk cycle: ~3 strides/second reads right at this scale.
                final frame = (seconds * 3).floor() % 2;
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
                    // The traveler, planted on the ground line.
                    Positioned(
                      left: w * 0.3,
                      bottom: groundH * 0.72,
                      child: PixelWalker(
                        spec: widget.avatarSpec,
                        characterClass: widget.characterClass,
                        frame: frame,
                        size: 40 * scale.clamp(0.8, 1.6),
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
