import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../models/unit_models.dart';
import '../services/unit_settings_service.dart';
import '../theme/tokens.dart';
import '../widgets/pixel_button.dart';
import '../widgets/strobe_flash.dart';

class LogWeightRewardPage extends StatelessWidget {
  const LogWeightRewardPage({
    super.key,
    required this.weightKg,
    this.rewarded = true,
  });

  final double weightKg;

  /// Whether this check-in earned the weekly XP-boost potion. When false the
  /// page stays calm and affirming — never framed as a missed reward
  /// (body-neutral: absence is just absence).
  final bool rewarded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        canPop: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            48,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              const Spacer(),
              const Text(
                'LOGGED.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 18,
                  color: kNeon,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'weight: ${formatWeight(weightKg, Units.weight)}',
                style: AppFonts.shareTechMono(color: kText, fontSize: 14),
              ),
              const SizedBox(height: 40),
              if (rewarded)
                StrobeFlash(
                  trigger: true,
                  color: kNeon,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ImageIcon(
                        AssetImage('assets/icons/control/icon_potion.png'),
                        color: kNeon,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '+2x XP',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                              color: kNeon,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'next 3 workouts',
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'every check-in sharpens your trend.',
                  textAlign: TextAlign.center,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 12,
                  ),
                ),
              const Spacer(),
              PixelButton(
                label: 'CONTINUE',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
