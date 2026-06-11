import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/gem_ledger_entry.dart';

class GemService {
  static const String ledgerKey = 'gem_ledger_v1';

  Future<int> balance() async {
    final entries = await ledger();
    return entries.fold<int>(0, (sum, entry) => sum + entry.amount);
  }

  Future<List<GemLedgerEntry>> ledger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ledgerKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
      for (final entry in decoded)
        if (entry is Map)
          GemLedgerEntry.fromJson(Map<String, dynamic>.from(entry)),
    ];
  }

  Future<int> awardQuestGems({
    required String claimKey,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final id = 'quest:$claimKey';
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
  }

  Future<int> awardDemoGems({
    required String packId,
    required int amount,
    required String label,
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final timestamp = now ?? DateTime.now();
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
  }

  Future<void> _save(List<GemLedgerEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ledgerKey,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }
}
