import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/loot_item.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/loot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('session milestone unlocks exactly at the new boundary', () async {
    final service = LootService();

    final before = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(29),
    );
    expect(before, isNot(contains('frame_neon')));

    final atBoundary = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(30),
    );
    expect(atBoundary, contains('frame_neon'));
  });

  test('all-stats loot ignores hidden DEF, VIT, and LCK scales', () async {
    final service = LootService();

    final missingVisibleGrowthStat = await service.evaluateUnlocks(
      stats: const {
        'STR': 600,
        'DEF': 600,
        'AGI': 600,
        'END': 10,
        'VIT': 100,
        'LCK': 100,
      },
      sessions: const [],
    );
    expect(missingVisibleGrowthStat, isNot(contains('title_ironbit')));

    final growthStats = await service.evaluateUnlocks(
      stats: const {
        'STR': 600,
        'DEF': 10,
        'AGI': 600,
        'END': 600,
        'VIT': 10,
        'LCK': 0,
      },
      sessions: const [],
    );
    expect(growthStats, contains('title_ironbit'));
  });

  test('owned loot is not re-revealed', () async {
    final service = LootService();

    final first = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(30),
    );
    expect(first, contains('frame_neon'));

    final second = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(30),
    );
    expect(second, isNot(contains('frame_neon')));
  });

  test('frames can be purchased with enough gems', () async {
    final gems = GemService();
    final service = LootService();
    await gems.awardQuestGems(claimKey: 'seed', amount: 500, label: 'Seed');

    await service.purchaseItemWithGems('frame_stone');

    final owned = (await service.getInventory()).map((item) => item.id);
    expect(owned, contains('frame_stone'));
    expect(await gems.balance(), 350);
  });

  test('insufficient gems do not purchase or mutate balance', () async {
    final gems = GemService();
    final service = LootService();
    await gems.awardQuestGems(claimKey: 'seed', amount: 5, label: 'Seed');

    expect(() => service.purchaseItemWithGems('frame_gold'), throwsStateError);
    expect(await gems.balance(), 5);
    final owned = (await service.getInventory()).map((item) => item.id);
    expect(owned, isNot(contains('frame_gold')));
  });

  test('titles are not purchasable with gems', () async {
    final service = LootService();

    expect(
      () => service.purchaseItemWithGems('title_iron_will'),
      throwsStateError,
    );
  });

  test('unequipCategory clears the title but keeps ownership', () async {
    final service = LootService();
    await service.grantItem('title_iron_novice');
    await service.equipItem('title_iron_novice');
    expect(
      (await service.getEquippedItem(LootCategory.titleBadge))?.id,
      'title_iron_novice',
    );

    await service.unequipCategory(LootCategory.titleBadge);
    expect(await service.getEquippedItem(LootCategory.titleBadge), isNull);

    // Earned is forever: still owned, freely re-equippable without re-earning.
    final owned = (await service.getInventory()).map((item) => item.id);
    expect(owned, contains('title_iron_novice'));
    await service.equipItem('title_iron_novice');
    expect(
      (await service.getEquippedItem(LootCategory.titleBadge))?.id,
      'title_iron_novice',
    );
  });

  test('purchased milestone loot is not re-revealed later', () async {
    final gems = GemService();
    final service = LootService();
    await gems.awardQuestGems(claimKey: 'seed', amount: 500, label: 'Seed');
    await service.purchaseItemWithGems('frame_stone');

    final unlocked = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(4),
    );

    expect(unlocked, isNot(contains('frame_stone')));
  });

  test('the first earned title auto-equips from any milestone source', () async {
    final service = LootService();
    expect(await service.getEquippedItem(LootCategory.titleBadge), isNull);

    final granted = await service.evaluateUnlocks(
      stats: const {'STR': 400, 'AGI': 0, 'END': 0},
      sessions: const [],
    );

    expect(granted, contains('title_iron_warden'));
    expect(
      (await service.getEquippedItem(LootCategory.titleBadge))?.id,
      'title_iron_warden',
    );
  });

  test('when several titles cross at once, the rarest is worn', () async {
    final service = LootService();

    final granted = await service.evaluateUnlocks(
      stats: const {'STR': 800, 'AGI': 100, 'END': 100},
      sessions: const [],
    );

    expect(
      granted,
      containsAll(['title_iron_warden', 'title_legend', 'title_s_rank']),
    );
    // s_rank (epic) outranks legend (rare) and iron_warden (uncommon).
    expect(
      (await service.getEquippedItem(LootCategory.titleBadge))?.id,
      'title_s_rank',
    );
  });

  test('a later title never overrides the worn first title', () async {
    final service = LootService();
    await service.evaluateUnlocks(
      stats: const {'STR': 400, 'AGI': 0, 'END': 0},
      sessions: const [],
    );
    expect(
      (await service.getEquippedItem(LootCategory.titleBadge))?.id,
      'title_iron_warden',
    );

    await service.evaluateUnlocks(
      stats: const {'STR': 800, 'AGI': 100, 'END': 100},
      sessions: const [],
    );

    expect(
      (await service.getEquippedItem(LootCategory.titleBadge))?.id,
      'title_iron_warden',
    );
  });

  test('a user who cleared to No Title is not re-auto-equipped', () async {
    final service = LootService();
    await service.evaluateUnlocks(
      stats: const {'STR': 400, 'AGI': 0, 'END': 0},
      sessions: const [],
    );
    await service.unequipCategory(LootCategory.titleBadge);
    expect(await service.getEquippedItem(LootCategory.titleBadge), isNull);

    await service.evaluateUnlocks(
      stats: const {'STR': 800, 'AGI': 100, 'END': 100},
      sessions: const [],
    );

    expect(await service.getEquippedItem(LootCategory.titleBadge), isNull);
  });

  test('frames unlock in strict rarity order on the sessions axis', () async {
    final service = LootService();

    await service.evaluateUnlocks(stats: const {}, sessions: _sessions(13));
    var owned = (await service.getInventory()).map((i) => i.id).toSet();
    expect(owned, isNot(contains('frame_silver')));
    expect(owned, isNot(contains('frame_gold')));

    // silver (14) lands before gold (22) — the inversion is fixed.
    await service.evaluateUnlocks(stats: const {}, sessions: _sessions(14));
    owned = (await service.getInventory()).map((i) => i.id).toSet();
    expect(owned, contains('frame_silver'));
    expect(owned, isNot(contains('frame_gold')));

    await service.evaluateUnlocks(stats: const {}, sessions: _sessions(22));
    owned = (await service.getInventory()).map((i) => i.id).toSet();
    expect(owned, contains('frame_gold'));
  });

  test('each trainable muscle group grants its title at 8000 volume', () async {
    const expected = {
      'Chest': 'title_golem_breaker',
      'Back': 'title_wraith_hunter',
      'Shoulders': 'title_skybreaker',
      'Arms': 'title_gauntlet',
      'Legs': 'title_colossus',
      'Core': 'title_keystone',
    };
    for (final entry in expected.entries) {
      SharedPreferences.setMockInitialValues({});
      final unlocked = await LootService().evaluateUnlocks(
        stats: const {},
        sessions: [_muscleSession(entry.key, 8000)],
      );
      expect(unlocked, contains(entry.value), reason: '${entry.key} title');
    }
  });

  test('The Grinder volume title re-tiers to 100k', () async {
    final service = LootService();

    final under = await service.evaluateUnlocks(
      stats: const {},
      sessions: [_volumeSession(60000)],
    );
    expect(under, isNot(contains('title_grinder')));

    final over = await service.evaluateUnlocks(
      stats: const {},
      sessions: [_volumeSession(120000)],
    );
    expect(over, contains('title_grinder'));
  });
}

