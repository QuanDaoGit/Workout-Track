import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/tokens.dart';
import '../widgets/pixel_button.dart';
import '../widgets/strobe_flash.dart';

class LogWeightRewardPage extends StatelessWidget {
  const LogWeightRewardPage({
    super.key,
    required this.weightKg,
    this.bonusPotionGranted = false,
  });

  final double weightKg;
  final bool bonusPotionGranted;

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
                'weight: ${weightKg.toStringAsFixed(1)} kg',
                style: GoogleFonts.shareTechMono(color: kText, fontSize: 14),
              ),
              const SizedBox(height: 40),
              // Base potion
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
                          'for 24h',
                          style: GoogleFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (bonusPotionGranted) ...[
                const SizedBox(height: 20),
                StrobeFlash(
                  trigger: true,
                  color: kAmber,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ImageIcon(
                        AssetImage('assets/icons/control/icon_potion.png'),
                        color: kAmber,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '+2x XP BONUS',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                              color: kAmber,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'for 24h',
                            style: GoogleFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
