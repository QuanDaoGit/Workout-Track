import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/class_definitions.dart';
import '../models/character_class.dart';
import '../models/class_battle_carryover.dart';
import '../models/class_state.dart';
import 'exercise_catalog_service.dart';
import 'workout_storage_service.dart';

class ClassService {
  static const _stateKey = 'class_state_v1';
  static const _carryoverKey = 'class_carryover_v1';
  static const _pendingRevealKey = 'class_ultimate_pending_reveal';

  /// Minimum volume threshold when snapshot is 0.
  static const _minUltimateThreshold = 1000.0;

  Future<ClassState?> getState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) return null;
    return ClassState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<CharacterClass> getCurrentClass() async {
    final state = await getState();
    return state?.currentClass ?? CharacterClass.bruiser;
  }

  /// Select a class. Snapshots current volume and unlocks primary ability.
  /// [silent] = true for migration (no pending reveal flag).
  Future<void> selectClass(CharacterClass cls, {bool silent = false}) async {
    final volume = await getCurrentVolume(cls);
    final primary = primaryAbility(cls);
    final state = ClassState(
      currentClass: cls,
      selectedAt: DateTime.now(),
      volumeSnapshot: volume,
      unlockedAbilityIds: {primary.id},
    );
    await _saveState(state);
  }

  /// Switch to a new class. Locks all old abilities, resets snapshot.
  Future<void> switchClass(CharacterClass cls) async {
    final volume = await getCurrentVolume(cls);
    final primary = primaryAbility(cls);
    final state = ClassState(
      currentClass: cls,
      selectedAt: DateTime.now(),
      volumeSnapshot: volume,
      unlockedAbilityIds: {primary.id},
    );
    await _saveState(state);
  }

  /// Calculate total volume in the class's relevant muscle groups.
  Future<double> getCurrentVolume(CharacterClass cls) async {
    final catalog = await _loadCatalog();
    final sessions = await WorkoutStorageService().getSessions();
    final muscles = musclesForClass(cls);
    var total = 0.0;

    for (final session in sessions) {
      if (session.isOngoing) continue;
      for (final log in session.exercises) {
        final muscle = catalog[log.exerciseId] ?? '';
        if (muscles.contains(muscle.toLowerCase())) {
          total += log.totalVolume;
        }
      }
    }
    return total;
  }

  /// Volume required to unlock ultimate = max(snapshot * 2, minThreshold).
  Future<double> getRequiredVolumeForUltimate() async {
    final state = await getState();
    if (state == null) return _minUltimateThreshold;
    final snapshot = state.volumeSnapshot;
    if (snapshot <= 0) return _minUltimateThreshold;
    return snapshot * 2.0;
  }

  /// Progress toward ultimate unlock [0..1].
  Future<double> getUltimateProgress() async {
    final state = await getState();
    if (state == null) return 0.0;

    final currentVol = await getCurrentVolume(state.currentClass);
    final snapshot = state.volumeSnapshot;
    final required = snapshot <= 0 ? _minUltimateThreshold : snapshot * 2.0;
    final delta = required - snapshot;
    if (delta <= 0) return 1.0;

    return ((currentVol - snapshot) / delta).clamp(0.0, 1.0);
  }

  /// Whether the ultimate ability is unlocked.
  Future<bool> isUltimateUnlocked() async {
    final state = await getState();
    if (state == null) return false;
    final ultimate = ultimateAbility(state.currentClass);
    return state.unlockedAbilityIds.contains(ultimate.id);
  }

  /// Check and unlock ultimate if threshold crossed.
  /// Returns true if this call triggered the unlock.
  /// Sets pending reveal flag for cinematic on next app open.
  Future<bool> checkAndUnlockUltimate() async {
    final state = await getState();
    if (state == null) return false;

    final ultimate = ultimateAbility(state.currentClass);
    if (state.unlockedAbilityIds.contains(ultimate.id)) return false;

    final progress = await getUltimateProgress();
    if (progress < 1.0) return false;

    // Unlock the ultimate
    final updated = state.copyWith(
      unlockedAbilityIds: {...state.unlockedAbilityIds, ultimate.id},
    );
    await _saveState(updated);

    // Set pending reveal flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingRevealKey, true);

    return true;
  }

  /// Whether a specific ability is unlocked (used by battle system).
  Future<bool> hasAbility(String abilityId) async {
    final state = await getState();
    if (state == null) return false;
    return state.unlockedAbilityIds.contains(abilityId);
  }

  /// Check if there's a pending ultimate reveal.
  Future<bool> hasPendingUltimateReveal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingRevealKey) ?? false;
  }

  /// Clear the pending ultimate reveal flag.
  Future<void> clearPendingUltimateReveal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRevealKey);
  }

  /// Read battle carryover state.
  Future<ClassBattleCarryover> getCarryover() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_carryoverKey);
    if (raw == null || raw.isEmpty) return const ClassBattleCarryover();
    return ClassBattleCarryover.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Persist battle carryover state.
  Future<void> updateCarryover(ClassBattleCarryover carryover) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_carryoverKey, jsonEncode(carryover.toJson()));
  }

  Future<void> _saveState(ClassState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(state.toJson()));
  }

  /// Load exercise id → primary muscle mapping (same pattern as StatEngine).
  Future<Map<String, String>> _loadCatalog() async {
    final raw = await rootBundle.loadString('assets/exercises.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final result = <String, String>{
      for (final item in decoded)
        (item as Map<String, dynamic>)['id'] as String:
            _firstMuscle(item['primaryMuscles'] as List<dynamic>?),
    };
    final custom = await ExerciseCatalogService().getCustomExercises();
    for (final e in custom) {
      result[e.id] = e.primaryMuscle ?? '';
    }
    return result;
  }

  String _firstMuscle(List<dynamic>? muscles) {
    if (muscles == null || muscles.isEmpty) return '';
    return (muscles.first as String?) ?? '';
  }
}
