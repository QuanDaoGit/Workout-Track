import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';

/// BIT types at a single, consistent speed everywhere — a robot, so a *constant*
/// interval reads mechanical. ~22 ms/char ≈ 45 cps: fast + readable.
const int kBitTypeCharMs = 22;

/// Width of the subtle bracket jitter, in px. Tiny so the phrase stays readable.
const double _kShakeAmp = 0.8;

final _bracket = RegExp(r'\[([^\]]+)\]');

String _stripBrackets(String text) =>
    text.replaceAllMapped(_bracket, (m) => m.group(1)!);

/// Which way the bubble's little tail points — i.e. where BIT sits relative to
/// the bubble. [left] (default) = BIT on the left (the onboarding chat layout);
/// [right] = BIT on the right; [none] = a tail-less caption; [down] = BIT BELOW
/// the bubble — the in-world balloon-above-the-speaker convention (the bubble is
/// a Column with the tail under the box, pointing down at the character).
enum BitTailDirection { left, right, none, down }

/// An arcade-styled speech callout for BIT. The painted tail points at BIT
/// ([tailDirection], default [BitTailDirection.left]).
///
/// **Typewriter** ([typewriter] true): BIT *types* [text] out at [kBitTypeCharMs]
/// (the old line is cleared, the new types in) — robotic and on-character. The
/// `[bracketed]` emphasis blooms amber + a subtle shake **when the line finishes
/// typing**. [skip] flipping true completes the line instantly (tap-to-skip);
/// [onTypingComplete] fires when the line is fully shown. Re-types whenever [text]
/// changes. Reduced motion / screen-reader → the full line shows instantly, and
/// the **whole line is always exposed to Semantics** (never the half-typed text).
///
/// **Static** ([typewriter] false, the default — Start Gate, loader): shows the
/// full rich line immediately, [emphasis] (a single substring, e.g. a name) tinted
/// cyan inline.
class BitSpeechBubble extends StatefulWidget {
  const BitSpeechBubble({
    super.key,
    required this.text,
    this.emphasis,
    this.emphasisColor,
    this.typewriter = false,
    this.charMs = kBitTypeCharMs,
    this.skip = false,
    this.onTypingComplete,
    this.tailDirection = BitTailDirection.left,
    this.downTailDx = 0,
    this.downApexFrac = 0.5,
    this.fontSize = 14,
    this.child,
    this.semanticsLabel,
  });

  final String text;
  final String? emphasis;

  /// Tint for the legacy single-substring [emphasis]. Defaults to [kCyan] when
  /// null, so existing callers are byte-identical; pass e.g. [kGemMagenta] for
  /// a haul/gem word.
  final Color? emphasisColor;
  final bool typewriter;
  final int charMs;

  /// When non-null, the bubble hosts this rich [child] **instead** of the typed
  /// [text] (the typewriter is skipped) — e.g. the relocated expedition status
  /// readout. [semanticsLabel] then provides the screen-reader line.
  final Widget? child;

  /// Overrides the Semantics label (required when using [child], where there is
  /// no plain [text] to read). Null ⇒ the plain [text].
  final String? semanticsLabel;

  /// Type size for the line (default 14, matching onboarding/quest). The room
  /// passes a smaller, kx-scaled size so the bubble sits in the diorama's text
  /// density instead of dominating it.
  final double fontSize;

  /// Which side the tail points (where BIT sits). Default [BitTailDirection.left].
  final BitTailDirection tailDirection;

  /// For [BitTailDirection.down] only: shift the tail horizontally off the box's
  /// centre, in px (negative = left). The comic convention is a tail that leaves
  /// the balloon slightly *off-centre* and leans back toward the speaker, rather
  /// than a symmetric nub dead-centre. Default 0 (centred, byte-identical).
  final double downTailDx;

  /// For [BitTailDirection.down] only: where the tail's apex sits across its own
  /// width, 0..1 (0.5 = symmetric). >0.5 leans the point toward the box's right,
  /// so a left-shifted tail still aims back at a centred speaker. Default 0.5.
  final double downApexFrac;

  /// Flip true to complete the type instantly (a tap during typing).
  final bool skip;

  /// Fired (post-frame) when the line is fully shown — naturally or via [skip].
  final VoidCallback? onTypingComplete;

