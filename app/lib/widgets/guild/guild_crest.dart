import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;

import '../../models/guild_models.dart';

/// Ported from the **Crest Forge** handoff (`Crest Forge.dc.html`). The crest is
/// a **banner layer** + an optional **emblem layer**, each rendered from a shipped
/// pixel-art PNG, **independently recoloured** (tone-preserving — the art's
/// light→dark structure maps onto the chosen hue, low-saturation metal stays
/// neutral), then composited every frame with a **row-by-row cloth sway** pinned
/// at the rod. Recolour is expensive → the two layers are cached and rebuilt only
/// when `shape|emblem|bannerColor|emblemColor|size` changes (handoff `buildLayers`
/// + `_sig`); the sway is a cheap per-row strip blit (handoff `composite`).
///
/// Reduced motion (or [animate]`=false`, e.g. off the Guild tab) → the sway
/// freezes to a still, legible crest (handoff `off = 0`).

/// Banner asset basenames, indexed by `GuildCrest.shape`.
const List<String> kCrestShapeNames = [
  'swallowtail',
  'pennant',
  'draped',
  'notched',
];

/// Emblem asset basenames, indexed by `GuildCrest.emblem`.
const List<String> kCrestEmblemNames = ['sword', 'shield', 'gem', 'bolt'];

/// The art's authored tint (handoff `DEFAULT '#37d2cf'`). Recolour is skipped at
/// this hue so the original teal pixels show through untouched.
const int _kCrestArtTeal = 0xFF37D2CF;

/// Box aspect (W:H) carried from the Forge preview canvas (300×392) so the ported
/// fit geometry (0.90 contain, `by × 0.42`) frames the banner identically.
const double kCrestBoxRatio = 392 / 300;

class GuildCrestBadge extends StatefulWidget {
  const GuildCrestBadge({
    super.key,
    required this.crest,
    required this.fallbackColor,
    this.size = 96,
    this.animate = true,
  });

  final GuildCrest crest;

  /// Resolves an "auto" (0) banner/emblem colour — the player's class theme.
  final Color fallbackColor;

  /// Box **width** in logical px; height follows [kCrestBoxRatio].
  final double size;

  /// Whether the cloth sways. Off-tab callers pass false (still honours reduced
  /// motion, which freezes it regardless).
  final bool animate;

  @override
  State<GuildCrestBadge> createState() => _GuildCrestBadgeState();
}

