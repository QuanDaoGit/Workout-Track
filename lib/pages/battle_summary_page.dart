import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/idle_battle_models.dart';
import '../models/loot_item.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import 'live_dungeon_page.dart';

/// Shown on app open after offline battles were simulated.
class BattleSummaryPage extends StatelessWidget {
  const BattleSummaryPage({super.key, required this.result});

  final OfflineSimResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: result.wasEntirelyRest
              ? _buildRestDayContent(context)
              : _buildBattleContent(context),
        ),
      ),
    );
  }

  Widget _buildRestDayContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'REST DAY',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kMutedText,
            ),
          ),
          const SizedBox(height: kSpace2),
          Text(
            'NO BATTLES',
            style: GoogleFonts.shareTechMono(fontSize: 16, color: kMutedText),
          ),
          const SizedBox(height: kSpace5),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleContent(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        // Floor change
        _buildFloorChange(),
        const SizedBox(height: kSpace5),
        // Battle tally
        _buildBattleTally(),
        const SizedBox(height: kSpace5),
        // Loot section
        if (result.lootGained.isNotEmpty) ...[
          _buildLootSection(),
          const SizedBox(height: kSpace5),
        ],
        const Spacer(),
        // Enter dungeon button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                arcadeRoute((_) => const LiveDungeonPage()),
              );
            },
            child: const Text('ENTER DUNGEON'),
          ),
        ),
      ],
    );
  }

  Widget _buildFloorChange() {
    final delta = result.floorDelta;
    if (delta == 0) {
      return Text(
        'FLOOR ${result.startFloor} — HELD',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 16,
          color: kText,
        ),
      );
    }

    final arrowColor = delta > 0 ? kNeon : kDanger;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'FLOOR ${result.startFloor}',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16,
            color: kText,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace3),
          child: Text(
            '\u2192',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 16,
              color: arrowColor,
            ),
          ),
        ),
        Text(
          '${result.endFloor}',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16,
            color: arrowColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBattleTally() {
    return Text(
      '${result.totalBattles} BATTLES  |  '
      '${result.wins} WINS  |  '
      '${result.losses} LOSSES',
      textAlign: TextAlign.center,
      style: GoogleFonts.shareTechMono(fontSize: 13, color: kMutedText),
    );
  }

  Widget _buildLootSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final loot in result.lootGained) _buildLootCard(loot),
      ],
    );
  }

  Widget _buildLootCard(LootResult loot) {
    final item = loot.item;
    final rarityColor = item.rarity.color;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: kSpace2),
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.2),
              border: Border.all(color: rarityColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '★',
                style: TextStyle(fontSize: 14, color: rarityColor),
              ),
            ),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: rarityColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loot.isDuplicate
                      ? '+${loot.scrapAwarded} SCRAP'
                      : item.rarity.label.toUpperCase(),
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    color: kMutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
