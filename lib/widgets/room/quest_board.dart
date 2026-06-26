import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/haptic_service.dart';
import '../../theme/tokens.dart';
import '../companion/bit_core_engine.dart' show bitGlow;

/// IRONBIT — QUEST BOARD (code-painted wall terminal).
///
/// A faithful Flutter port of `assets/design_handoff_home_room/quest-board/
/// quest-board.js` — a flush-mounted crate on BIT's wall, painted entirely in
/// code in a **65×72 design space (9:10)** and rendered at any size.
///
/// Design law carried over verbatim from the handoff:
/// • GLANCE, DON'T TRANSACT — no claim button; tapping routes to the Quests
///   page (the claim juice lives there). On the wall: QUESTS · 5-seg weekly bar
///   · one gem pip.
/// • ONE SYSTEM — the bar's cyan **is** the pad's LED ([bitGlow]); the crate
///   FACE uses the room surface tokens (border / surface-2 / card).
/// • SUBORDINATE + CALM — cyan is steady-lit (never a nag, never dark). The ONLY
///   thing that moves is the claimable cue, and only when [ready] ≥ 1: an
///   ambient amber edge-glow + a lit amber gem pip, breathing slowly and low.
///   (Coordinate with the pad's armed-glow so only one accent breathes at once.)
/// • prefers-reduced-motion → fully static (lit gem, static edge-glow if ready).
///
/// The cyan deviates from the handoff's literal `#30bee8` note: the live
/// `BitPad` LED is [bitGlow] (`#17D6CC`), and the handoff's stated intent is to
/// match the pad — so the bar tracks the real pad colour for true coherence.
const double _kQbBaseW = 65;
const double _kQbBaseH = 72;

// Crate face maps exactly to room tokens (the handoff used the app's surface
// tokens): border = kBorder, faceLit emboss = kBorderVariant, face = kSurface2.
// The recessed-screen darks, bolt, cell and amber shades are sprite-art consts
// faithful to the handoff — not brand tokens (mirrors BitPad's local `_m*`).
const Color _qbEmboss = Color(0xFF14142A);
const Color _qbBoltDk = Color(0xFF101024);
const Color _qbScrEdge = Color(0xFF0B0B18);
const Color _qbScr = Color(0xFF0E0E1C);
const Color _qbScrTop = Color(0xFF070712);
const Color _qbBar = Color(0xFF0A0A18);
const Color _qbBarEdge = Color(0xFF070712);
const Color _qbBarInner = Color(0xFF050510);
const Color _qbCellOff = Color(0xFF1A1A30);
const Color _qbCellOffIn = Color(0xFF121226);
const Color _qbCellTop = Color(0xFF23233F);
const Color _qbCyHi = Color(0xFF5EE8DD); // the room's bright turquoise glint
const Color _qbAmber = Color(0xFFF5C43C); // calmer than kAmber — never out-shouts BIT
const Color _qbAmberHi = Color(0xFFFFE27A);
const Color _qbScan = Color(0x0996AAFF); // rgba(150,170,255,0.035) static scanline

/// The painted board. [glow] is the breathe value `g ∈ [0,1]` (driven by the
/// host widget); only consulted when [ready] > 0.
class QuestBoardPainter extends CustomPainter {
  QuestBoardPainter({
    required this.total,
    required this.filled,
    required this.ready,
    required this.glow,
  });

  final int total;
  final int filled;
  final int ready;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    const w = _kQbBaseW, h = _kQbBaseH;
    final s = size.width / w;
    canvas.save();
    canvas.scale(s);

