import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_goal_models.dart';
import '../models/character_class.dart';
import 'body_goal_service.dart';
import 'class_service.dart';

/// One-time migration: maps existing body goal to a class.
/// If no goal is set, defaults to Bruiser.
class ClassMigrationService {
  static const _migrationKey = 'class_migration_v1_done';

  Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) return;

    final goalState = await BodyGoalService().getGoalState();
    final cls = _classFromGoal(goalState?.goal);

    await ClassService().selectClass(cls, silent: true);
    await prefs.setBool(_migrationKey, true);
  }

  CharacterClass _classFromGoal(BodyGoal? goal) => switch (goal) {
    BodyGoal.cut => CharacterClass.assassin,
    BodyGoal.recomp => CharacterClass.bruiser,
    BodyGoal.bulk => CharacterClass.tank,
    null => CharacterClass.bruiser,
  };
}
