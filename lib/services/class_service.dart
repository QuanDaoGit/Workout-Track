import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/class_definitions.dart';
import '../data/muscle_groups.dart';
import '../models/character_class.dart';
import '../models/class_state.dart';
import 'calibration_service.dart';
import 'exercise_catalog_service.dart';
import 'workout_storage_service.dart';

/// Whether the user can change class right now, and why not if not.
enum RespecAvailability { locked, available, cooldown }

class RespecStatus {
  const RespecStatus(this.availability, this.daysRemaining);

  final RespecAvailability availability;
  final int daysRemaining;

  bool get canRespec => availability == RespecAvailability.available;
}

class ClassService {
  static const _stateKey = 'class_state_v1';

  /// Soft lock from signup before the first class change is allowed.
  static const lockDays = 7;

  /// Cooldown between respecs.
  static const cooldownDays = 30;

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

  /// Select a class. Snapshots current volume.
  /// [silent] kept for call-site compatibility.
  Future<void> selectClass(CharacterClass cls, {bool silent = false}) async {
    final volume = await getCurrentVolume(cls);
    final state = ClassState(
      currentClass: cls,
      selectedAt: DateTime.now(),
      volumeSnapshot: volume,
    );
    await _saveState(state);
  }

  /// Switch to a new class. Delegates to [respec] so the cooldown + former-path
  /// history are recorded (kept for call-site compatibility).
  Future<void> switchClass(CharacterClass cls) => respec(cls);

  /// Record a respec: set the new class, append the outgoing class to the
  /// former-paths history, snapshot volume, and start the 30-day cooldown.
  /// Stat history is untouched. No-op guard is the caller's job (UI checks
  /// [respecStatus] first).
  Future<void> respec(CharacterClass cls, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final state = await getState();
    final volume = await getCurrentVolume(cls);
    final formerClasses = <FormerClass>[
      ...?state?.formerClasses,
      if (state != null) FormerClass(clazz: state.currentClass, changedAt: n),
    ];
    await _saveState(
      ClassState(
        currentClass: cls,
        selectedAt: n,
        volumeSnapshot: volume,
        nextRespecAt: n.add(const Duration(days: cooldownDays)),
        formerClasses: formerClasses,
      ),
    );
  }

  /// Current respec availability: locked during the signup soft-lock window,
  /// then on cooldown after each respec, otherwise available.
  Future<RespecStatus> respecStatus({DateTime? now}) async {
    final n = now ?? DateTime.now();

    // Signup soft lock — anchored on the onboarding class-confirm time. Legacy
    // users (no timestamp) predate the field and are past the window.
    final confirmedAt = await CalibrationService().classConfirmedAt();
    if (confirmedAt != null) {
      final lockedUntil = confirmedAt.add(const Duration(days: lockDays));
      if (n.isBefore(lockedUntil)) {
        return RespecStatus(
          RespecAvailability.locked,
          _daysUntil(n, lockedUntil),
        );
      }
    }

    final nextRespec = (await getState())?.nextRespecAt;
    if (nextRespec != null && n.isBefore(nextRespec)) {
      return RespecStatus(
        RespecAvailability.cooldown,
        _daysUntil(n, nextRespec),
      );
    }
    return const RespecStatus(RespecAvailability.available, 0);
  }

  /// Classes the user may respec into. Excludes the current class. (All classes
  /// unlock at level 1; the [level] gate is retained for forward-compatibility.)
  Future<List<CharacterClass>> availableRespecClasses(int level) async {
    final current = await getCurrentClass();
    return [
      for (final c in CharacterClass.values)
        if (c != current && level >= c.unlockLevel) c,
    ];
  }

  int _daysUntil(DateTime now, DateTime target) =>
      (target.difference(now).inHours / 24).ceil();

  /// Calculate total volume in the class's relevant muscle buckets.
  /// Maps each ExerciseLog's detailed primary muscle → canonical bucket,
  /// then checks set membership against [musclesForClass].
  Future<double> getCurrentVolume(CharacterClass cls) async {
    final catalog = await _loadCatalog();
    final sessions = await WorkoutStorageService().getSessions();
    final buckets = musclesForClass(cls);
    var total = 0.0;

    for (final session in sessions) {
      if (session.isOngoing) continue;
      for (final log in session.exercises) {
        final detailed = catalog[log.exerciseId] ?? '';
        final bucket = muscleGroupForDetailed(detailed);
        if (bucket != null && buckets.contains(bucket)) {
          total += log.totalVolume;
        }
      }
    }
    return total;
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
        (item as Map<String, dynamic>)['id'] as String: _firstMuscle(
          item['primaryMuscles'] as List<dynamic>?,
        ),
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
