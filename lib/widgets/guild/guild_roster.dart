import 'package:flutter/material.dart';

import '../../models/guild_models.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../arcade_badge.dart';
import '../arcade_card.dart';
import '../loot_avatar_frame.dart';

/// The guild roster — solo-honest v1: the player (real, wearing their equipped
/// frame) followed by OPEN slots awaiting future real guildmates. No NPC members.
/// Built on the canonical `ArcadeCard` / `ArcadeBadge`; the player's avatar
/// renders through `LootAvatarFrame` so the earned cosmetic actually shows.
class GuildRoster extends StatelessWidget {
  const GuildRoster({
    super.key,
    required this.player,
    required this.openSlots,
  });

  final GuildMember player;
  final int openSlots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ROSTER',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _PlayerTile(player: player),
        for (var i = 0; i < openSlots; i++) ...[
          const SizedBox(height: 8),
          const _OpenSlotTile(),
        ],
        const SizedBox(height: 12),
        Text(
          'Open slots await real guildmates — coming in a future update.',
          style: AppFonts.shareTechMono(color: kDim, fontSize: 10, height: 1.4),
        ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player});

  final GuildMember player;

  @override
  Widget build(BuildContext context) {
    final days = player.activeDays;
    return ArcadeCard(
      key: const ValueKey('guild_roster_player'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 65 = 260 / 4 → integer downscale, crisp frame (260px master art).
          LootAvatarFrame(
            avatarSpec: player.avatarSpec,
            framePath: player.framePath,
            frameCount: player.frameCount,
            size: 65,
            avatarDropPx: 65 * 0.76 / 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name.isEmpty ? 'YOU' : player.name.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.shareTechMono(
                          color: kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ArcadeBadge(label: player.rank),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$days active ${days == 1 ? 'day' : 'days'} this week',
                  style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenSlotTile extends StatelessWidget {
  const _OpenSlotTile();

  @override
  Widget build(BuildContext context) {
    return ArcadeCard(
      borderAlpha: 0.5,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kBg,
              border: Border.all(color: kBorder.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(kCardRadius),
            ),
            child: const Icon(Icons.add_sharp, color: kDim, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'OPEN',
            style: AppFonts.shareTechMono(
              color: kDim,
              fontSize: 13,
            ).copyWith(letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
