import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_models.dart';

/// Coarse classification used to pick a rep target for progressive overload.
enum ExerciseKind { compound, isolation, bodyweight }

/// Resolves an [ExerciseKind] for an exercise and caches the answer per-id so
/// it never flips. Hybrid moves (bodyweight first, weighted vest later) keep
/// their original kind — the rep target stays at the safer default.
///
/// Resolution order on a cache miss:
///   1. If any historical set has `weight == 0` → bodyweight.
///   2. Else if [mechanic] == `'compound'` → compound.
///   3. Else if [mechanic] == `'isolation'` → isolation.
///   4. Else if [equipment] == `'body only'` → bodyweight.
///   5. Default → compound.
class ExerciseKindCache {
  ExerciseKindCache._();
  static final ExerciseKindCache instance = ExerciseKindCache._();

  static const String _key = 'exercise_kind_cache_v1';

  Map<String, String>? _memo;

  Future<Map<String, String>> _read() async {
    if (_memo != null) return _memo!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _memo = {};
      return _memo!;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _memo = decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      _memo = {};
    }
    return _memo!;
  }

  Future<void> _write(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(map));
    _memo = map;
  }

  /// Returns the kind, persisting the answer on first call. [observedSets] may
  /// be null when classifying an exercise the user has never logged.
  Future<ExerciseKind> classify(
    String exerciseId, {
    String? mechanic,
    String? equipment,
    List<SetEntry>? observedSets,
  }) async {
    final cache = await _read();
    final cached = cache[exerciseId];
    if (cached != null) {
      final kind = _decode(cached);
      if (kind != null) return kind;
    }

    final resolved = _resolve(
      mechanic: mechanic,
      equipment: equipment,
      observedSets: observedSets,
    );
    cache[exerciseId] = resolved.name;
    await _write(cache);
    return resolved;
  }

  ExerciseKind _resolve({
    required String? mechanic,
    required String? equipment,
    required List<SetEntry>? observedSets,
  }) {
    if (observedSets != null &&
        observedSets.any((s) => s.weight == 0 && s.reps > 0)) {
      return ExerciseKind.bodyweight;
    }
    final mech = mechanic?.toLowerCase();
    if (mech == 'compound') return ExerciseKind.compound;
    if (mech == 'isolation') return ExerciseKind.isolation;
    if (equipment?.toLowerCase() == 'body only') return ExerciseKind.bodyweight;
    return ExerciseKind.compound;
  }

  ExerciseKind? _decode(String name) {
    for (final kind in ExerciseKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  /// Test-only reset of the in-memory memo so reloads from prefs are honored.
  void resetForTest() => _memo = null;
}
