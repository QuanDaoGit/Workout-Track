import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
    this.powered = true,
    this.lockGlow = 0.30,
    this.press = false,
  });

  final int total;
  final int filled;
  final int ready;
  final double glow;

  /// False = the earned-unlock locked state: the crate hangs on the wall but
  /// its screen is dark — no scanlines, no title/bar/pip, no claim cue. A dim
  /// pixel padlock sits on the dark screen (something is WAITING, not broken),
  /// its brightness driven by [lockGlow].
  final bool powered;

  /// Padlock brightness 0..1 — a slow, low flicker from the host widget
  /// (static ~0.30 under reduced motion). Only consulted when unpowered.
  final double lockGlow;

  /// True while a finger is down (plus a short linger) — the screen answers
  /// with one brightness step. Paint-state feedback only: the fixture never
  /// transforms (the room is one rigid depth plane).
  final bool press;

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

    // ── flush-mount bolts (the only chrome) — shared by both power states ──
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

    void bolts() {
      bolt(0, 0);
      bolt(w - 6, 0);
      bolt(0, h - 6);
      bolt(w - 6, h - 6);
    }

    // ── recessed screen ──
    cham(sx, sy, sw, sh, _qbScrEdge, 3);
    cham(sx + 1, sy + 1, sw - 2, sh - 2, _qbScr, 3);
    rc(sx + 3, sy + 1, sw - 6, 1, _qbScrTop);

    if (!powered) {
      // Dark screen + a dim pixel padlock breathing in low light — the locked
      // board reads "sealed, waiting", never dead. One small slow element
      // (ambient salience: every dial low).
      final a = lockGlow.clamp(0.0, 1.0);
      final lock = bitGlow.withValues(alpha: a);
      // Shackle: a 4-connected 1-unit arch (x 29..37, y 26..33).
      rc(30, 26, 7, 1, lock); // top bar
      rc(29, 27, 1, 6, lock); // left leg
      rc(37, 27, 1, 6, lock); // right leg
      // Body: chamfered 12×10 plate (x 27..39, y 33..43).
      cham(27, 33, 13, 10, lock, 1);
      // Lit top edge — the one luminance accent on the plate.
      rc(28, 33, 11, 1, bitGlow.withValues(alpha: (a + 0.10).clamp(0.0, 1.0)));
      // Keyhole punched back to the screen dark.
      rc(32, 36, 3, 2, _qbScr);
      rc(33, 38, 1, 3, _qbScr);
      if (press) {
        // Even sealed, the crate acknowledges the touch — the padlock blinks
        // one step brighter.
        cham(27, 33, 13, 10,
            bitGlow.withValues(alpha: (a + 0.25).clamp(0.0, 1.0)), 1);
      }
      bolts();
      canvas.restore();
      return;
    }

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

    if (press) {
      // Press-light: the screen answers the finger — one washed brightness
      // step over the recessed screen (a CRT taking the touch), no geometry.
      rc(sx + 1, sy + 1, sw - 2, sh - 2, _qbCyHi.withValues(alpha: 0.10));
    }

    bolts();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant QuestBoardPainter old) =>
      old.total != total ||
      old.filled != filled ||
      old.ready != ready ||
      old.glow != glow ||
      old.powered != powered ||
      old.lockGlow != lockGlow ||
      old.press != press;
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
    this.powered = true,
  });

  final double width;
  final double height;
  final int total;
  final int filled;
  final int ready;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  /// False = the locked/dark screen (see [QuestBoardPainter.powered]).
  final bool powered;

  @override
  State<QuestBoard> createState() => _QuestBoardState();
}

class _QuestBoardState extends State<QuestBoard> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool _reduce = false;
  double _g = 0.6; // static claim level when not animating
  bool _pressed = false;
  Timer? _pressLinger;

  void _setPressed(bool down) {
    _pressLinger?.cancel();
    if (down) {
      if (!_pressed) setState(() => _pressed = true);
      return;
    }
    // Hold the lit step ~90ms past release so an instant tap still reads.
    _pressLinger = Timer(const Duration(milliseconds: 90), () {
      if (mounted && _pressed) setState(() => _pressed = false);
    });
  }

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
    if (old.ready != widget.ready || old.powered != widget.powered) _sync();
  }

  // Only loop when there is something to animate: the claimable amber breathe
  // (powered) or the padlock's low flicker (unpowered) — plus motion enabled.
  void _sync() {
    final shouldAnim =
        !_reduce && (widget.powered ? widget.ready > 0 : true);
    if (shouldAnim) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
      final next = !widget.powered
          ? _kLockStatic
          : (widget.ready > 0 ? 0.6 : 0.0);
      if (_g != next) setState(() => _g = next);
    }
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    setState(() {
      _g = widget.powered
          ? 0.5 + 0.5 * math.sin(t * 2.25)
          : _lockFlicker(t);
    });
  }

  /// Static padlock brightness (reduced motion / ticker off).
  static const double _kLockStatic = 0.30;

  /// The padlock's low-light life: a slow ~7s breathe between 0.20 and 0.32
  /// with a rare brief glint — subtle enough to sit in peripheral vision
  /// without nagging (ambient salience: slow, dim, small, one element).
  double _lockFlicker(double t) {
    final breathe = 0.5 + 0.5 * math.sin(t * 0.9);
    var a = 0.20 + 0.12 * breathe;
    // Two incommensurate sines cross this threshold only for brief moments a
    // few times a minute — the occasional "still alive" glint.
    if (math.sin(t * 5.7) * math.sin(t * 1.31) > 0.985) a += 0.18;
    return a;
  }

  @override
  void dispose() {
    _pressLinger?.cancel();
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
    final claim = widget.ready > 0 && widget.powered;
    final label = widget.semanticsLabel ?? _label();
    final Widget content = CustomPaint(
      size: Size(widget.width, widget.height),
      painter: QuestBoardPainter(
        total: widget.total,
        filled: widget.filled,
        ready: widget.ready,
        glow: claim ? _g : 0.0,
        powered: widget.powered,
        lockGlow: widget.powered ? 0.0 : _g,
        press: _pressed,
      ),
    );
    final Widget board = widget.onTap != null
        ? Semantics(
            button: true,
            label: label,
            child: GestureDetector(
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              // One haptic owner per gesture: the HOST's tap closure fires the
              // coalesced selection (the room already does) — the old internal
              // `HapticService.instance.selection()` double-fired on every
              // board tap and was removed (Codex F6).
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: ExcludeSemantics(child: content),
            ),
          )
        : Semantics(label: label, child: ExcludeSemantics(child: content));
    return SizedBox(width: widget.width, height: widget.height, child: board);
  }
}
