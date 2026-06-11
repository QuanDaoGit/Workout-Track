import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/xp_boost_potion.dart';

class XpBoostService {
  static const _potionsKey = 'xp_potions_v1';
  static const _bonusTotalKey = 'xp_potion_bonus_total';
  static const double _maxMultiplier = 5.0;

  /// Monotonic suffix so back-to-back grants (base + direction bonus) never
  /// collide on `millisecondsSinceEpoch` and share an id.
  static int _idSeq = 0;

  /// Optional clock override for testing.
  final DateTime Function() _now;

  XpBoostService({DateTime Function()? nowProvider})
    : _now = nowProvider ?? DateTime.now;

  /// Returns currently active potions: not expired and with charges left.
  Future<List<XpBoostPotion>> getActivePotions() async {
    final all = await _loadPotions();
    final now = _now();
    return all
        .where((p) => now.isBefore(p.expiresAt) && p.chargesRemaining > 0)
        .toList();
  }

  /// Grant a new potion (2x XP for the next [XpBoostPotion.maxCharges] eligible
  /// workouts, expiring after 3 weeks as a backstop — long enough that all three
  /// charges can be spent at a realistic weekly training cadence).
  Future<XpBoostPotion> grantPotion({
    double multiplier = 2.0,
    bool directionBonus = false,
  }) async {
    final now = _now();
    final potion = XpBoostPotion(
      id: 'potion_${now.millisecondsSinceEpoch}_${_idSeq++}',
      grantedAt: now,
      expiresAt: now.add(const Duration(days: 21)),
      multiplier: multiplier,
      isDirectionBonus: directionBonus,
      chargesRemaining: XpBoostPotion.maxCharges,
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

  /// Record realized potion-bonus XP into the lifetime running total surfaced by
  /// [getTotalBonusXP]. Called once per saved workout with the session's bonus
  /// (final − base, already computed in the XP breakdown). No-op for a
  /// non-positive amount. Pairs with [consumeActivePotions], which spends the
  /// charges; this only accounts for the bonus.
  Future<void> recordBonusXp(int bonusXP) async {
    if (bonusXP <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_bonusTotalKey) ?? 0;
    await prefs.setInt(_bonusTotalKey, current + bonusXP);
  }

  /// Spend one charge from each active potion for a workout session.
  ///
  /// Returns the effective multiplier applied to this session. Each active
  /// potion loses one charge; potions that reach 0 charges (or have expired)
  /// are dropped. New workout sessions persist their final awarded XP on the
  /// session itself, so this does not touch the legacy `_bonusTotalKey`.
  Future<double> consumeActivePotions() async {
    final all = await _loadPotions();
    final now = _now();
    final active = all
        .where((p) => now.isBefore(p.expiresAt) && p.chargesRemaining > 0)
        .toList();
    if (active.isEmpty) {
      // Opportunistically prune any expired/spent potions.
      if (active.length != all.length) await _savePotions(active);
      return 1.0;
    }

    final multiplier = min(
      1.0 + active.fold(0.0, (s, p) => s + (p.multiplier - 1.0)),
      _maxMultiplier,
    );

    // Survivors = active potions with one charge spent, keeping only those that
    // still have charges left. Expired/spent potions are dropped.
    final survivors = <XpBoostPotion>[
      for (final p in active)
        if (p.chargesRemaining - 1 > 0)
          p.copyWith(chargesRemaining: p.chargesRemaining - 1),
    ];
    await _savePotions(survivors);
    return multiplier;
  }

  /// Running total of all potion-boosted XP ever granted.
  Future<int> getTotalBonusXP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bonusTotalKey) ?? 0;
  }

  /// Display label for active boosts, e.g. "3x XP · 3 WORKOUTS".
  /// The charge count is how many more eligible workouts the boost covers.
  /// Returns null if no active potions.
  Future<String?> getActiveBoostLabel() async {
    final active = await getActivePotions();
    if (active.isEmpty) return null;

    final multiplier = await getEffectiveMultiplier();
    final multLabel =
        '${multiplier.toStringAsFixed(multiplier == multiplier.roundToDouble() ? 0 : 1)}x';

    final charges = active.map((p) => p.chargesRemaining).reduce(max);
    final unit = charges == 1 ? 'WORKOUT' : 'WORKOUTS';
    return '$multLabel XP \u00B7 $charges $unit';
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
