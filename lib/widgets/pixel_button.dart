import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pixel_loader.dart';

class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final bool fullWidth;
  final double minHeight;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color,
    this.fullWidth = true,
    this.minHeight = kButtonHeight,
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
    final fill = widget.color ?? kNeon;
    const disabledFill = kBorderDark;
    const disabledFg = kDim;
    const fg = kBg;
    final shadow = _darken(fill);

    final width = widget.fullWidth ? double.infinity : null;
    final borderBottom = _enabled
        ? (_pressed ? _kBorderPressed : _kBorderRest)
        : 0.0;
    final translateY = (_enabled && _pressed) ? 2.0 : 0.0;

    final content = widget.isLoading
        ? const PixelLoader(size: 16, color: Color(0xFF0D0D1A))
        : Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: _enabled ? fg : disabledFg,
            ),
          );

    final core = Container(
      width: width,
      constraints: BoxConstraints(minHeight: widget.minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _enabled ? fill : disabledFill,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          bottom: BorderSide(
            color: _enabled ? shadow : Colors.transparent,
            width: borderBottom,
          ),
        ),
      ),
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
                      color: const Color(0xFF00FF9C).withValues(alpha: 0.3),
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
