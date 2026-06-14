import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Session-scoped, **ephemeral** program-exercise swaps chosen on the Start
/// screen (effectiveOriginalId → replacementId), keyed by the ongoing session
/// id. Applied by [ProgramService.prescriptionsForOngoingSession] so a
/// force-kill / resume keeps a swapped lift paired with its prescribed sets×reps
/// (Codex plan-review F1). Distinct from the **persistent** per-program swaps in
/// `ProgramCustomizationService`; cleared when the ongoing session row is
/// removed/finalized (Codex plan-review F3).
class OngoingProgramSwapService {
  static const String _key = 'ongoing_program_swaps_v1';

  Future<Map<String, Map<String, String>>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        entry.key: {
          for (final swap in (entry.value as Map<String, dynamic>).entries)
            swap.key: swap.value as String,
        },
    };
  }

  Future<void> _write(Map<String, Map<String, String>> all) async {
    final prefs = await SharedPreferences.getInstance();
    if (all.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(all));
    }
  }

  /// Record (or clear, when [swaps] is empty) the swap map for [sessionId].
  Future<void> setSwaps(String sessionId, Map<String, String> swaps) async {
    final all = await _all();
    if (swaps.isEmpty) {
      all.remove(sessionId);
    } else {
      all[sessionId] = Map.of(swaps);
    }
    await _write(all);
  }

  Future<Map<String, String>> swapsFor(String sessionId) async {
    final all = await _all();
    return all[sessionId] ?? const {};
  }

  /// Drop the swap row for a finalized/removed ongoing session.
  Future<void> clear(String sessionId) async {
    final all = await _all();
    if (all.remove(sessionId) != null) await _write(all);
  }
}
