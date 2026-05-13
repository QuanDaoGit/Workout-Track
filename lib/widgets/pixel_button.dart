import 'package:flutter/material.dart';

import 'pixel_loader.dart';

class PixelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final bool fullWidth;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFF00FF9C);
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF2A2A3E);
            }
            return bg;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF555577);
            }
            return const Color(0xFF0D0D1A);
          }),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        child: isLoading
            ? const PixelLoader(size: 16, color: Color(0xFF0D0D1A))
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                ),
              ),
      ),
    );
  }
}