class _GuildCrestBadgeState extends State<GuildCrestBadge>
    with SingleTickerProviderStateMixin {
  // Raw decoded PNGs, shared across every crest instance (the editor shows many
  // at once) — keyed by basename, decoded once.
  static final Map<String, Future<ui.Image>> _rawCache = {};

  ui.Image? _bannerLayer;
  ui.Image? _emblemLayer;
  double _by = 0, _bh = 0; // banner fit top + height, LOGICAL px (drives sway yn)
  double _dpr = 1;
  String _sig = '';
  int _buildToken = 0;

  late final Ticker _ticker;
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  bool _reduce = false;

  double get _w => widget.size;
  double get _h => widget.size * kCrestBoxRatio;

  @override
  void initState() {
    super.initState();
    // elapsed → ms phase (handoff `t = performance.now()`; absolute origin is
    // irrelevant, the sway is continuous).
    _ticker = createTicker(
      (elapsed) => _phase.value = elapsed.inMicroseconds / 1000.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final m = MediaQuery.of(context);
    _reduce = m.disableAnimations || m.accessibleNavigation;
    _dpr = m.devicePixelRatio;
    _syncTicker();
    _rebuildIfNeeded();
  }

  @override
  void didUpdateWidget(GuildCrestBadge old) {
    super.didUpdateWidget(old);
    _syncTicker();
    _rebuildIfNeeded();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  void _syncTicker() {
    final shouldRun = widget.animate && !_reduce;
    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _phase.value = 0; // static fallback → off = 0
    }
  }

  Color _resolve(int argb) => argb == 0 ? widget.fallbackColor : Color(argb);

  String get _signature {
    final c = widget.crest;
    return [
      c.shape,
      c.emblem,
      _resolve(c.bannerColor).toARGB32(),
      _resolve(c.emblemColor).toARGB32(),
      (_w * _dpr).round(),
      (_h * _dpr).round(),
    ].join('|');
  }

  Future<void> _rebuildIfNeeded() async {
    final sig = _signature;
    if (sig == _sig && _bannerLayer != null) return;
    _sig = sig;
    final token = ++_buildToken;
    final built = await _buildLayers();
    if (!mounted || token != _buildToken || built == null) return;
    setState(() {
      _bannerLayer = built.banner;
      _emblemLayer = built.emblem;
      _by = built.by;
      _bh = built.bh;
    });
  }

  static Future<ui.Image> _raw(String key) {
    return _rawCache.putIfAbsent(key, () async {
      final data = await rootBundle.load('assets/guild/crest/$key.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    });
  }

  Future<({ui.Image banner, ui.Image? emblem, double by, double bh})?>
  _buildLayers() async {
    final c = widget.crest;
    // Logical box + its physical-pixel size (crisp on hi-dpi).
    final w = _w, h = _h;
    final pw = (w * _dpr).round(), ph = (h * _dpr).round();
    if (pw <= 0 || ph <= 0) return null;

    final banner = await _raw('blank_${kCrestShapeNames[c.shape.clamp(0, 3)]}');
    // Fit-by-height into the box, contain with margin, biased up so tail tips
    // never clip (handoff buildLayers).
    final bScale =
        math.min(w / banner.width, h / banner.height) * 0.90;
    final bw = banner.width * bScale, bh = banner.height * bScale;
    final bx = (w - bw) / 2, by = (h - bh) * 0.42;

    final bannerLayer = await _composeLayer(
      src: banner,
      dst: Rect.fromLTWH(bx, by, bw, bh),
      pw: pw,
      ph: ph,
      color: _resolve(c.bannerColor),
    );

    ui.Image? emblemLayer;
    if (c.emblem != GuildCrest.noEmblem) {
      final em = await _raw('icon_${kCrestEmblemNames[c.emblem.clamp(0, 3)]}');
      final th = bh * 0.30, es = th / em.height;
      final ew = em.width * es, eh = em.height * es;
      emblemLayer = await _composeLayer(
        src: em,
        dst: Rect.fromLTWH(w / 2 - ew / 2, by + bh * 0.50 - eh / 2, ew, eh),
        pw: pw,
        ph: ph,
        color: _resolve(c.emblemColor),
      );
    }
    return (banner: bannerLayer, emblem: emblemLayer, by: by, bh: bh);
  }

  /// Renders [src] into a `pw×ph` physical-pixel layer at the logical [dst]
  /// (smooth), then applies the tone-preserving recolour (skipped at the authored
  /// teal). Matches the handoff: draw the layer smooth at build time, blit crisp
  /// at composite time.
  Future<ui.Image> _composeLayer({
    required ui.Image src,
    required Rect dst,
    required int pw,
    required int ph,
    required Color color,
  }) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(_dpr); // draw at logical coords into the physical layer
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );
    final rendered = await rec.endRecording().toImage(pw, ph);
    if (color.toARGB32() == _kCrestArtTeal) return rendered;

    final bytes = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (bytes == null) return rendered;
    final d = bytes.buffer.asUint8List();
    _recolor(d, color);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      d,
      pw,
      ph,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Tone-preserving, saturation-aware recolour (handoff `recolor` + `rampAt`):
  /// each lit pixel's luminance picks a point on a dark→base→near-white ramp of
  /// the target hue; low-saturation pixels (the metal rod) stay neutral.
  void _recolor(Uint8List d, Color target) {
    final argb = target.toARGB32();
    final tr = (argb >> 16) & 0xFF, tg = (argb >> 8) & 0xFF, tb = argb & 0xFF;
    double ramp(int t, double y) {
      if (y < 0.5) {
        final f = y / 0.5, lo = t * 0.20;
        return lo + (t - lo) * f;
      }
      final f = (y - 0.5) / 0.5;
      return t + (255 - t) * (f * 0.82);
    }

    for (var i = 0; i < d.length; i += 4) {
      if (d[i + 3] == 0) continue;
      final r = d[i], g = d[i + 1], b = d[i + 2];
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      final s = mx == 0 ? 0.0 : (mx - mn) / mx;
      final y = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      final amt = ((s - 0.18) * 1.7).clamp(0.0, 1.0);
      d[i] = (r + (ramp(tr, y) - r) * amt).round().clamp(0, 255);
      d[i + 1] = (g + (ramp(tg, y) - g) * amt).round().clamp(0, 255);
      d[i + 2] = (b + (ramp(tb, y) - b) * amt).round().clamp(0, 255);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerLayer;
    return SizedBox(
      width: _w,
      height: _h,
      child: banner == null
          ? null
          : CustomPaint(
              size: Size(_w, _h),
              painter: _CrestPainter(
                banner: banner,
                emblem: _emblemLayer,
                by: _by,
                bh: _bh,
                dpr: _dpr,
                phase: _phase,
                reduce: _reduce || !widget.animate,
              ),
            ),
    );
  }
}

class _CrestPainter extends CustomPainter {
  _CrestPainter({
    required this.banner,
    required this.emblem,
    required this.by,
    required this.bh,
    required this.dpr,
    required this.phase,
    required this.reduce,
  }) : super(repaint: phase);

  final ui.Image banner;
  final ui.Image? emblem;
  final double by, bh, dpr;
  final ValueListenable<double> phase;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = reduce ? 0.0 : phase.value;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    const band = 2.0, amp = 2.6;
    // Blit cached layers in 2px logical strips, each shifted by the sway offset
    // for its row (handoff composite). Layers are physical-res; src rows scale
    // by dpr, the sway math stays in logical px so A=2.6 reads identically.
    for (double y = 0; y < h; y += band) {
      final yn = ((y - by) / bh).clamp(0.0, 1.0);
      final off = reduce
          ? 0.0
          : (amp * yn * math.sin(t * 0.0019 - yn * 3.0) +
                    0.9 * yn * math.sin(t * 0.0011 + 1.3))
                .roundToDouble();
      final src = Rect.fromLTWH(0, y * dpr, w * dpr, band * dpr);
      final dst = Rect.fromLTWH(off, y, w, band);
      canvas.drawImageRect(banner, src, dst, paint);
      final em = emblem;
      if (em != null) canvas.drawImageRect(em, src, dst, paint);
    }
  }

  @override
  bool shouldRepaint(_CrestPainter old) =>
      old.banner != banner ||
      old.emblem != emblem ||
      old.by != by ||
      old.bh != bh ||
      old.reduce != reduce;
}
