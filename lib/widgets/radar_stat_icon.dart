import 'package:flutter/material.dart';

import '../services/xp_service.dart';

class RadarStatIcons {
  const RadarStatIcons._();

  static const statsBuild = 'assets/icons/radar/stats-build.png';

  static const vitalityEmpty = 'assets/icons/radar/vitality-heart-empty.png';
  static const vitality20 = 'assets/icons/radar/vitality-heart-20.png';
  static const vitality40 = 'assets/icons/radar/vitality-heart-40.png';
  static const vitality60 = 'assets/icons/radar/vitality-heart-60.png';
  static const vitality80 = 'assets/icons/radar/vitality-heart-80.png';
  static const vitalityFull = 'assets/icons/radar/vitality-heart-full.png';

  static const lckNone = 'assets/icons/radar/lck-streak-none.png';
  static const lckActive = 'assets/icons/radar/lck-streak.png';
  static const lckHot = 'assets/icons/radar/lck-streak-hot.png';

  static const all = <String>[
    statsBuild,
    vitalityEmpty,
    vitality20,
    vitality40,
    vitality60,
    vitality80,
    vitalityFull,
    lckNone,
    lckActive,
    lckHot,
  ];

  static String vitalityForValue(int value) {
    if (value >= 100) return vitalityFull;
    if (value >= 80) return vitality80;
    if (value >= 60) return vitality60;
    if (value >= 40) return vitality40;
    if (value >= 20) return vitality20;
    return vitalityEmpty;
  }

  static String lckForValue(int value, {int? filledDiamonds}) {
    // [value] is the LCK weekly-consistency streak; diamonds come from the
    // shared weekly ladder so the icon matches the XP multiplier exactly.
    final filled = filledDiamonds ?? XpService.lckDiamondCount(value);
    if (filled >= 4) return lckHot;
    if (filled > 0) return lckActive;
    return lckNone;
  }
}

class RadarStatIcon extends StatelessWidget {
  const RadarStatIcon({
    super.key,
    required this.assetPath,
    this.size = 18,
    this.semanticLabel,
  });

  final String assetPath;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      semanticLabel: semanticLabel,
    );
  }
}
