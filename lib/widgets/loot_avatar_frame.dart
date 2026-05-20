import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class LootAvatarFrame extends StatelessWidget {
  final String avatarPath;
  final String? framePath;
  final double size;
  final Color borderColor;

  const LootAvatarFrame({
    super.key,
    required this.avatarPath,
    this.framePath,
    required this.size,
    this.borderColor = const Color(0xFF3A3A5C),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Padding(
                padding: EdgeInsets.all(size * 0.1),
                child: Image.asset(
                  avatarPath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person_sharp, color: kMutedText),
                ),
              ),
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
  }
}
