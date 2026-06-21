import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/services/body_goal_service.dart';
import 'package:workout_track/services/class_migration_service.dart';
import 'package:workout_track/services/class_service.dart';

/// Boot-sequence step 3 (main.dart): the one-time body-goal → class migration.
/// The load-bearing guarantees are the goal→class map and **idempotency** — a
/// second run (or a run after the user has since changed class) must NOT
/// re-assign. There was no coverage for this migration before.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<CharacterClass> migrateFromGoal(BodyGoal? goal) async {
    if (goal != null) await BodyGoalService().setGoal(goal);
    await ClassMigrationService().migrateIfNeeded();
    return ClassService().getCurrentClass();
  }

  test('cut → Assassin', () async {
    expect(await migrateFromGoal(BodyGoal.cut), CharacterClass.assassin);
  });

  test('recomp → Bruiser', () async {
    expect(await migrateFromGoal(BodyGoal.recomp), CharacterClass.bruiser);
  });

  test('bulk → Tank', () async {
    expect(await migrateFromGoal(BodyGoal.bulk), CharacterClass.tank);
  });

  test('no goal set → defaults to Bruiser', () async {
    expect(await migrateFromGoal(null), CharacterClass.bruiser);
  });

  test('sets the done flag so it is a one-time migration', () async {
    await ClassMigrationService().migrateIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('class_migration_v1_done'), isTrue);
  });

  test('idempotent: a second run never overrides a user class change', () async {
    // Migrate from a "cut" goal → Assassin, then the user deliberately respecs.
    await BodyGoalService().setGoal(BodyGoal.cut);
    await ClassMigrationService().migrateIfNeeded();
    expect(await ClassService().getCurrentClass(), CharacterClass.assassin);

    await ClassService().selectClass(CharacterClass.tank);

    // A later boot runs the migration again — it must be a no-op (gated by the
    // done flag), so the user's chosen Tank survives. A migration that re-ran
    // would clobber it back to Assassin.
    await ClassMigrationService().migrateIfNeeded();
    expect(await ClassService().getCurrentClass(), CharacterClass.tank);
  });

  test('the done flag dominates a later body-goal change', () async {
    // First migration derives Assassin from a "cut" goal and sets the flag.
    await BodyGoalService().setGoal(BodyGoal.cut);
    await ClassMigrationService().migrateIfNeeded();
    expect(await ClassService().getCurrentClass(), CharacterClass.assassin);

    // The user later changes their body goal to bulk (which maps to Tank). The
    // migration must NOT re-fire and re-derive — the gate dominates, so the
    // class stays Assassin. Without the gate it would flip to Tank.
    await BodyGoalService().setGoal(BodyGoal.bulk);
    await ClassMigrationService().migrateIfNeeded();
    expect(await ClassService().getCurrentClass(), CharacterClass.assassin);
  });
}
