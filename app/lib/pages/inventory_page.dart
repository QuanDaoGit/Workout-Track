import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/loot_registry.dart';
import '../models/loot_item.dart';
import '../services/haptic_service.dart';
import '../services/loot_service.dart';
import '../services/ui_sound.dart';
import '../services/unit_settings_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_filled.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/pixel_button.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => InventoryPageState();
}

class InventoryPageState extends State<InventoryPage> {
  final LootService _lootService = LootService();
  Set<String> _ownedIds = {};
  Map<LootCategory, LootItem> _equipped = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-fetch owned + equipped loot. Called by [RootPage] on tab re-entry so a
  /// kept-alive (IndexedStack) page shows loot earned after its first build.
  Future<void> reload() => _load();

  Future<void> _load() async {
    final inventory = await _lootService.getInventory();
    final equipped = await _lootService.getEquippedLoot();
    if (!mounted) return;
    setState(() {
      _ownedIds = inventory.map((item) => item.id).toSet();
      _equipped = equipped;
      _loading = false;
    });
  }

  Future<void> _confirmEquip(LootItem item) async {
    if (!_ownedIds.contains(item.id)) return;

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
          item.displayDescription(Units.weight),
          style: AppFonts.shareTechMono(fontSize: 14, color: kMutedText),
        ),
        actions: [
          ArcadeTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: AppFonts.shareTechMono(color: kMutedText),
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
    HapticService.instance.success(); // the "equipped" payoff
    await _load();
  }

  Future<void> _clearTitle() async {
    await _lootService.unequipCategory(LootCategory.titleBadge);
    HapticService.instance.selection();
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
                ],
              ),
            ),
    );
  }

  Widget _buildVisualSection(LootCategory category) {
    final allItems = lootRegistry.where((item) => item.category == category);
    final items = allItems
        .where((item) => _ownedIds.contains(item.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(
          label: category.label,
          owned: items.length,
          total: allItems.length,
        ),
        const SizedBox(height: kSpace3),
        if (items.isEmpty)
          const _EmptyInventoryHint()
        else
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
    final allItems = lootRegistry.where(
      (item) => item.category == LootCategory.titleBadge,
    );
    final items = allItems
        .where((item) => _ownedIds.contains(item.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(
          label: LootCategory.titleBadge.label,
          owned: items.length,
          total: allItems.length,
        ),
        const SizedBox(height: kSpace3),
        // "No Title" is always available: an earned title is never lost, and the
        // user can freely revert to an untitled card and re-pick any time.
        _NoTitleRow(
          selected: _equipped[LootCategory.titleBadge] == null,
          onTap: _clearTitle,
        ),
        for (final item in items)
          _TitleLootRow(
            item: item,
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

class _EmptyInventoryHint extends StatelessWidget {
  const _EmptyInventoryHint();

  @override
  Widget build(BuildContext context) {
    const label = 'frames';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Text(
        'No owned $label yet. Visit the Gem Shop or keep training.',
        style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
      ),
    );
  }
}

class _NoTitleRow extends StatelessWidget {
  const _NoTitleRow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoldDepress(
        onTap: onTap,
        haptic: HapticIntent.selection,
        sound: UiSound.select,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: selected ? kNeon : kBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Title',
                      style: AppFonts.shareTechMono(
                        fontSize: 15,
                        color: kText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Show no title on your card.',
                      style: AppFonts.shareTechMono(
                        fontSize: 12,
                        color: kMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_sharp : Icons.block_sharp,
                color: selected ? kNeon : kMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LootGridTile extends StatelessWidget {
  final LootItem item;
  final bool equipped;
  final VoidCallback onTap;

  const _LootGridTile({
    required this.item,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoldDepress(
      onTap: onTap,
      haptic: HapticIntent.selection,
      sound: UiSound.select,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: equipped ? kNeon : kBorder),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 1,
                    child: Image.asset(
                      item.assetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, error, stackTrace) =>
                          _LootImageFallback(item: item),
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
              style: AppFonts.shareTechMono(
                fontSize: 10,
                color: kText,
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
  final bool equipped;
  final VoidCallback onTap;

  const _TitleLootRow({
    required this.item,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoldDepress(
        onTap: onTap,
        haptic: HapticIntent.selection,
        sound: UiSound.select,
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
                      style: AppFonts.shareTechMono(
                        fontSize: 15,
                        color: item.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.displayDescription(Units.weight),
                      style: AppFonts.shareTechMono(
                        fontSize: 12,
                        color: kMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                equipped ? Icons.check_sharp : Icons.inventory_2_sharp,
                color: equipped ? kNeon : item.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
