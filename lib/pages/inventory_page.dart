import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/loot_registry.dart';
import '../models/loot_item.dart';
import '../services/loot_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/pixel_button.dart';
import 'scrap_shop_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final LootService _lootService = LootService();
  Set<String> _ownedIds = {};
  Map<LootCategory, LootItem> _equipped = {};
  int _scrap = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inventory = await _lootService.getInventory();
    final equipped = await _lootService.getEquippedLoot();
    final scrap = await _lootService.getScrapBalance();
    if (!mounted) return;
    setState(() {
      _ownedIds = inventory.map((item) => item.id).toSet();
      _equipped = equipped;
      _scrap = scrap;
      _loading = false;
    });
  }

  Future<void> _confirmEquip(LootItem item) async {
    if (!_ownedIds.contains(item.id)) {
      _showLocked(item);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: item.color),
        ),
        title: Text(
          'EQUIP ${item.name.toUpperCase()}?',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kNeon,
          ),
        ),
        content: Text(
          item.description,
          style: GoogleFonts.shareTechMono(fontSize: 14, color: kMutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.shareTechMono(color: kMutedText),
            ),
          ),
          SizedBox(
            width: 150,
            child: PixelButton(
              label: 'EQUIP',
              fullWidth: false,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _lootService.equipItem(item.id);
    await _load();
  }

  void _showLocked(LootItem item) {
    final hint = item.bossExclusive && item.bossFloor != null
        ? 'DEFEAT BOSS FLOOR ${item.bossFloor}'
        : 'Locked loot. Find it in battle rewards or the scrap shop.';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(kSpace5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: kMutedText,
              ),
            ),
            const SizedBox(height: kSpace3),
            Text(
              hint,
              style: GoogleFonts.shareTechMono(fontSize: 14, color: kMutedText),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openShop() async {
    await Navigator.of(context).push(arcadeRoute((_) => const ScrapShopPage()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kNeon,
        elevation: 0,
        title: const Text(
          'LOOT INVENTORY',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: kNeon,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: kSpace4),
            child: Center(
              child: Text(
                'SCRAP: $_scrap ◆',
                style: GoogleFonts.shareTechMono(
                  fontSize: 13,
                  color: kCyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kNeon))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVisualSection(LootCategory.avatarFrame),
                  _buildTitleSection(),
                  _buildVisualSection(LootCategory.homeTheme),
                  _buildVisualSection(LootCategory.battleEffect),
                  const SizedBox(height: kSpace4),
                  PixelButton(
                    label: 'SCRAP SHOP',
                    color: kCyan,
                    onPressed: _openShop,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildVisualSection(LootCategory category) {
    final items = lootRegistry
        .where((item) => item.category == category)
        .toList();
    final ownedCount = items
        .where((item) => _ownedIds.contains(item.id))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(
          label: category.label,
          owned: ownedCount,
          total: items.length,
        ),
        const SizedBox(height: kSpace3),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _LootGridTile(
              item: item,
              owned: _ownedIds.contains(item.id),
              equipped: _equipped[category]?.id == item.id,
              onTap: () => _confirmEquip(item),
            );
          },
        ),
        const SizedBox(height: kSpace5),
      ],
    );
  }

  Widget _buildTitleSection() {
    final items = lootRegistry
        .where((item) => item.category == LootCategory.titleBadge)
        .toList();
    final ownedCount = items
        .where((item) => _ownedIds.contains(item.id))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(
          label: LootCategory.titleBadge.label,
          owned: ownedCount,
          total: items.length,
        ),
        const SizedBox(height: kSpace3),
        for (final item in items)
          _TitleLootRow(
            item: item,
            owned: _ownedIds.contains(item.id),
            equipped: _equipped[LootCategory.titleBadge]?.id == item.id,
            onTap: () => _confirmEquip(item),
          ),
        const SizedBox(height: kSpace5),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String label;
  final int owned;
  final int total;

  const _CategoryHeader({
    required this.label,
    required this.owned,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '-- $label ($owned/$total) --',
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 8,
        color: kMutedText,
      ),
    );
  }
}

class _LootGridTile extends StatelessWidget {
  final LootItem item;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  const _LootGridTile({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: equipped
                ? kNeon
                : owned
                ? item.color.withValues(alpha: 0.75)
                : kBorder,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: owned ? 1 : 0.28,
                    child: Image.asset(
                      item.assetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, error, stackTrace) =>
                          _LootImageFallback(item: item),
                    ),
                  ),
                  if (!owned)
                    const Center(
                      child: Icon(
                        Icons.lock_sharp,
                        color: kMutedText,
                        size: 18,
                      ),
                    ),
                  if (equipped)
                    const Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.check_sharp, color: kNeon, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.shareTechMono(
                fontSize: 10,
                color: owned ? Colors.white : kMutedText,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LootImageFallback extends StatelessWidget {
  final LootItem item;

  const _LootImageFallback({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: item.color),
      ),
      alignment: Alignment.center,
      child: Text(
        item.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14,
          color: item.color,
        ),
      ),
    );
  }
}

class _TitleLootRow extends StatelessWidget {
  final LootItem item;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  const _TitleLootRow({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hint = item.bossExclusive && item.bossFloor != null
        ? 'DEFEAT BOSS FLOOR ${item.bossFloor}'
        : item.rarity.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: equipped ? kNeon : kBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.shareTechMono(
                        fontSize: 15,
                        color: owned ? item.color : kMutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owned ? item.description : hint,
                      style: GoogleFonts.shareTechMono(
                        fontSize: 12,
                        color: kMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                equipped
                    ? Icons.check_sharp
                    : owned
                    ? Icons.inventory_2_sharp
                    : Icons.lock_sharp,
                color: equipped
                    ? kNeon
                    : owned
                    ? item.color
                    : kMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
