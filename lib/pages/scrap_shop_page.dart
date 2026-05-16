import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/loot_item.dart';
import '../services/loot_service.dart';
import '../theme/tokens.dart';
import '../widgets/pixel_button.dart';

class ScrapShopPage extends StatefulWidget {
  const ScrapShopPage({super.key});

  @override
  State<ScrapShopPage> createState() => _ScrapShopPageState();
}

class _ScrapShopPageState extends State<ScrapShopPage> {
  final LootService _lootService = LootService();
  List<LootItem> _items = [];
  int _scrap = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _lootService.getShopItems();
    final scrap = await _lootService.getScrapBalance();
    if (!mounted) return;
    setState(() {
      _items = items;
      _scrap = scrap;
      _loading = false;
    });
  }

  Future<void> _confirmBuy(LootItem item) async {
    final price = item.rarity.shopPrice;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: kCyan),
        ),
        title: Text(
          'SPEND $price SCRAP?',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kCyan,
          ),
        ),
        content: Text(
          item.name,
          style: GoogleFonts.shareTechMono(fontSize: 16, color: Colors.white),
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
            width: 140,
            child: PixelButton(
              label: 'BUY',
              fullWidth: false,
              color: kCyan,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _lootService.purchaseWithScrap(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kCyan,
        elevation: 0,
        title: const Text(
          'SCRAP SHOP',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: kCyan,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'YOUR SCRAP: $_scrap ◆',
                    style: GoogleFonts.shareTechMono(
                      fontSize: 15,
                      color: kCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: kSpace4),
                  if (_items.isEmpty)
                    Text(
                      'Shop cleared. Boss loot still waits in the dungeon.',
                      style: GoogleFonts.shareTechMono(
                        fontSize: 14,
                        color: kMutedText,
                      ),
                    )
                  else
                    for (final item in _items)
                      _ShopItemRow(
                        item: item,
                        scrap: _scrap,
                        onBuy: _confirmBuy,
                      ),
                ],
              ),
            ),
    );
  }
}

class _ShopItemRow extends StatelessWidget {
  final LootItem item;
  final int scrap;
  final ValueChanged<LootItem> onBuy;

  const _ShopItemRow({
    required this.item,
    required this.scrap,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final price = item.rarity.shopPrice;
    final canBuy = scrap >= price;
    return Container(
      margin: const EdgeInsets.only(bottom: kSpace3),
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          _ShopItemVisual(item: item),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.rarity.label} · $price ◆',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 12,
                    color: item.rarity.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace2),
          SizedBox(
            width: 86,
            child: PixelButton(
              label: 'BUY',
              color: kCyan,
              fullWidth: false,
              onPressed: canBuy ? () => onBuy(item) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopItemVisual extends StatelessWidget {
  final LootItem item;

  const _ShopItemVisual({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.category == LootCategory.titleBadge) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: item.color),
        ),
        alignment: Alignment.center,
        child: Text(
          'T',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16,
            color: item.color,
          ),
        ),
      );
    }
    return SizedBox(
      width: 54,
      height: 54,
      child: Image.asset(
        item.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (context, error, stackTrace) =>
            _ShopImageFallback(item: item),
      ),
    );
  }
}

class _ShopImageFallback extends StatelessWidget {
  final LootItem item;

  const _ShopImageFallback({required this.item});

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
