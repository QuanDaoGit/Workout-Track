import 'package:flutter/material.dart';

import '../models/avatar_spec.dart';
import '../theme/tokens.dart';
import 'avatar/ironbit_avatar.dart';

/// The standard square identity frame: pixel-face avatar inside a bordered
/// tile, with an optional equipped loot frame drawn over it.
class LootAvatarFrame extends StatelessWidget {
  final AvatarSpec avatarSpec;
  final String? framePath;
  final double size;
  final Color borderColor;
  final Color? glowColor;
  final double glowOpacity;

  const LootAvatarFrame({
    super.key,
    required this.avatarSpec,
    this.framePath,
    required this.size,
    this.borderColor = const Color(0xFF3A3A5C),
    this.glowColor,
    this.glowOpacity = 0.22,
  });

  @override
  Widget build(BuildContext context) {
    final framedAvatar = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            margin: EdgeInsets.all(size * 0.08),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor),
            ),
            // Sprite fills the inner tile minus the frame margin (8% each
            // side), the 1px border, and a small breathing pad.
            child: Center(
              child: IronbitAvatar(spec: avatarSpec, size: size * 0.76),
            ),
          ),
          if (framePath != null && framePath!.isNotEmpty)
            Image.asset(
              framePath!,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
        ],
      ),
    );

    if (glowColor == null) return framedAvatar;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: neonGlow(color: glowColor!, opacity: glowOpacity, blur: 22),
      ),
      child: framedAvatar,
    );
  }
}
