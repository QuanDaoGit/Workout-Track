import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../arcade_badge.dart';
import '../arcade_bar.dart';
import '../arcade_card.dart';
import '../chest_open_animation.dart';

/// The Weekly Cache — a cooperative active-days goal that **auto-banks** a gem
/// reward the instant it completes (no manual claim, no expiry penalty; resting
/// is safe by design). A supporting card (recedes under the hall/crest hero):
/// one amber **reward** accent on the bar + the magenta **gem** chip; no other
/// bright colour. The chest opens once on the banking moment ([justBanked]).
class WeeklyCacheCard extends StatelessWidget {
  const WeeklyCacheCard({
    super.key,
    required this.activeDays,
    required this.target,
    required this.banked,
    required this.reward,
    this.justBanked = false,
  });

  final int activeDays;
  final int target;
  final bool banked;
  final int reward;
  final bool justBanked;

  @override
  Widget build(BuildContext context) {
    return ArcadeCard(
      key: const ValueKey('guild_weekly_cache'),
      borderAlpha: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'WEEKLY CACHE',
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 11,
                ).copyWith(letterSpacing: 1),
              ),
              const Spacer(),
              const ArcadeBadge(label: 'CO-OP'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ArcadeBar.segments(
                  litCells: activeDays.clamp(0, target),
                  totalCells: target,
                  accent: kAmber,
                  height: 14,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 30,
                child: ChestOpenAnimation(
                  height: 30,
                  open: banked,
                  play: justBanked,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$activeDays',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 15,
                  color: kText,
                ),
              ),
              Text(
                '/$target',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                'ACTIVE DAYS',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
              ),
              const Spacer(),
              _GemChip(amount: reward),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            banked
                ? 'CACHE BANKED · resets Monday'
                : 'Rest is part of it — the guild rests when you do.',
            style: AppFonts.shareTechMono(
              color: banked ? kAmber : kDim,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GemChip extends StatelessWidget {
  const _GemChip({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: kGemMagenta),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/economy/icon_gem.png',
            width: 11,
            height: 11,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.diamond_sharp, color: kGemMagenta, size: 11),
          ),
          const SizedBox(width: 4),
          Text(
            '+$amount',
            style: AppFonts.shareTechMono(color: kGemMagenta, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
