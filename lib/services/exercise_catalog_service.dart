import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/workout_models.dart';
import 'custom_exercise_service.dart';

/// Centralized service for loading the full exercise catalog (built-in + custom).
/// Caches the built-in catalog after first load. Custom exercises are always
/// fetched fresh (they can change between calls).
class ExerciseCatalogService {
  static List<Exercise>? _builtInCache;

  final CustomExerciseService _customService = CustomExerciseService();

  /// Returns the merged catalog: built-in exercises + custom exercises.
  Future<List<Exercise>> getFullCatalog() async {
    final builtIn = await getBuiltInCatalog();
    final custom = await _customService.getCustomExercises();
    return [...builtIn, ...custom];
  }

  /// Returns only the built-in exercises from assets/exercises.json (cached).
  Future<List<Exercise>> getBuiltInCatalog() async {
    if (_builtInCache != null) return _builtInCache!;
    final jsonStr = await rootBundle.loadString('assets/exercises.json');
    final data = jsonDecode(jsonStr) as List<dynamic>;
    _builtInCache = [
      for (final e in data) Exercise.fromJson(e as Map<String, dynamic>),
    ];
    return _builtInCache!;
  }

  /// Returns only custom exercises.
  Future<List<Exercise>> getCustomExercises() =>
      _customService.getCustomExercises();

  /// Lookup a single exercise by ID from the full catalog.
  Future<Exercise?> getExerciseById(String id) async {
    final catalog = await getFullCatalog();
    for (final e in catalog) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Call after creating, editing, or deleting a custom exercise.
  /// Built-in cache is preserved; custom exercises are always re-fetched.
  static void invalidateCache() {
    // Built-in cache doesn't need invalidation since exercises.json is static.
    // Custom exercises are fetched fresh each time via SharedPreferences.
    // This method exists for future use if we add full-catalog caching.
  }
}