    final p = Paint()..isAntiAlias = false;
    void rc(double x, double y, double rw, double rh, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, rw, rh), p);
    }

    // Chamfered (cut-corner) rect: a horizontal slab inset by k + a vertical
    // slab inset by k — their union notches the four corners by k×k.
    void cham(double x, double y, double rw, double rh, Color c, double k) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x + k, y, rw - 2 * k, rh), p);
      canvas.drawRect(Rect.fromLTWH(x, y + k, rw, rh - 2 * k), p);
    }

    void glowRect(double x, double y, double rw, double rh, Color c, double a, double sigma) {
      canvas.drawRect(
        Rect.fromLTWH(x, y, rw, rh),
        Paint()
          ..isAntiAlias = true
          ..color = c.withValues(alpha: a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }

    final claim = ready > 0;
    final g = glow;

    // thin flush bezel → a slightly larger screen, same 65×72 board
    const sx = 3.0, sy = 3.0;
    const sw = w - 6, sh = h - 6;

    // ── crate FACE (room card / emboss surface), thin flush bezel ──
    cham(0, 0, w, h, kBorder, 3);
    cham(1, 1, w - 2, h - 2, kBorderVariant, 2); // emboss highlight (top-left)
    cham(1, 2, w - 2, h - 4, kSurface2, 2); // surface-2 face (leaves 1px lit top)
    rc(2, h - 3, w - 4, 1, _qbEmboss); // thin bottom emboss shade

    // ── recessed screen ──
    cham(sx, sy, sw, sh, _qbScrEdge, 3);
    cham(sx + 1, sy + 1, sw - 2, sh - 2, _qbScr, 3);
    rc(sx + 3, sy + 1, sw - 6, 1, _qbScrTop);
    p.color = _qbScan; // static dim scanlines (powered, calm)
    for (var yy = sy + 3; yy < sy + sh - 1; yy += 3) {
      canvas.drawRect(Rect.fromLTWH(sx + 2, yy, sw - 4, 1), p);
    }

    // ── centred content: QUESTS · bar · gem pip ──
    const cx = w / 2;
    const titleH = 8.0, g1 = 6.0, barH = 12.0, g2 = 7.0, pipH = 7.0;
    const blockH = titleH + g1 + barH + g2 + pipH;
    const top = sy + (sh - blockH) / 2;

    final tp = TextPainter(
      text: TextSpan(
        text: 'QUESTS',
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 6,
          height: 1.0,
          color: kText,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, top + titleH - tp.height));

    // progress bar
    final by = top + titleH + g1;
    const bx = sx + 6, bw = sw - 12, bh = 12.0;
    cham(bx, by, bw, bh, _qbBarEdge, 3);
    cham(bx + 1, by + 1, bw - 2, bh - 2, _qbBar, 3);
    rc(bx + 3, by + 1, bw - 6, 1, _qbBarInner);
    const ix = bx + 3, iw = bw - 6, ih = 6.0, gap = 1.2;
    final iy = by + 3;
    final cw = (iw - (total - 1) * gap) / total;
    for (var i = 0; i < total; i++) {
      final cxp = ix + i * (cw + gap);
      if (i < filled) {
        glowRect(cxp, iy, cw, ih, bitGlow, 0.2, 1.25); // steady cyan bloom — no pulse
        rc(cxp, iy, cw, ih, bitGlow.withValues(alpha: 0.30)); // dim teal body
        rc(cxp, iy, cw, 1, bitGlow); // lit top edge
        rc(cxp, iy, math.max(1, cw * 0.4), 1, _qbCyHi); // glint
      } else {
        rc(cxp, iy, cw, ih, _qbCellOff);
        rc(cxp, iy + 1, cw, ih - 1, _qbCellOffIn);
        rc(cxp, iy, cw, 1, _qbCellTop);
      }
    }

    // the single status token — a gem pip. amber + breathe when claimable,
    // else calm steady cyan. never dark.
    final pipCx = cx;
    final pipCy = top + titleH + g1 + barH + g2 + pipH / 2;
    const r = 3.2;
    final diamond = Path()
      ..moveTo(pipCx, pipCy - r)
      ..lineTo(pipCx + r, pipCy)
      ..lineTo(pipCx, pipCy + r)
      ..lineTo(pipCx - r, pipCy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..isAntiAlias = true
        ..color = (claim ? _qbAmber : bitGlow)
            .withValues(alpha: claim ? (0.42 + 0.36 * g) : 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, claim ? (5 + 3 * g) / 2 : 1.25),
    );
    canvas.drawPath(
      diamond,
      Paint()
        ..isAntiAlias = true
        ..color = claim ? _qbAmber : bitGlow,
    );
    final glint = Path()
      ..moveTo(pipCx, pipCy - r)
      ..lineTo(pipCx - r * 0.62, pipCy - r * 0.18)
      ..lineTo(pipCx, pipCy - r * 0.2)
      ..close();
    canvas.drawPath(
      glint,
      Paint()
        ..isAntiAlias = true
        ..color = claim ? _qbAmberHi : _qbCyHi,
    );

    // ── claimable cue: ambient amber edge-glow — faithful to the handoff's
    // `edgeGlow`: faint crisp strokes that each cast a STRONG amber bloom
    // (`glowOn(amA(0.6·g), 8)` → a blurred amber stroke at alpha 0.6·g,
    // sigma ≈ 4), doubled across the two inset rects. ──
    if (claim) {
      void edge(double inset, double crispAlpha) {
        final r = Rect.fromLTWH(sx + inset, sy + inset, sw - 2 * inset, sh - 2 * inset);
        canvas.drawRect(
          r,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = _qbAmber.withValues(alpha: 0.6 * g)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawRect(
          r,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = _qbAmber.withValues(alpha: crispAlpha),
        );
      }

      edge(3, 0.09 + 0.14 * g);
      edge(5, 0.05 + 0.09 * g);
    }

    // ── flush-mount bolts (the only chrome) ──
    void bolt(double x, double y) {
      const sz = 6.0;
      cham(x, y, sz, sz, _qbBoltDk, 2);
      cham(x + 1, y + 1, sz - 2, sz - 2, kBorderVariant, 2);
      cham(x + 1, y + 2, sz - 2, sz - 3, kSurface2, 2);
      rc(x + 2, y + 2, 3, 3, _qbEmboss);
      rc(x + 2, y + 2, 3, 1, _qbBoltDk);
      rc(x + 2, y + 2, 1, 3, _qbBoltDk);
      rc(x + 4, y + 3, 1, 2, kBorderVariant);
    }

    bolt(0, 0);
    bolt(w - 6, 0);
    bolt(0, h - 6);
    bolt(w - 6, h - 6);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant QuestBoardPainter old) =>
      old.total != total || old.filled != filled || old.ready != ready || old.glow != glow;
}

/// The wall fixture: a [QuestBoardPainter] at [width]×[height] (keep 9:10), with
/// a slow amber breathe that runs **only when [ready] > 0 and motion is on**
/// (idle is genuinely static — nothing on the wall nags). Reduced motion → a
/// still frame (lit gem + static edge-glow if ready). [onTap] routes to Quests.
class QuestBoard extends StatefulWidget {
  const QuestBoard({
    super.key,
    required this.width,
    required this.height,
    required this.total,
    required this.filled,
    required this.ready,
    this.onTap,
    this.semanticsLabel,
  });

  final double width;
  final double height;
  final int total;
  final int filled;
  final int ready;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  State<QuestBoard> createState() => _QuestBoardState();
}

class _QuestBoardState extends State<QuestBoard> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool _reduce = false;
  double _g = 0.6; // static claim level when not animating

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(QuestBoard old) {
    super.didUpdateWidget(old);
    if (old.ready != widget.ready) _sync();
  }

  // Only loop when there is actually something to animate (claimable + motion).
  void _sync() {
    final shouldAnim = !_reduce && widget.ready > 0;
    if (shouldAnim) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
      final next = widget.ready > 0 ? 0.6 : 0.0;
      if (_g != next) setState(() => _g = next);
    }
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    setState(() => _g = 0.5 + 0.5 * math.sin(t * 2.25));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _label() {
    if (widget.ready <= 0) return 'Quest board. Opens quests.';
    final noun = widget.ready == 1 ? 'reward' : 'rewards';
    return 'Quest board. ${widget.ready} $noun ready to claim. Opens quests.';
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.ready > 0;
    final label = widget.semanticsLabel ?? _label();
    final Widget content = CustomPaint(
      size: Size(widget.width, widget.height),
      painter: QuestBoardPainter(
        total: widget.total,
        filled: widget.filled,
        ready: widget.ready,
        glow: claim ? _g : 0.0,
      ),
    );
    final Widget board = widget.onTap != null
        ? Semantics(
            button: true,
            label: label,
            child: GestureDetector(
              onTap: () {
                HapticService.instance.selection(); // glance at the board
                widget.onTap!();
              },
              behavior: HitTestBehavior.opaque,
              child: ExcludeSemantics(child: content),
            ),
          )
        : Semantics(label: label, child: ExcludeSemantics(child: content));
    return SizedBox(width: widget.width, height: widget.height, child: board);
  }
}
