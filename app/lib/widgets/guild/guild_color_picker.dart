import 'package:flutter/material.dart';

import '../../services/haptic_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../pixel_button.dart';

/// A compact pixel-arcade **HSV colour picker** — an SV square + a hue strip + a
/// hex readout — for the Crest Forge's "any colour" custom option (the handoff's
/// `<input type=color>` free picker). Pops the chosen [Color] on USE, null on
/// cancel. All gradient endpoints are computed from [HSVColor] (the colours ARE
/// the picker's content — no brand tokens involved), so no raw hex chrome.
class CrestColorPickerSheet extends StatefulWidget {
  const CrestColorPickerSheet({
    super.key,
    required this.initial,
    required this.title,
  });

  final Color initial;
  final String title;

  @override
  State<CrestColorPickerSheet> createState() => _CrestColorPickerSheetState();
}

class _CrestColorPickerSheetState extends State<CrestColorPickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  // Drag haptics fire only on a quantized step-crossing (a tactile tick as the
  // value steps), NEVER per pan-update — a continuous per-frame buzz is the
  // forbidden "drone". The service's 30ms coalesce is the rate backstop.
  int? _hueBucket, _satBucket, _valBucket;

  Color get _color => _hsv.toColor();

  void _tick(bool stepped) {
    if (stepped) HapticService.instance.fireCoalesced(HapticIntent.selection);
  }

  void _setSV(Offset local, double side) {
    final s = (local.dx / side).clamp(0.0, 1.0);
    final v = 1 - (local.dy / side).clamp(0.0, 1.0);
    final sb = (s * 16).round(), vb = (v * 16).round();
    _tick(sb != _satBucket || vb != _valBucket);
    _satBucket = sb;
    _valBucket = vb;
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
  }

  void _setHue(double dx, double width) {
    final h = (dx / width).clamp(0.0, 1.0) * 360;
    final hb = (h / 15).round(); // 24 buckets, 15° each
    _tick(hb != _hueBucket);
    _hueBucket = hb;
    setState(() => _hsv = _hsv.withHue(h));
  }

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${(_color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 11,
            ).copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final side = c.maxWidth.clamp(0.0, 280.0);
              return Center(
                child: GestureDetector(
                  onPanDown: (d) => _setSV(d.localPosition, side),
                  onPanUpdate: (d) => _setSV(d.localPosition, side),
                  child: CustomPaint(
                    size: Size(side, side),
                    painter: _SVPainter(_hsv),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return GestureDetector(
                onPanDown: (d) => _setHue(d.localPosition.dx, w),
                onPanUpdate: (d) => _setHue(d.localPosition.dx, w),
                child: CustomPaint(
                  size: Size(w, 22),
                  painter: _HuePainter(_hsv.hue),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _color,
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(kCardRadius),
                ),
              ),
              const SizedBox(width: 10),
              Text(hex, style: AppFonts.shareTechMono(color: kText, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PixelButton(
                  label: 'CANCEL',
                  secondary: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PixelButton(
                  label: 'USE COLOR',
                  onPressed: () => Navigator.of(context).pop(_color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SVPainter extends CustomPainter {
  _SVPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    final white = HSVColor.fromAHSV(1, 0, 0, 1).toColor();
    final black = HSVColor.fromAHSV(1, 0, 0, 0).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(colors: [white, hue]).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [black.withValues(alpha: 0), black],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = kBorder,
    );
    // Square thumb (no round tells) — outlined for contrast on any hue.
    final tx = hsv.saturation * size.width;
    final ty = (1 - hsv.value) * size.height;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(tx, ty), width: 12, height: 12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = kText,
    );
  }

  @override
  bool shouldRepaint(_SVPainter old) => old.hsv != hsv;
}

class _HuePainter extends CustomPainter {
  _HuePainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stops = [
      for (var h = 0; h <= 360; h += 60)
        HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
    ];
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: stops).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = kBorder,
    );
    final tx = (hue / 360) * size.width;
    canvas.drawRect(
      Rect.fromLTWH(tx - 2, -1, 4, size.height + 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = kText,
    );
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}
