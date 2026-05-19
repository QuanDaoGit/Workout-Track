import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/xp_boost_potion.dart';

class XpBoostService {
  static const _potionsKey = 'xp_potions_v1';
  static const _bonusTotalKey = 'xp_potion_bonus_total';
  static const double _maxMultiplier = 5.0;

  /// Optional clock override for testing.
  final DateTime Function() _now;

  XpBoostService({DateTime Function()? nowProvider})
    : _now = nowProvider ?? DateTime.now;

  /// Returns currently active (non-expired) potions.
  Future<List<XpBoostPotion>> getActivePotions() async {
    final all = await _loadPotions();
    final now = _now();
    return all.where((p) => now.isBefore(p.expiresAt)).toList();
  }

  /// Grant a new potion (2x XP for 24h).
  Future<XpBoostPotion> grantPotion({
    double multiplier = 2.0,
    bool directionBonus = false,
  }) async {
    final now = _now();
    final potion = XpBoostPotion(
      id: 'potion_${now.millisecondsSinceEpoch}',
      grantedAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      multiplier: multiplier,
      isDirectionBonus: directionBonus,
    );
    final all = await _loadPotions();
    all.add(potion);
    await _savePotions(all);
    return potion;
  }

  /// Effective multiplier from all active potions.
  /// Formula: 1.0 + sum((mult - 1.0) for each active), capped at 5.0.
  Future<double> getEffectiveMultiplier() async {
    final active = await getActivePotions();
    if (active.isEmpty) return 1.0;
    final sum = active.fold(0.0, (s, p) => s + (p.multiplier - 1.0));
    return min(1.0 + sum, _maxMultiplier);
  }

  /// Consume active potions for a workout session.
  /// Returns the bonus XP amount (total XP - base XP).
  /// Potions are consumed (removed) after use.
  Future<int> consumeForSession(int baseXP) async {
    final active = await getActivePotions();
    if (active.isEmpty) return 0;

    final multiplier = await getEffectiveMultiplier();
    final totalXP = (baseXP * multiplier).round();
    final bonusXP = totalXP - baseXP;

    // Remove consumed potions
    final all = await _loadPotions();
    final activeIds = active.map((p) => p.id).toSet();
    all.removeWhere((p) => activeIds.contains(p.id));
    await _savePotions(all);

    // Add to running total
    final prefs = await SharedPreferences.getInstance();
    final currentTotal = prefs.getInt(_bonusTotalKey) ?? 0;
    await prefs.setInt(_bonusTotalKey, currentTotal + bonusXP);

    return bonusXP;
  }

  /// Running total of all potion-boosted XP ever granted.
  Future<int> getTotalBonusXP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bonusTotalKey) ?? 0;
  }

  /// Display label for active boosts, e.g. "3x XP · 18h LEFT".
  /// Returns null if no active potions.
  Future<String?> getActiveBoostLabel() async {
    final active = await getActivePotions();
    if (active.isEmpty) return null;

    final multiplier = await getEffectiveMultiplier();
    final multLabel =
        '${multiplier.toStringAsFixed(multiplier == multiplier.roundToDouble() ? 0 : 1)}x';

    // Find earliest expiry
    final now = _now();
    Duration? shortest;
    for (final p in active) {
      final remaining = p.expiresAt.difference(now);
      if (shortest == null || remaining < shortest) shortest = remaining;
    }
    if (shortest == null || shortest.isNegative) return null;

    final hours = shortest.inHours;
    final timeLabel = hours > 0
        ? '${hours}h LEFT'
        : '${shortest.inMinutes}m LEFT';
    return '$multLabel XP \u00B7 $timeLabel';
  }

  Future<List<XpBoostPotion>> _loadPotions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_potionsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final e in list) XpBoostPotion.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<void> _savePotions(List<XpBoostPotion> potions) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(potions.map((p) => p.toJson()).toList());
    await prefs.setString(_potionsKey, json);
  }
}
