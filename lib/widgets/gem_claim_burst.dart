import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A localized pixel "gem shard" burst — the Flutter analog of the mockup's
/// `fireBurst()`. On each [trigger] bump it sprays small amber/cyan pixel
/// squares radially outward from its center with a little gravity + spin, then
/// fades. Pixel-perfect (no anti-aliasing) to match the CRT/arcade identity.
///
/// Drop it as an overlay (e.g. `Positioned.fill`) above the thing being claimed.
/// It paints nothing while idle and is fully inert under reduced motion.
class GemClaimBurst extends StatefulWidget {
  const GemClaimBurst({super.key, required this.trigger, this.shardCount = 12});

  static const shardColors = <Color>[kAmber, kAmberDark];

  /// Increment to fire a burst.
  final int trigger;
  final int shardCount;

  @override
  State<GemClaimBurst> createState() => _GemClaimBurstState();
}

class _GemClaimBurstState extends State<GemClaimBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_Shard> _shards = const [];

  @override
  void initState() {
    super.initState();
    // Build the controller in initState (not lazily): under reduced motion the
    // build/didUpdate paths never touch it, so a `late final` initializer would
    // otherwise fire during dispose() and do an unsafe ancestor lookup.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
  }

  @override
  void didUpdateWidget(covariant GemClaimBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      if (MediaQuery.of(context).disableAnimations) return;
      _shards = _spawn(widget.trigger, widget.shardCount);
      _controller.forward(from: 0);
    }
  }

  List<_Shard> _spawn(int seed, int count) {
    // Seeded so a given burst is deterministic (testable) but each varies.
    final rand = math.Random(seed);
    return [
      for (var i = 0; i < count; i++)
        _Shard(
          angle: (i / count) * 2 * math.pi + (rand.nextDouble() - 0.5) * 0.6,
          speed: 24 + rand.nextDouble() * 28,
          size: 3 + rand.nextDouble() * 2,
          color:
              GemClaimBurst.shardColors[i % GemClaimBurst.shardColors.length],
          spin: rand.nextDouble() * 2 - 1,
        ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          if (v <= 0 || v >= 1 || _shards.isEmpty) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _BurstPainter(_shards, v),
          );
        },
      ),
    );
  }
}

class _Shard {
  const _Shard({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
  });

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final Color color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.shards, this.t);

  final List<_Shard> shards;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOut.transform(t);
    final gravity = 20.0 * t * t;
    final alpha = (1 - t).clamp(0.0, 1.0);
    for (final shard in shards) {
      final dx = math.cos(shard.angle) * shard.speed * eased;
      final dy = math.sin(shard.angle) * shard.speed * eased + gravity;
      final side = shard.size * (1 - 0.4 * t);
      final paint = Paint()
        ..color = shard.color.withValues(alpha: alpha)
        ..isAntiAlias = false;
      canvas
        ..save()
        ..translate(center.dx + dx, center.dy + dy)
        ..rotate(shard.spin * t * 3)
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => oldDelegate.t != t;
}
