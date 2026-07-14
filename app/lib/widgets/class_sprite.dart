import 'package:flutter/material.dart';

/// Attempts to load an image asset; on failure renders a class-colored
/// placeholder rectangle with a border and optional label.
class ClassSprite extends StatelessWidget {
  const ClassSprite({
    super.key,
    required this.assetPath,
    required this.placeholderTint,
    this.size = 48,
    this.placeholderLabel,
  });

  final String assetPath;
  final Color placeholderTint;
  final double size;
  final String? placeholderLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: placeholderTint.withValues(alpha: 0.15),
        border: Border.all(color: placeholderTint, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: placeholderLabel != null
          ? Text(
              placeholderLabel!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: size * 0.15,
                color: placeholderTint,
              ),
            )
          : Icon(Icons.shield_sharp, size: size * 0.5, color: placeholderTint),
    );
  }
}