  @override
  State<BitSpeechBubble> createState() => _BitSpeechBubbleState();
}

class _BitSpeechBubbleState extends State<BitSpeechBubble> {
  Timer? _typeTimer;
  String _plain = '';
  int _shown = 0;
  bool _done = false;
  bool _reduce = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final reduce = media.disableAnimations || media.accessibleNavigation;
    final wasReduce = _reduce;
    _reduce = reduce;
    if (_started) {
      // Reduced motion / screen-reader turned ON mid-type → snap to the full line
      // now (don't keep revealing a character at a time). Build-phase, so the
      // owner notify must wait a frame.
      if (reduce && !wasReduce && !_done) {
        _typeTimer?.cancel();
        _typeTimer = null;
        _done = true;
        _shown = _plain.length;
        _notifyTyped(defer: true);
      }
      return;
    }
    _started = true;
    _plain = _stripBrackets(widget.text);
    if (widget.child != null || !widget.typewriter || _reduce) {
      // Set directly (pre-first-build) so there's no empty flash.
      _done = true;
      _shown = _plain.length;
      _notifyTyped(defer: true);
    } else {
      _typeTimer = Timer.periodic(Duration(milliseconds: widget.charMs), _tick);
    }
  }

  @override
  void didUpdateWidget(BitSpeechBubble old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text) {
      _plain = _stripBrackets(widget.text);
      _restart();
    } else if (widget.skip && !old.skip && !_done) {
      _complete(defer: true); // inside the parent's rebuild
    }
  }

  void _restart() {
    _typeTimer?.cancel();
    if (!widget.typewriter || _reduce) {
      setState(() {
        _done = true;
        _shown = _plain.length;
      });
      _notifyTyped(defer: true);
    } else {
      setState(() {
        _done = false;
        _shown = 0;
      });
      _typeTimer = Timer.periodic(Duration(milliseconds: widget.charMs), _tick);
    }
  }

  void _tick(Timer t) {
    setState(() => _shown++);
    // Natural completion runs in a timer callback (not during build), so the
    // owner is notified SYNCHRONOUSLY — its "typed" flag flips in the same frame
    // the last char lands. A tap-to-continue the instant typing ends is then
    // never mis-read as a skip (no one-frame dead window).
    if (_shown >= _plain.length) _complete();
  }

  void _complete({bool defer = false}) {
    _typeTimer?.cancel();
    _typeTimer = null;
    if (_done) return;
    setState(() {
      _done = true;
      _shown = _plain.length;
    });
    _notifyTyped(defer: defer);
  }

  void _notifyTyped({bool defer = false}) {
    final cb = widget.onTypingComplete;
    if (cb == null) return;
    if (defer) {
      // Build-phase callers (didChangeDependencies / didUpdateWidget) can't call
      // synchronously back into the owner's setState — wait one frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) cb();
      });
    } else {
      cb();
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      // The whole line is always the Semantics label (never the half-typed
      // partial), so screen readers read it correctly; the visual is excluded.
      child: Semantics(
        label: widget.semanticsLabel ?? _plain,
        child: ExcludeSemantics(child: widget.child ?? _visual()),
      ),
    );
    final bubble = Flexible(child: bubbleBox);
    return switch (widget.tailDirection) {
      // In-world balloon ABOVE the speaker: a Column with the tail under the box.
      BitTailDirection.down => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            bubbleBox,
            // Transform (not layout) so the centred Column still wraps the box;
            // the tail just slides off-centre and the apex leans back at BIT.
            Transform.translate(
              offset: Offset(widget.downTailDx, 0),
              child: _downTail(),
            ),
          ],
        ),
      BitTailDirection.left => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [_tail(pointLeft: true), bubble],
        ),
      BitTailDirection.right => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [bubble, _tail(pointLeft: false)],
        ),
      BitTailDirection.none => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [bubble],
        ),
    };
  }

  Widget _tail({required bool pointLeft}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CustomPaint(
          size: const Size(7, 12),
          painter: _TailPainter(pointLeft: pointLeft),
        ),
      );

  /// The downward tail under the box (BIT below) — wider than tall, apex below so
  /// it points down at the character. [downApexFrac] biases the apex across the
  /// width (0.5 = straight down; >0.5 leans the point toward BIT when the tail is
  /// shifted off-centre).
  Widget _downTail() => CustomPaint(
        size: const Size(12, 7),
        painter: _TailPainter(down: true, downApexFrac: widget.downApexFrac),
      );

  TextStyle get _base =>
      AppFonts.shareTechMono(color: kText, fontSize: widget.fontSize, height: 1.4);

  Widget _visual() {
    if (!_done) {
      return Text(_plain.substring(0, _shown.clamp(0, _plain.length)),
          style: _base);
    }
    return _rich();
  }

  // The fully-typed line: `[bracketed]` runs become amber + shake; or the legacy
  // single-substring cyan emphasis; or plain text.
  Widget _rich() {
    if (_bracket.hasMatch(widget.text)) {
      final spans = <InlineSpan>[];
      var last = 0;
      for (final m in _bracket.allMatches(widget.text)) {
        if (m.start > last) {
          spans.add(TextSpan(text: widget.text.substring(last, m.start)));
        }
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _ShakyEmphasis(text: m.group(1)!, fontSize: widget.fontSize),
          ),
        );
        last = m.end;
      }
      if (last < widget.text.length) {
        spans.add(TextSpan(text: widget.text.substring(last)));
      }
      return Text.rich(TextSpan(style: _base, children: spans));
    }

    final emph = widget.emphasis;
    final idx = (emph == null || emph.isEmpty) ? -1 : widget.text.indexOf(emph);
    if (idx < 0) return Text(widget.text, style: _base);
    return Text.rich(
      TextSpan(
        style: _base,
        children: [
          TextSpan(text: widget.text.substring(0, idx)),
          TextSpan(
            text: emph,
            style: AppFonts.shareTechMono(
              color: widget.emphasisColor ?? kCyan,
              fontSize: widget.fontSize,
              height: 1.4,
            ),
          ),
          TextSpan(text: widget.text.substring(idx + emph!.length)),
        ],
      ),
    );
  }
}

