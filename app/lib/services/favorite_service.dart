import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService {
  const FavoriteService();

  static const String _favoriteExerciseIdsKey = 'favorite_exercise_ids';

  Future<Set<String>> getFavoriteExerciseIds() async {
    final preferences = await SharedPreferences.getInstance();
    final favoriteIds =
        preferences.getStringList(_favoriteExerciseIdsKey) ?? const <String>[];

    return {
      for (final favoriteId in favoriteIds)
        if (favoriteId.isNotEmpty) favoriteId,
    };
  }

  Future<bool> isFavoriteExercise(String exerciseId) async {
    final favoriteIds = await getFavoriteExerciseIds();
    return favoriteIds.contains(exerciseId);
  }

  Future<bool> toggleFavoriteExercise(String exerciseId) async {
    if (exerciseId.isEmpty) {
      return false;
    }

    final preferences = await SharedPreferences.getInstance();
    final favoriteIds = <String>{
      for (final favoriteId
          in preferences.getStringList(_favoriteExerciseIdsKey) ??
              const <String>[])
        if (favoriteId.isNotEmpty) favoriteId,
    };

    final isFavorite = favoriteIds.contains(exerciseId);
    if (isFavorite) {
      favoriteIds.remove(exerciseId);
    } else {
      favoriteIds.add(exerciseId);
    }

    final sortedFavoriteIds = favoriteIds.toList()..sort();
    await preferences.setStringList(_favoriteExerciseIdsKey, sortedFavoriteIds);

    return !isFavorite;
  }
}
