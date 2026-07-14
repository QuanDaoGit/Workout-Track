import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_models.dart';

class CustomExerciseService {
  static const _key = 'custom_exercises_v1';

  /// Primary muscle mapping from canonical muscle group names.
  /// Case-insensitive so legacy lowercase values still resolve.
  static String primaryMuscleFor(String muscleGroup) =>
      switch (muscleGroup.toLowerCase()) {
        'chest' => 'chest',
        'back' => 'lats',
        'legs' => 'quadriceps',
        'shoulders' => 'shoulders',
        'arms' => 'biceps',
        'core' => 'abdominals',
        'full body' => 'chest',
        _ => 'chest',
      };

  Future<List<Exercise>> getCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [for (final e in list) Exercise.fromJson(e as Map<String, dynamic>)];
  }

  Future<void> saveCustomExercise({
    required String name,
    required String muscleGroup,
    required String exerciseType,
    String? userNote,
  }) async {
    final exercises = await getCustomExercises();
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final exercise = Exercise(
      id: id,
      name: name.trim(),
      level: 'custom',
      images: const [],
      instructions: const [],
      isCustom: true,
      createdAt: DateTime.now(),
      userNote: userNote?.trim(),
      muscleGroup: muscleGroup,
      exerciseType: exerciseType,
      primaryMuscle: primaryMuscleFor(muscleGroup),
    );
    exercises.add(exercise);
    await _persist(exercises);
  }

  Future<void> updateCustomExercise(
    String id, {
    String? name,
    String? muscleGroup,
    String? exerciseType,
    String? userNote,
  }) async {
    final exercises = await getCustomExercises();
    final index = exercises.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final existing = exercises[index];
    final updated = existing.copyWith(
      name: name?.trim() ?? existing.name,
      muscleGroup: muscleGroup ?? existing.muscleGroup,
      exerciseType: exerciseType ?? existing.exerciseType,
      userNote: userNote ?? existing.userNote,
      primaryMuscle: muscleGroup != null
          ? primaryMuscleFor(muscleGroup)
          : existing.primaryMuscle,
    );
    exercises[index] = updated;
    await _persist(exercises);
  }

  Future<void> deleteCustomExercise(String id) async {
    final exercises = await getCustomExercises();
    exercises.removeWhere((e) => e.id == id);
    await _persist(exercises);
  }

  /// Case-insensitive name check against all exercises (built-in + custom).
  /// [excludeId] allows edit mode to skip the exercise being edited.
  Future<bool> isNameDuplicate(String name, {String? excludeId}) async {
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    // Check custom exercises
    final custom = await getCustomExercises();
    for (final e in custom) {
      if (e.id == excludeId) continue;
      if (e.name.toLowerCase() == trimmed) return true;
    }

    // Check built-in exercises
    final builtIn = await _loadBuiltInNames();
    return builtIn.contains(trimmed);
  }

  Future<Set<String>> _loadBuiltInNames() async {
    final jsonStr = await rootBundle.loadString('assets/exercises.json');
    final data = jsonDecode(jsonStr) as List<dynamic>;
    return {
      for (final e in data)
        ((e as Map<String, dynamic>)['name'] as String? ?? '').toLowerCase(),
    };
  }

  Future<void> _persist(List<Exercise> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(exercises.map((e) => e.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
