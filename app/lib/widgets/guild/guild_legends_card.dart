import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../arcade_card.dart';

/// Guild Legends — the recognition surface. In **solo v1** there are no other
/// members to rank, so it shows YOUR week's highlights as self-referenced badges
/// (active days · streak · improvement vs last week) — body-neutral (you vs your
/// past), and the "improved" badge never shows a red/negative failure. A quiet,
/// supporting card: uniform muted icons/labels with white values, so it recedes
/// under the hall/crest hero. Phase 2 turns it into the spread-badge board.
class GuildLegendsCard extends StatelessWidget {
  const GuildLegendsCard({
    super.key,
    required this.activeDays,
    required this.streak,
    required this.improvedDelta,
  });

  final int activeDays;
  final int streak;

  /// active-days this week minus last week. >0 shows "+N"; <=0 reads "STEADY"
  /// (neutral — no punishment for a lighter or recovery week).
  final int improvedDelta;

  @override
  Widget build(BuildContext context) {
    final improvedUp = improvedDelta > 0;
    return ArcadeCard(
      key: const ValueKey('guild_legends'),
      borderAlpha: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'GUILD LEGENDS',
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 11,
                ).copyWith(letterSpacing: 1),
              ),
              const SizedBox(width: 8),
              Text(
                '· THIS WEEK',
                style: AppFonts.shareTechMono(color: kDim, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Badge(
                icon: Icons.calendar_month_sharp,
                label: 'ACTIVE DAYS',
                value: '$activeDays',
              ),
              const SizedBox(width: 8),
              _Badge(
                icon: Icons.local_fire_department_sharp,
                label: 'IRON STREAK',
                value: '$streak',
              ),
              const SizedBox(width: 8),
              _Badge(
                icon: Icons.trending_up_sharp,
                label: 'IMPROVED',
                value: improvedUp ? '+$improvedDelta' : 'STEADY',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'More legends light up when guildmates join.',
            style: AppFonts.shareTechMono(color: kDim, fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ArcadeCard(
        background: kBg,
        borderAlpha: 0.6,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: kMutedText, size: 18),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 9),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: value.length > 3 ? 9 : 12,
                color: kText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
