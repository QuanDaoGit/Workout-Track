import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

// Procedural sprite-art frame palette (hard pixels; same documented status as
// the BIT pad ramp — these are engine shades, not brand tokens).
const Color _barInk = Color(0xFF0A0A12); // recessed shadow edge (top + left)
const Color _barLip = Color(0xFF4B4B6E); // lit bevel edge (bottom + right)
const Color _barWell = Color(0xFF0C0C16); // dark track behind the fill

/// The app's **canonical bar** — a chunky beveled console meter, painted pixel
/// art (`isAntiAlias=false`, hard edges, no blur). An **embossed frame** (dark
/// top-left, light bottom-right) recesses the track; the fill carries volume via
/// a **specular top row**, a base body, and a **shadow base row**.
///
/// - **continuous** — `ArcadeBar(value: 0..1)` for magnitudes (XP, program %,
///   meter). With [flashOnIncrease] (gated by [increaseSignal]) the fill *glides*
///   to a gained value; otherwise it snaps. Reduced motion → snaps.
/// - **count** — `ArcadeBar.segments(litCells:, totalCells:)` for discrete
///   counts (quests, stat tiers): the same beveled fill, split into cells.
class ArcadeBar extends StatefulWidget {
  const ArcadeBar({
    super.key,
    required double this.value,
    this.height = 10,
    this.accent = kNeon,
    this.flashOnIncrease = false,
    this.increaseSignal,
  }) : litCells = null,
       totalCells = null,
       gap = 2;

  const ArcadeBar.segments({
    super.key,
    required int this.litCells,
    required int this.totalCells,
    this.height = 10,
    this.gap = 2,
    this.accent = kNeon,
    this.flashOnIncrease = true,
    this.increaseSignal,
  }) : value = null;

  final double? value;
  final int? litCells;
  final int? totalCells;
  final double height;
  final double gap;
  final Color accent;
  final bool flashOnIncrease;
  final int? increaseSignal;

  bool get isSegments => totalCells != null;

  double get fraction => isSegments
      ? (totalCells == 0 ? 0.0 : litCells! / totalCells!).clamp(0.0, 1.0)
      : (value ?? 0).clamp(0.0, 1.0);

  @override
  State<ArcadeBar> createState() => _ArcadeBarState();
}

class _ArcadeBarState extends State<ArcadeBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  double _from = 0, _to = 0;
  bool _reduce = false;

  double get _displayed =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_ctrl.value);

  @override
  void initState() {
    super.initState();
    _to = _from = widget.fraction;
    _ctrl.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
  }

  @override
  void didUpdateWidget(ArcadeBar old) {
    super.didUpdateWidget(old);
    final f = widget.fraction;
    if (f != _to) {
      final gain =
          widget.increaseSignal != null && old.increaseSignal != null
          ? widget.increaseSignal! > old.increaseSignal!
          : f > _to;
      _from = _displayed;
      _to = f;
      if (!_reduce && widget.flashOnIncrease && gain) {
        _ctrl.forward(from: 0);
      } else {
        _ctrl.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ArcadeBarPainter(
            displayed: _displayed,
            accent: widget.accent,
            segments: widget.isSegments,
            litCells: widget.litCells ?? 0,
            totalCells: widget.totalCells ?? 0,
            gap: widget.gap,
          ),
        ),
      ),
    );
  }
}

class _ArcadeBarPainter extends CustomPainter {
  _ArcadeBarPainter({
    required this.displayed,
    required this.accent,
    required this.segments,
    required this.litCells,
    required this.totalCells,
    required this.gap,
  });

  final double displayed;
  final Color accent;
  final bool segments;
  final int litCells;
  final int totalCells;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()..isAntiAlias = false;

    // Fill ramp from the accent (specular top → base → shadow base).
    final specular = Color.lerp(accent, kText, 0.7)!;
    final shadow = Color.lerp(accent, kBg, 0.5)!;

    // Embossed frame: dark everywhere, a lit lip on the bottom + right edges,
    // then the recessed dark well inside.
    final ft = (h * 0.14).clamp(1.0, 2.0);
    canvas.drawRect(Offset.zero & size, p..color = _barInk);
    canvas.drawRect(Rect.fromLTWH(0, h - ft, w, ft), p..color = _barLip);
    canvas.drawRect(Rect.fromLTWH(w - ft, 0, ft, h), p..color = _barLip);
    final inner = Rect.fromLTWH(ft, ft, w - 2 * ft, h - 2 * ft);
    canvas.drawRect(inner, p..color = _barWell);

    final specH = math.max(1.0, inner.height * 0.26);
    final shadH = math.max(1.0, inner.height * 0.18);
    void slab(double x, double cw) {
      if (cw <= 0) return;
      canvas.drawRect(
        Rect.fromLTWH(x, inner.top, cw, specH),
        p..color = specular,
      );
      canvas.drawRect(
        Rect.fromLTWH(x, inner.top + specH, cw, inner.height - specH - shadH),
        p..color = accent,
      );
      canvas.drawRect(
        Rect.fromLTWH(x, inner.bottom - shadH, cw, shadH),
        p..color = shadow,
      );
    }

    if (segments) {
      if (totalCells > 0) {
        final cw = (inner.width - (totalCells - 1) * gap) / totalCells;
        for (var i = 0; i < totalCells && i < litCells; i++) {
          slab(inner.left + i * (cw + gap), cw);
        }
      }
      return;
    }
    slab(inner.left, inner.width * displayed);
  }

  @override
  bool shouldRepaint(covariant _ArcadeBarPainter old) =>
      old.displayed != displayed ||
      old.accent != accent ||
      old.segments != segments ||
      old.litCells != litCells ||
      old.totalCells != totalCells;
}
