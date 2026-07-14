import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/programs_library.dart';
import '../models/program_models.dart';

/// Persists user-chosen, permanent exercise swaps for a program. A swap replaces
/// one prescribed lift with another (e.g. Barbell Squat → Goblet Squat) and is
/// scoped **per program**, so it applies to every day that prescribes the
/// original. Swaps are user preferences: they live in their own key and are not
/// cleared by starting or quitting a program.
///
/// Storage shape (one JSON object under [_key]):
/// `{ programId: { originalExerciseId: replacementExerciseId } }`.
class ProgramCustomizationService {
  ProgramCustomizationService();

  static const _key = 'program_exercise_swaps_v1';

  /// The originalId → replacementId map for [programId] (empty if none).
  Future<Map<String, String>> swapsFor(String programId) async {
    final prefs = await SharedPreferences.getInstance();
    return _programSwaps(prefs, programId);
  }

  /// Records a permanent swap of [originalId] → [replacementId] for [programId].
  /// A no-op self-swap ([replacementId] == [originalId]) clears the swap instead.
  Future<void> setSwap(
    String programId,
    String originalId,
    String replacementId,
  ) async {
    if (replacementId == originalId) {
      await removeSwap(programId, originalId);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final all = _loadAll(prefs);
    final forProgram = Map<String, String>.from(all[programId] ?? const {});
    forProgram[originalId] = replacementId;
    all[programId] = forProgram;
    await _saveAll(prefs, all);
  }

  /// Reverts [originalId] back to its prescribed lift for [programId].
  Future<void> removeSwap(String programId, String originalId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _loadAll(prefs);
    final forProgram = Map<String, String>.from(all[programId] ?? const {});
    if (forProgram.remove(originalId) == null) return;
    if (forProgram.isEmpty) {
      all.remove(programId);
    } else {
      all[programId] = forProgram;
    }
    await _saveAll(prefs, all);
  }

  /// Clears every swap for [programId].
  Future<void> clearSwaps(String programId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _loadAll(prefs);
    if (all.remove(programId) == null) return;
    await _saveAll(prefs, all);
  }

  /// [day] with [programId]'s swaps applied — the loadout the user actually
  /// trains. A no-op for rest days or when nothing is swapped.
  Future<ProgramDay> effectiveDay(String programId, ProgramDay day) async {
    final swaps = await swapsFor(programId);
    return applyProgramSwaps(day, swaps);
  }

  Map<String, String> _programSwaps(SharedPreferences prefs, String programId) {
    final entry = _loadAll(prefs)[programId];
    return entry == null ? const {} : Map<String, String>.from(entry);
  }

  Map<String, Map<String, String>> _loadAll(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (programId, swaps) => MapEntry(
        programId,
        (swaps as Map<String, dynamic>).map(
          (original, replacement) => MapEntry(original, replacement as String),
        ),
      ),
    );
  }

  Future<void> _saveAll(
    SharedPreferences prefs,
    Map<String, Map<String, String>> all,
  ) async {
    if (all.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, jsonEncode(all));
  }
}
