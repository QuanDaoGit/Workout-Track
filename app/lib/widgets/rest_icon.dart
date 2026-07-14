import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class RestAssets {
  const RestAssets._();

  static const campfire = 'assets/icons/control/icon_campfire.png';
  static const bedroll = 'assets/icons/control/icon_bedroll.png';
  static const recoveryShield = 'assets/icons/control/icon_recovery_shield.png';
  static const activeRecovery = 'assets/icons/control/icon_active_recovery.png';
  static const scene = 'assets/icons/control/rest_day_scene.png';
}

class RestIcon extends StatelessWidget {
  const RestIcon({
    super.key,
    required this.assetPath,
    required this.fallbackAssetPath,
    this.size = 18,
    this.color,
  });

  final String assetPath;
  final String fallbackAssetPath;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      color: color,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) =>
          ImageIcon(AssetImage(fallbackAssetPath), size: size, color: color),
    );
  }
}

class RestScene extends StatelessWidget {
  const RestScene({super.key, this.height = 70});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      RestAssets.scene,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => SizedBox(
        height: height,
        child: const Center(
          child: RestIcon(
            assetPath: RestAssets.campfire,
            fallbackAssetPath: 'assets/icons/control/icon_time.png',
            size: 36,
            color: kAmber,
          ),
        ),
      ),
    );
  }
}