/// An amber phrase that jitters by ~1 px on decoupled sines — a subtle "alive"
/// emphasis. Static (just amber) under reduced motion.
class _ShakyEmphasis extends StatefulWidget {
  const _ShakyEmphasis({required this.text, this.fontSize = 14});

  final String text;
  final double fontSize;

  @override
  State<_ShakyEmphasis> createState() => _ShakyEmphasisState();
}

class _ShakyEmphasisState extends State<_ShakyEmphasis>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final ValueNotifier<double> _t = ValueNotifier<double>(0);
  bool _reduce = false;
  late final double _phase =
      (widget.text.hashCode % 1000) / 1000 * math.pi * 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _ticker?.stop();
      _t.value = 0;
    } else {
      _ticker ??= createTicker((d) => _t.value = d.inMicroseconds / 1e6);
      if (!_ticker!.isActive) _ticker!.start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.shareTechMono(color: kAmber, fontSize: widget.fontSize, height: 1.4);
    final label = Text(widget.text, style: style);
    if (_reduce) return label;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final t = _t.value * 9 + _phase; // ~1.4 Hz, gentle
        final dx = _kShakeAmp * math.sin(t);
        final dy = _kShakeAmp * math.sin(t * 1.3 + 0.7); // slightly decoupled
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: label,
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({
    this.pointLeft = true,
    this.down = false,
    this.downApexFrac = 0.5,
  });

  /// Apex points left (BIT on the left) when true; right when false.
  final bool pointLeft;

  /// Apex points DOWN (BIT below) — the box's bottom edge is the base.
  final bool down;

  /// Where the down-apex sits across the width (0.5 = centred, >0.5 leans right).
  final double downApexFrac;

  @override
  void paint(Canvas canvas, Size size) {
    final baseX = pointLeft ? size.width : 0.0;
    final apexX = pointLeft ? 0.0 : size.width;
    Path tail() => down
        ? (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width * downApexFrac, size.height)
          ..lineTo(size.width, 0))
        : (Path()
          ..moveTo(baseX, 0)
          ..lineTo(apexX, size.height / 2)
          ..lineTo(baseX, size.height));
    canvas.drawPath(tail()..close(), Paint()..color = kCard);
    canvas.drawPath(
      tail(),
      Paint()
        ..color = kBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.pointLeft != pointLeft ||
      oldDelegate.down != down ||
      oldDelegate.downApexFrac != downApexFrac;
}
