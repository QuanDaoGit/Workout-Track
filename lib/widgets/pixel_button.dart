import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion/power_on.dart';
import 'pixel_loader.dart';

class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final bool fullWidth;
  final double minHeight;
  final double fontSize;
  final Color? disabledColor;
  final Color? disabledLabelColor;
  final Color? disabledBorderColor;
  final bool powerOn;

  /// Secondary style: filled blue-grey (`kBorderVariant`) with a white label,
  /// no glow. Use for dismiss/secondary actions (CLOSE, CANCEL). Neon is
  /// reserved for primary actions.
  final bool secondary;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color,
    this.fullWidth = true,
    this.minHeight = kButtonHeight,
    this.secondary = false,
    this.fontSize = 10,
    this.disabledColor,
    this.disabledLabelColor,
    this.disabledBorderColor,
    this.powerOn = false,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;
  bool _flashing = false;
  Timer? _flashTimer;

  static const _kBorderRest = 3.0;
  static const _kBorderPressed = 1.0;
  static const _kFlashMs = 80;
  static const _kFlashHalo = 5.0;

  static Color _darken(Color c, [double amount = 0.30]) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  // A fill earns a color-matched glow only if it's a bright/identity color —
  // muted/secondary fills (grey) would bloom into invisible mud, so skip them.
  static bool _isGlowableFill(Color c) =>
      c != kBorderDark && c != kDim && c != kMutedText;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _handleTapDown(TapDownDetails _) {
    if (!_enabled) return;
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_enabled) return;
    setState(() {
      _pressed = false;
      _flashing = true;
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: _kFlashMs), () {
      if (!mounted) return;
      setState(() => _flashing = false);
    });
    widget.onPressed!.call();
  }

  void _handleTapCancel() {
    if (!_enabled) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.powerOn) {
      return PowerOn(
        enabled: _enabled,
        builder: (context, power) => _buildButton(context, power),
      );
    }
    return _buildButton(context, _enabled ? 1.0 : 0.0);
  }

  Widget _buildButton(BuildContext context, double power) {
    final secondary = widget.secondary;
    final fill = widget.color ?? (secondary ? kBorderVariant : kNeon);
    final disabledFill = widget.disabledColor ?? kBorderDark;
    final disabledFg = widget.disabledLabelColor ?? kDim;
    // Secondary = white label on blue-grey; primary = dark label on neon.
    final fg = secondary ? kText : kBg;
    final effectiveFill = _enabled && widget.powerOn
        ? Color.lerp(disabledFill, fill, power)!
        : (_enabled ? fill : disabledFill);
    final effectiveFg = _enabled && widget.powerOn
        ? Color.lerp(disabledFg, fg, power)!
        : (_enabled ? fg : disabledFg);
    final shadow = _darken(fill);

    final width = widget.fullWidth ? double.infinity : null;
    final borderBottom = _enabled
        ? (_pressed ? _kBorderPressed : _kBorderRest)
        : 0.0;
    final translateY = (_enabled && _pressed) ? 2.0 : 0.0;

    final content = widget.isLoading
        ? PixelLoader(size: 16, color: effectiveFg)
        : Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: widget.fontSize,
              color: effectiveFg,
            ),
          );

    final decoration = BoxDecoration(
      color: effectiveFill,
      borderRadius: BorderRadius.circular(4),
      // Drop the border entirely when disabled — Flutter asserts on
      // hairline borders (width: 0) combined with non-zero borderRadius.
      border: _enabled
          ? Border(
              bottom: BorderSide(color: shadow, width: borderBottom),
            )
          : widget.disabledBorderColor == null
          ? null
          : Border.all(color: widget.disabledBorderColor!),
      // Neon glow only for bright primary fills — never secondary/muted.
      boxShadow: (_enabled && !secondary && _isGlowableFill(fill))
          ? neonGlow(color: fill)
          : null,
    );

    final core = Container(
      width: width,
      constraints: BoxConstraints(minHeight: widget.minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: decoration,
      alignment: Alignment.center,
      child: content,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (_flashing)
              Positioned(
                left: -_kFlashHalo,
                right: -_kFlashHalo,
                top: -_kFlashHalo,
                bottom: -_kFlashHalo,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: kNeon.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            Transform.translate(offset: Offset(0, translateY), child: core),
          ],
        ),
      ),
    );
  }
}
