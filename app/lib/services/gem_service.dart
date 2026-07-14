import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/gem_ledger_entry.dart';
import 'json_safe.dart';
import 'keyed_lock.dart';

class GemService {
  static const String ledgerKey = 'gem_ledger_v1';

  Future<int> balance() async {
    final entries = await ledger();
    return entries.fold<int>(0, (sum, entry) => sum + entry.amount);
  }

  Future<List<GemLedgerEntry>> ledger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ledgerKey);
    // Corruption-tolerant: a malformed ledger or a single bad entry yields the
    // salvageable subset instead of throwing (this is the currency store).
    return safeMapList(raw, GemLedgerEntry.fromJson, debugLabel: ledgerKey);
  }

  Future<int> awardQuestGems({
    required String claimKey,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final id = 'quest:$claimKey';
    return prefsWriteLock.synchronized(ledgerKey, () async {
      final entries = await ledger();
      if (entries.any((entry) => entry.id == id)) return 0;
      await _save([
        ...entries,
        GemLedgerEntry(
          id: id,
          amount: amount,
          sourceKind: GemLedgerSourceKind.quest,
          sourceId: claimKey,
          label: label,
          createdAt: now ?? DateTime.now(),
        ),
      ]);
      return amount;
    });
  }

  /// Awards a quest **section-completion bonus** (all of a daily/weekly section's
  /// quests claimed). Idempotent by `questbonus:<section>:<periodKey>` — the
  /// per-period id IS the anti-farm cap (one daily bonus per day, one weekly per
  /// week), and it makes the award the **durable one-shot** the chest celebration
  /// fires from: a replay after the section is already settled returns 0 (Codex
  /// review F1/F2). Returns the amount newly credited (0 if already awarded).
  Future<int> awardQuestSectionBonus({
    required String section,
    required String periodKey,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final id = 'questbonus:$section:$periodKey';
    return prefsWriteLock.synchronized(ledgerKey, () async {
      final entries = await ledger();
      if (entries.any((entry) => entry.id == id)) return 0;
      await _save([
        ...entries,
        GemLedgerEntry(
          id: id,
          amount: amount,
          sourceKind: GemLedgerSourceKind.questBonus,
          sourceId: '$section:$periodKey',
          label: label,
          createdAt: now ?? DateTime.now(),
        ),
      ]);
      return amount;
    });
  }

  /// Awards an expedition's gem payout. Idempotent by expedition id — a
  /// settle retried after a crash (or raced from two paths) can never
  /// double-credit.
  Future<int> awardAdventureGems({
    required String expeditionId,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final id = 'adventure:$expeditionId';
    return prefsWriteLock.synchronized(ledgerKey, () async {
      final entries = await ledger();
      if (entries.any((entry) => entry.id == id)) return 0;
      await _save([
        ...entries,
        GemLedgerEntry(
          id: id,
          amount: amount,
          sourceKind: GemLedgerSourceKind.adventure,
          sourceId: expeditionId,
          label: label,
          createdAt: now ?? DateTime.now(),
        ),
      ]);
      return amount;
    });
  }

  /// Awards the general warm-up bonus. Idempotent by **day** — the id is
  /// `warmup:<dayKey>`, so at most one warm-up reward lands per calendar day no
  /// matter how many sessions are saved (the daily cap is the dedup itself).
  Future<int> awardWarmupGems({
    required String dayKey,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final id = 'warmup:$dayKey';
    return prefsWriteLock.synchronized(ledgerKey, () async {
      final entries = await ledger();
      if (entries.any((entry) => entry.id == id)) return 0;
      await _save([
        ...entries,
        GemLedgerEntry(
          id: id,
          amount: amount,
          sourceKind: GemLedgerSourceKind.warmup,
          sourceId: dayKey,
          label: label,
          createdAt: now ?? DateTime.now(),
        ),
      ]);
      return amount;
    });
  }

  /// Auto-banks the Weekly Cache reward. Idempotent by **week** — id
  /// `guildcache:v1:<weekKey>` — so the cache pays out at most once per week; a
  /// reload after banking returns 0 (the durable one-shot the chest fires from).
  /// Versioned (`v1`) so a future pooled-guild rule can change target semantics
  /// without colliding with historical claims. Returns the amount newly credited.
  Future<int> awardGuildCacheGems({
    required String weekKey,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final id = 'guildcache:v1:$weekKey';
    return prefsWriteLock.synchronized(ledgerKey, () async {
      final entries = await ledger();
      if (entries.any((entry) => entry.id == id)) return 0;
      await _save([
        ...entries,
        GemLedgerEntry(
          id: id,
          amount: amount,
          sourceKind: GemLedgerSourceKind.guildCache,
          sourceId: weekKey,
          label: label,
          createdAt: now ?? DateTime.now(),
        ),
      ]);
      return amount;
    });
  }

  /// Whether this week's cache has already banked (the ledger is the source of
  /// truth for the banked state — survives session edits/deletes, Codex F5).
  Future<bool> isGuildCacheBanked(String weekKey) async {
    final id = 'guildcache:v1:$weekKey';
    final entries = await ledger();
    return entries.any((entry) => entry.id == id);
  }

  Future<int> awardDemoGems({
    required String packId,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final timestamp = now ?? DateTime.now();
    return prefsWriteLock.synchronized(ledgerKey, () async {
      final entries = await ledger();
      await _save([
        ...entries,
        GemLedgerEntry(
          id: 'demo:$packId:${timestamp.microsecondsSinceEpoch}',
          amount: amount,
          sourceKind: GemLedgerSourceKind.demoTopUp,
          sourceId: packId,
          label: label,
          createdAt: timestamp,
        ),
      ]);
      return amount;
    });
  }

  Future<void> spendGems({
    required String sourceId,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    // Balance check + write are one critical section so a concurrent spend can't
    // both pass the check against the same balance and overdraw.
    await prefsWriteLock.synchronized(ledgerKey, () async {
      final entries = await ledger();
      final currentBalance = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.amount,
      );
      if (currentBalance < amount) {
        throw StateError('Not enough gems.');
      }
      final timestamp = now ?? DateTime.now();
      await _save([
        ...entries,
        GemLedgerEntry(
          id: 'spend:$sourceId:${timestamp.microsecondsSinceEpoch}',
          amount: -amount,
          sourceKind: GemLedgerSourceKind.cosmeticPurchase,
          sourceId: sourceId,
          label: label,
          createdAt: timestamp,
        ),
      ]);
    });
  }

  Future<void> _save(List<GemLedgerEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ledgerKey,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }
}
