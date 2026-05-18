import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/class_definitions.dart';
import '../models/character_class.dart';
import '../models/class_state.dart';
import 'exercise_catalog_service.dart';
import 'workout_storage_service.dart';

class ClassService {
  static const _stateKey = 'class_state_v1';

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

  /// Switch to a new class. Resets snapshot.
  Future<void> switchClass(CharacterClass cls) async {
    final volume = await getCurrentVolume(cls);
    final state = ClassState(
      currentClass: cls,
      selectedAt: DateTime.now(),
      volumeSnapshot: volume,
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
