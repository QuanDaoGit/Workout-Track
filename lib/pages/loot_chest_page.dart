import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/loot_registry.dart';
import '../models/loot_item.dart';
import '../services/loot_service.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pulse_color_text.dart';
import '../widgets/strobe_flash.dart';

class LootChestPage extends StatefulWidget {
  final LootResult? initialLoot;

  const LootChestPage({super.key, this.initialLoot});

  @override
  State<LootChestPage> createState() => _LootChestPageState();
}

class _LootChestPageState extends State<LootChestPage> {
  final LootService _lootService = LootService();
  LootResult? _loot;
  LootResult? _claimed;
  bool _loading = true;
  bool _opened = false;
  bool _claiming = false;
  int _flashToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loot = widget.initialLoot ?? await _lootService.getUnclaimedLoot();
    if (!mounted) return;
    setState(() {
      _loot = loot;
      _loading = false;
    });
  }

  void _openChest() {
    if (_opened || _loot == null) return;
    setState(() {
      _opened = true;
      _flashToken++;
    });
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final claimed = await _lootService.claimUnclaimedLoot();
    if (!mounted) return;
    setState(() {
      _claimed = claimed ?? _loot;
      _claiming = false;
    });
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF9C)),
              )
            : _loot == null
            ? _buildEmpty()
            : _claimed == null
            ? _buildChest(_loot!)
            : _buildClaimed(_claimed!),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'NO SPOILS',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No unclaimed reward is waiting.',
            style: GoogleFonts.shareTechMono(
              fontSize: 14,
              color: const Color(0xFFB8B8D8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PixelButton(label: 'BACK TO HOME', onPressed: _goHome),
        ],
      ),
    );
  }

  Widget _buildChest(LootResult loot) {
    final chestAsset = loot.isBoss ? bossChestAsset : commonChestAsset;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openChest,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height - 80,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'VICTORY SPOILS',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: Color(0xFFFFD700),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: loot.item.rarity.color),
                ),
                child: Column(
                  children: [
                    if (!_opened) ...[
                      Image.asset(
                        chestAsset,
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                      const SizedBox(height: 18),
                      PulseColorText(
                        'Tap to open',
                        style: GoogleFonts.shareTechMono(fontSize: 16),
                        colorA: Colors.white,
                        colorB: const Color(0xFF6B6B8A),
                      ),
                    ] else ...[
                      StrobeFlash(
                        trigger: _flashToken,
                        color: loot.item.rarity.color,
                        borderRadius: BorderRadius.circular(4),
                        fireOnMount: true,
                        child: _LootItemPreview(item: loot.item, size: 112),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        loot.item.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          color: loot.item.rarity.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${loot.item.rarity.label} DROP',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 8,
                          color: loot.item.rarity.color,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (loot.isDuplicate) ...[
                        Text(
                          'ALREADY OWNED',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                            color: Color(0xFF6B6B8A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '+${loot.scrapAwarded} SCRAP',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                            color: Color(0xFF00BFFF),
                          ),
                        ),
                      ] else
                        Text(
                          loot.item.description,
                          style: GoogleFonts.shareTechMono(
                            fontSize: 14,
                            color: const Color(0xFFB8B8D8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 24),
                      PixelButton(
                        label: loot.isDuplicate ? 'CLAIM SCRAP' : 'CLAIM',
                        color: loot.isDuplicate
                            ? const Color(0xFF00BFFF)
                            : const Color(0xFF00FF9C),
                        isLoading: _claiming,
                        onPressed: _claim,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimed(LootResult loot) {
    final nextFloor = loot.floor == null ? null : loot.floor! + 1;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            loot.isDuplicate ? 'SCRAP CLAIMED' : 'LOOT CLAIMED',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: loot.isDuplicate
                  ? const Color(0xFF00BFFF)
                  : const Color(0xFF00FF9C),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          _LootItemPreview(item: loot.item, size: 96),
          const SizedBox(height: 20),
          Text(
            loot.isDuplicate
                ? '+${loot.scrapAwarded} SCRAP'
                : loot.item.name.toUpperCase(),
            style: GoogleFonts.shareTechMono(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (nextFloor != null) ...[
            const SizedBox(height: 18),
            Text(
              '+1 FLOOR',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dungeon floor $nextFloor unlocked.',
              style: GoogleFonts.shareTechMono(
                fontSize: 14,
                color: const Color(0xFFB8B8D8),
              ),
            ),
          ],
          const SizedBox(height: 28),
          PixelButton(label: 'BACK TO HOME', onPressed: _goHome),
        ],
      ),
    );
  }
}

class _LootItemPreview extends StatelessWidget {
  final LootItem item;
  final double size;

  const _LootItemPreview({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    if (item.category == LootCategory.titleBadge) {
      return Container(
        width: size * 1.8,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: item.color),
        ),
        alignment: Alignment.center,
        child: Text(
          item.name.toUpperCase(),
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: item.color,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        item.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: item.color),
          ),
          alignment: Alignment.center,
          child: Text(
            item.name.substring(0, 1),
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 18,
              color: item.color,
            ),
          ),
        ),
      ),
    );
  }
}
