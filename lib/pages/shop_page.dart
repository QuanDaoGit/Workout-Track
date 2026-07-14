import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/loot_registry.dart';
import '../models/avatar_spec.dart';
import '../models/loot_item.dart';
import '../services/gem_service.dart';
import '../services/loot_service.dart';
import '../services/profile_service.dart';
import '../services/unit_settings_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_bar.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/phosphor_tap.dart';
import '../widgets/pixel_button.dart';
import '../widgets/loot_avatar_frame.dart';
import '../widgets/arcade_notice.dart';

enum _ShopFilter { all, affordable }

class _DemoGemPack {
  const _DemoGemPack({
    required this.id,
    required this.amount,
    required this.demoPrice,
    this.bonus,
  });

  final String id;
  final int amount;
  final String demoPrice;
  final String? bonus;
}

const List<_DemoGemPack> _demoGemPacks = [
  _DemoGemPack(id: 'demo_80', amount: 80, demoPrice: r'DEMO $0.99'),
  _DemoGemPack(
    id: 'demo_500',
    amount: 500,
    demoPrice: r'DEMO $4.99',
    bonus: '+10% BONUS',
  ),
  _DemoGemPack(
    id: 'demo_1200',
    amount: 1200,
    demoPrice: r'DEMO $9.99',
    bonus: '+20% BONUS',
  ),
  _DemoGemPack(
    id: 'demo_2500',
    amount: 2500,
    demoPrice: r'DEMO $19.99',
    bonus: '+30% BONUS',
  ),
];

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final LootService _lootService = LootService();
  final GemService _gemService = GemService();
  final ProfileService _profileService = ProfileService();

  Set<String> _ownedIds = {};
  AvatarSpec _avatarSpec = AvatarSpec.fallback;
  int _gemBalance = 0;
  int _walletPulseSerial = 0;
  bool _loading = true;
  _ShopFilter _filter = _ShopFilter.all;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inventory = await _lootService.getInventory();
    final balance = await _gemService.balance();
    final profile = await _profileService.loadProfile();
    if (!mounted) return;
    setState(() {
      _ownedIds = inventory.map((item) => item.id).toSet();
      _avatarSpec = profile.avatarSpec;
      _gemBalance = balance;
      _loading = false;
    });
  }

  bool _isShopItem(LootItem item) {
    return item.gemPrice != null &&
        item.category == LootCategory.avatarFrame;
  }

  List<LootItem> _shopItems() {
    final items = lootRegistry
        .where(_isShopItem)
        .where((item) => !_ownedIds.contains(item.id))
        .where((item) {
          return switch (_filter) {
            _ShopFilter.all => true,
            _ShopFilter.affordable => (item.gemPrice ?? 0) <= _gemBalance,
          };
        })
        .toList();

    items.sort((a, b) {
      final aAffordable = (a.gemPrice ?? 0) <= _gemBalance;
      final bAffordable = (b.gemPrice ?? 0) <= _gemBalance;
      if (aAffordable != bAffordable) return aAffordable ? -1 : 1;
      final priceCompare = (a.gemPrice ?? 0).compareTo(b.gemPrice ?? 0);
      if (priceCompare != 0) return priceCompare;
      return a.rarity.index.compareTo(b.rarity.index);
    });
    return items;
  }

  void _setFilter(_ShopFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
  }

  Future<void> _openPurchaseSheet(LootItem item) async {
    final price = item.gemPrice!;
    final missing = price - _gemBalance;
    final canBuy = missing <= 0;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kSpace5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: kNeon,
                          ),
                        ),
                        const SizedBox(height: kSpace2),
                        Text(
                          item.category.label,
                          style: AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _GemPricePill(price: price),
                ],
              ),
              const SizedBox(height: kSpace5),
              _ScanlineReveal(
                enabled: !_reduceMotion,
                child: _LiveShopPreview(
                  key: ValueKey('shop_live_preview_${item.category.name}'),
                  item: item,
                  avatarSpec: _avatarSpec,
                  height: 180,
                ),
              ),
              const SizedBox(height: kSpace4),
              Text(
                item.displayDescription(Units.weight),
                style: AppFonts.shareTechMono(
                  fontSize: 14,
                  color: kText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: kSpace2),
              Text(
                item.unlockRule?.displayHint ??
                    'Can also be earned by training.',
                style: AppFonts.shareTechMono(
                  fontSize: 12,
                  color: kMutedText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: kSpace4),
              _BalanceReceipt(balance: _gemBalance, price: price),
              const SizedBox(height: kSpace5),
              PixelButton(
                label: 'PREVIEW',
                secondary: true,
                onPressed: () => _openExpandedPreview(item),
              ),
              const SizedBox(height: kSpace2),
              PixelButton(
                label: 'BUY · $price',
                onPressed: () async {
                  if (!canBuy) {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (!mounted) return;
                    showArcadeNotice(context, 'Not enough gems');
                    // Demo top-up is a dev-only affordance; gems stay
                    // earned-only in release builds.
                    if (kDebugMode) await _openGemStore();
                    return;
                  }
                  try {
                    await _lootService.purchaseItemWithGems(item.id);
                  } on StateError catch (error) {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (!mounted) return;
                    showArcadeNotice(context, error.message);
                    return;
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await _load();
                  if (!mounted) return;
                  await _showPurchaseReveal(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGemStore() async {
    final awarded = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: kSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kSpace5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorderVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: kSpace5),
              const Text(
                'GEM STORE',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: kNeon,
                ),
              ),
              const SizedBox(height: kSpace2),
              Text(
                'Demo top-ups for previewing the cosmetic shop flow.',
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: kSpace5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _demoGemPacks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: kSpace3,
                  mainAxisSpacing: kSpace3,
                  childAspectRatio: 0.86,
                ),
                itemBuilder: (context, index) {
                  final pack = _demoGemPacks[index];
                  return _GemPackCard(
                    pack: pack,
                    onTap: () => Navigator.of(ctx).pop(pack.amount),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (awarded == null || awarded <= 0) return;
    final pack = _demoGemPacks.firstWhere((pack) => pack.amount == awarded);
    await _gemService.awardDemoGems(
      packId: pack.id,
      amount: pack.amount,
      label: '${pack.amount} demo gems',
    );
    await _load();
    if (!mounted) return;
    if (!_reduceMotion) {
      setState(() => _walletPulseSerial++);
    }
    showArcadeNotice(context, '+${pack.amount} GEMS');
  }

  Future<void> _showPurchaseReveal(LootItem item) async {
    final equip = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _PurchaseRevealDialog(item: item, avatarSpec: _avatarSpec),
    );
    if (equip == true) {
      await _lootService.equipItem(item.id);
      await _load();
    }
  }

  Future<void> _openExpandedPreview(LootItem item) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardRadius),
          side: BorderSide(color: item.rarity.color),
        ),
        child: Padding(
          padding: const EdgeInsets.all(kSpace5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${item.name.toUpperCase()} PREVIEW',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kText,
                ),
              ),
              const SizedBox(height: kSpace5),
              _LiveShopPreview(
                key: const ValueKey('shop_expanded_preview'),
                item: item,
                avatarSpec: _avatarSpec,
                height: 260,
                expanded: true,
              ),
              const SizedBox(height: kSpace5),
              PixelButton(
                label: 'CLOSE',
                secondary: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
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
          'GEM SHOP',
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
              child: _WalletPill(
                balance: _gemBalance,
                onAdd: kDebugMode ? _openGemStore : null,
                pulseSerial: _walletPulseSerial,
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
                  _FilterRail(selected: _filter, onChanged: _setFilter),
                  const SizedBox(height: kSpace4),
                  AnimatedSwitcher(
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    switchInCurve: Curves.linear,
                    switchOutCurve: Curves.linear,
                    child: _ShopSections(
                      key: ValueKey(
                        '${_filter.name}-$_gemBalance-${_ownedIds.length}',
                      ),
                      items: _shopItems(),
                      balance: _gemBalance,
                      filter: _filter,
                      onTapItem: _openPurchaseSheet,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({
    required this.balance,
    required this.onAdd,
    required this.pulseSerial,
  });

  final int balance;
  final VoidCallback? onAdd;
  final int pulseSerial;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kCardRadius);
    final reduceMotion =
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;
    return TweenAnimationBuilder<double>(
      key: ValueKey('wallet_pulse_$pulseSerial'),
      tween: Tween(begin: pulseSerial == 0 ? 1 : 0, end: 1),
      duration: reduceMotion || pulseSerial == 0
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.linear,
      builder: (context, value, child) {
        return Container(
          key: const ValueKey('shop_wallet_pill'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: Color.lerp(kNeon, kBorder, value)!),
            borderRadius: radius,
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/economy/icon_gem.png',
            width: 14,
            height: 14,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 6),
          Text(
            '$balance',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              color: kText,
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 7),
            PhosphorTap(
              borderRadius: BorderRadius.circular(4),
              child: HoldDepress(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  key: const ValueKey('shop_wallet_plus'),
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kNeon,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '+',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: kBg,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({required this.selected, required this.onChanged});

  final _ShopFilter selected;
  final ValueChanged<_ShopFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kSpace2,
      runSpacing: kSpace2,
      children: [
        _FilterChipButton(
          label: 'ALL',
          selected: selected == _ShopFilter.all,
          onTap: () => onChanged(_ShopFilter.all),
        ),
        _FilterChipButton(
          label: 'AFFORDABLE',
          selected: selected == _ShopFilter.affordable,
          onTap: () => onChanged(_ShopFilter.affordable),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kCardRadius);
    return PhosphorTap(
      borderRadius: radius,
      child: HoldDepress(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kNeon : kCard,
            border: Border.all(color: selected ? kNeon : kBorder),
            borderRadius: radius,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: selected ? kBg : kMutedText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopSections extends StatelessWidget {
  const _ShopSections({
    super.key,
    required this.items,
    required this.balance,
    required this.filter,
    required this.onTapItem,
  });

  final List<LootItem> items;
  final int balance;
  final _ShopFilter filter;
  final ValueChanged<LootItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyShopState();
    }

    final affordable = items
        .where((item) => (item.gemPrice ?? 0) <= balance)
        .toList();
    final withinReach = items
        .where((item) => (item.gemPrice ?? 0) > balance)
        .toList();

    if (filter == _ShopFilter.affordable) {
      return _ItemSection(
        title: 'AFFORDABLE NOW',
        items: items,
        balance: balance,
        onTapItem: onTapItem,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (affordable.isNotEmpty) ...[
          _ItemSection(
            title: 'AFFORDABLE NOW',
            items: affordable,
            balance: balance,
            onTapItem: onTapItem,
          ),
          const SizedBox(height: kSpace5),
        ],
        if (withinReach.isNotEmpty)
          _ItemSection(
            title: 'WITHIN REACH',
            items: withinReach,
            balance: balance,
            onTapItem: onTapItem,
          ),
      ],
    );
  }
}

class _ItemSection extends StatelessWidget {
  const _ItemSection({
    required this.title,
    required this.items,
    required this.balance,
    required this.onTapItem,
  });

  final String title;
  final List<LootItem> items;
  final int balance;
  final ValueChanged<LootItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '-- $title · ${items.length} --',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: kMutedText,
          ),
        ),
        const SizedBox(height: kSpace3),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: kSpace3,
            mainAxisSpacing: kSpace3,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ShopItemCard(
              item: item,
              balance: balance,
              onTap: () => onTapItem(item),
            );
          },
        ),
      ],
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.item,
    required this.balance,
    required this.onTap,
  });

  final LootItem item;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = item.gemPrice ?? 0;
    final affordable = balance >= price;
    final radius = BorderRadius.circular(kCardRadius);
    final rarityColor = item.rarity.color;
    return PhosphorTap(
      borderRadius: radius,
      child: HoldDepress(
        onTap: onTap,
        borderRadius: radius,
        child: Stack(
          children: [
            Container(
              key: ValueKey('shop_item_${item.id}'),
              padding: const EdgeInsets.fromLTRB(
                kSpace3,
                kSpace3 + 3,
                kSpace3,
                kSpace3,
              ),
              decoration: BoxDecoration(
                color: Color.lerp(kCard, kSurface2, 0.28),
                border: Border.all(color: kBorder),
                borderRadius: radius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ArmoryPreviewBay(
                      item: item,
                      rarityColor: rarityColor,
                    ),
                  ),
                  const SizedBox(height: kSpace3),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.shareTechMono(
                      color: kText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Frame',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: kSpace2),
                  Row(
                    children: [
                      _GemPricePill(
                        price: price,
                        compact: true,
                        highlighted: affordable,
                      ),
                      const Spacer(),
                      if (affordable) const _ReadyChip(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _AffordabilityProgress(
                    balance: balance,
                    price: price,
                    affordable: affordable,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: Container(
                key: ValueKey(
                  'shop_rarity_rail_${item.rarity.name}_${item.id}',
                ),
                height: 3,
                decoration: BoxDecoration(
                  color: rarityColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(kCardRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArmoryPreviewBay extends StatelessWidget {
  const _ArmoryPreviewBay({required this.item, required this.rarityColor});

  final LootItem item;
  final Color rarityColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace2),
      decoration: BoxDecoration(
        color: kBg,
        border: Border.all(color: kBorderDark),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 20,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: kBorder.withValues(alpha: 0.5)),
                  bottom: BorderSide(color: kBorder.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          Center(
            child: Image.asset(
              item.assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) =>
                  _LootImageFallback(item: item, color: rarityColor),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: _RarityBadge(rarity: item.rarity),
          ),
        ],
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.rarity});

  final LootRarity rarity;

  @override
  Widget build(BuildContext context) {
    final color = rarity.color;
    return Container(
      key: ValueKey('shop_rarity_badge_${rarity.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: kBg,
        border: Border.all(color: color.withValues(alpha: 0.72)),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 6, color: color),
      ),
    );
  }
}

class _AffordabilityProgress extends StatelessWidget {
  const _AffordabilityProgress({
    required this.balance,
    required this.price,
    required this.affordable,
  });

  final int balance;
  final int price;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    final ratio = price <= 0 ? 1.0 : (balance / price).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          affordable ? 'READY TO BUY' : '$balance / $price GEMS',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.shareTechMono(
            color: affordable ? kNeon : kMutedText,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        ArcadeBar(value: ratio, accent: kNeon, height: 6),
      ],
    );
  }
}

class _ScanlineReveal extends StatelessWidget {
  const _ScanlineReveal({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.linear,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ScanlineRevealPainter(value)),
                ),
              ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

class _ScanlineRevealPainter extends CustomPainter {
  const _ScanlineRevealPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..color = kNeon.withValues(alpha: 0.34 * (1 - progress));
    canvas.drawRect(
      Rect.fromLTWH(0, y.clamp(0, size.height), size.width, 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanlineRevealPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LiveShopPreview extends StatelessWidget {
  const _LiveShopPreview({
    super.key,
    required this.item,
    required this.avatarSpec,
    required this.height,
    this.expanded = false,
  });

  final LootItem item;
  final AvatarSpec avatarSpec;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: kBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      // scaleDown keeps the preview at natural size when it fits and only
      // shrinks it when the box is too short — so an undersized host (the
      // UNLOCKED dialog) can never overflow, while the roomier call sites are
      // visually unchanged.
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: LootAvatarFrame(
            avatarSpec: avatarSpec,
            framePath: item.assetPath,
            frameCount: item.frameCount,
            animate: true,
            // Integer multiples of the 260px frame master (×1 / ÷2) so the
            // nearest-neighbour scale stays pixel-crisp.
            size: expanded ? 260 : 130,
          ),
        ),
      ),
    );
  }
}

class _GemPricePill extends StatelessWidget {
  const _GemPricePill({
    required this.price,
    this.compact = false,
    this.highlighted = false,
  });

  final int price;
  final bool compact;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: highlighted ? kNeon.withValues(alpha: 0.08) : null,
        border: Border.all(color: highlighted ? kNeon : kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/economy/icon_gem.png',
            width: compact ? 10 : 13,
            height: compact ? 10 : 13,
            filterQuality: FilterQuality.none,
          ),
          SizedBox(width: compact ? 3 : 5),
          Text(
            '$price',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: compact ? 7 : 8,
              color: highlighted ? kNeon : kText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyChip extends StatelessWidget {
  const _ReadyChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: const Text(
        'READY',
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 6, color: kNeon),
      ),
    );
  }
}

class _BalanceReceipt extends StatelessWidget {
  const _BalanceReceipt({required this.balance, required this.price});

  final int balance;
  final int price;

  @override
  Widget build(BuildContext context) {
    final missing = (price - balance).clamp(0, price);
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/economy/icon_gem.png',
            width: 16,
            height: 16,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: kSpace2),
          Expanded(
            child: Text(
              missing == 0
                  ? '$balance GEMS READY'
                  : '$balance / $price GEMS · NEED $missing',
              style: AppFonts.shareTechMono(
                color: missing == 0 ? kNeon : kMutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GemPackCard extends StatelessWidget {
  const _GemPackCard({required this.pack, required this.onTap});

  final _DemoGemPack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kCardRadius);
    return PhosphorTap(
      borderRadius: radius,
      child: HoldDepress(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          key: ValueKey('gem_pack_${pack.id}'),
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: kBorder),
            borderRadius: radius,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/economy/icon_gem.png',
                width: 32,
                height: 32,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(height: kSpace3),
              Text(
                '${pack.amount}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                  color: kText,
                ),
              ),
              const SizedBox(height: kSpace2),
              Text(
                pack.bonus ?? 'DEMO PACK',
                textAlign: TextAlign.center,
                style: AppFonts.shareTechMono(
                  color: pack.bonus == null ? kMutedText : kNeon,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(kCardRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  pack.demoPrice,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: kMutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseRevealDialog extends StatelessWidget {
  const _PurchaseRevealDialog({required this.item, required this.avatarSpec});

  final LootItem item;
  final AvatarSpec avatarSpec;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;
    return Dialog(
      backgroundColor: kSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
        side: const BorderSide(color: kAmber),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.linear,
        builder: (context, value, child) {
          return Container(
            padding: const EdgeInsets.all(kSpace5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kCardRadius),
              boxShadow: [
                BoxShadow(
                  color: kAmber.withValues(alpha: 0.18 * value),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'UNLOCKED',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: kAmber,
              ),
            ),
            const SizedBox(height: kSpace4),
            _LiveShopPreview(item: item, avatarSpec: avatarSpec, height: 160),
            const SizedBox(height: kSpace4),
            Text(
              item.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: kText,
              ),
            ),
            const SizedBox(height: kSpace5),
            PixelButton(
              label: 'EQUIP NOW',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: kSpace2),
            PixelButton(
              label: 'DONE',
              secondary: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyShopState extends StatelessWidget {
  const _EmptyShopState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHOP CLEARED',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              color: kNeon,
            ),
          ),
          const SizedBox(height: kSpace2),
          Text(
            'All purchasable cosmetics are already in your inventory.',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LootImageFallback extends StatelessWidget {
  const _LootImageFallback({required this.item, Color? color})
    : color = color ?? kNeon;

  final LootItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: color),
      ),
      alignment: Alignment.center,
      child: Text(
        item.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14,
          color: color,
        ),
      ),
    );
  }
}