List<WorkoutSession> _sessions(int count) => [
  for (var i = 0; i < count; i++)
    WorkoutSession(
      id: 's$i',
      date: DateTime(2026, 1, 1 + i),
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 45,
      actualDurationSeconds: 45 * 60,
      estimatedCalories: 0,
      exercises: const [
        ExerciseLog(
          exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
          exerciseName: 'Bench Press',
          sets: [SetEntry(weight: 40, reps: 8)],
        ),
      ],
    ),
];

// A single session crediting [volume] kg to one [group]. The exercise id is
// unknown to the catalog, so volumeForMuscle falls back to target attribution
// (full volume → the lone target group).
WorkoutSession _muscleSession(String group, double volume) => WorkoutSession(
  id: 'muscle-$group',
  date: DateTime(2026, 3, 1),
  muscleGroup: group,
  targetMuscleGroups: [group],
  targetDurationMinutes: 45,
  actualDurationSeconds: 45 * 60,
  estimatedCalories: 0,
  exercises: [
    ExerciseLog(
      exerciseId: 'custom-${group.toLowerCase()}',
      exerciseName: group,
      sets: [SetEntry(weight: volume, reps: 1)],
    ),
  ],
);

// A single session contributing [volume] kg to lifetime volume only (targets
// Full Body, so it credits no per-muscle title).
WorkoutSession _volumeSession(double volume) => WorkoutSession(
  id: 'vol-${volume.toInt()}',
  date: DateTime(2026, 4, 1),
  muscleGroup: 'Full Body',
  targetMuscleGroups: const ['Full Body'],
  targetDurationMinutes: 45,
  actualDurationSeconds: 45 * 60,
  estimatedCalories: 0,
  exercises: [
    ExerciseLog(
      exerciseId: 'custom-fullbody',
      exerciseName: 'Full Body',
      sets: [SetEntry(weight: volume, reps: 1)],
    ),
  ],
);
