# Exercise Picker Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Curated/full-list toggle, equipment + sub-muscle filters, validated curated data, and selection-preservation fixes for the pre-workout exercise picker.

**Architecture:** A new pure pool builder (`lib/data/exercise_pool.dart`) owns candidate-list assembly/ordering/filtering for both curated and full-catalog modes; `start_workout.dart` becomes a thin consumer rendering via a lazy sliver list. Curated data gets a drift-guard test that forces the prune/declare cleanup. Spec: `docs/superpowers/plans/2026-06-10-exercise-picker-overhaul.md`.

**Tech Stack:** Flutter/Dart, SharedPreferences, flutter_test. No new dependencies.

**Conventions for every task:** the working tree contains unrelated uncommitted work — `git add` ONLY the files named in the commit step, never `git add -A`. `flutter analyze` baseline: 12 pre-existing errors in avatar/profile test files (`activation_handoff_test`, `character_service_test`, `name_screen_test`, `profile_service_test`, `start_gate_navigation_test`) — zero NEW issues is the bar.

---

### Task 1: `Exercise.category` field (additive)

**Files:**
- Modify: `lib/models/workout_models.dart` (Exercise class, ~lines 3–134)
- Test: `test/exercise_category_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/workout_models.dart';

void main() {
  test('fromJson parses category', () {
    final e = Exercise.fromJson(const {
      'id': 'x', 'name': 'X', 'level': 'beginner', 'images': <String>[],
      'category': 'stretching',
    });
    expect(e.category, 'stretching');
  });

  test('category defaults to null and stays out of toJson when unset', () {
    final e = Exercise.fromJson(const {
      'id': 'x', 'name': 'X', 'level': 'beginner', 'images': <String>[],
    });
    expect(e.category, isNull);
    expect(e.toJson().containsKey('category'), isFalse);
  });

  test('toJson round-trips category when set', () {
    const e = Exercise(
      id: 'x', name: 'X', level: 'beginner', images: [], category: 'strength',
    );
    expect(Exercise.fromJson(e.toJson()).category, 'strength');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/exercise_category_test.dart`
Expected: FAIL — `No named parameter with the name 'category'` / getter not defined.

- [ ] **Step 3: Implement** — in `Exercise`: add `this.category,` to the main constructor parameter list; add field `final String? category;` next to `equipment`; in `copyWith` add `String? category,` parameter and `category: category ?? this.category,`; in `toJson` add `if (category != null) 'category': category,`; in `fromJson` add `category: json['category'] as String?,`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/exercise_category_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/workout_models.dart test/exercise_category_test.dart
git commit -m "feat(model): parse exercise category from catalog"
```

---

### Task 2: Pool helpers — equipment buckets + sub-muscle labels

**Files:**
- Create: `lib/data/exercise_pool.dart`
- Test: `test/exercise_pool_test.dart` (create)

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/exercise_pool.dart';
import 'package:workout_track/models/workout_models.dart';

Exercise ex(String id, {String? primary, String? equipment, String level = 'beginner',
    String? category, bool custom = false, String? muscleGroup, String? name}) {
  return Exercise(id: id, name: name ?? id.replaceAll('_', ' '), level: level,
      images: const [], primaryMuscle: primary, equipment: equipment,
      category: category, isCustom: custom, muscleGroup: muscleGroup);
}

void main() {
  group('equipmentBucket', () {
    test('maps raw catalog values to the 8 chips', () {
      expect(equipmentBucket('barbell'), 'Barbell');
      expect(equipmentBucket('e-z curl bar'), 'Barbell');
      expect(equipmentBucket('dumbbell'), 'Dumbbell');
      expect(equipmentBucket('machine'), 'Machine');
      expect(equipmentBucket('cable'), 'Cable');
      expect(equipmentBucket('body only'), 'Bodyweight');
      expect(equipmentBucket('kettlebells'), 'Kettlebell');
      expect(equipmentBucket('bands'), 'Bands');
      expect(equipmentBucket('medicine ball'), 'Other');
      expect(equipmentBucket(null), 'Other');
    });
  });

  group('subMuscleLabel', () {
    test('special cases and default capitalization', () {
      expect(subMuscleLabel('quadriceps'), 'Quads');
      expect(subMuscleLabel('middle back'), 'Mid Back');
      expect(subMuscleLabel('lower back'), 'Lower Back');
      expect(subMuscleLabel('abdominals'), 'Abs');
      expect(subMuscleLabel('biceps'), 'Biceps');
      expect(subMuscleLabel('lats'), 'Lats');
    });
  });

  group('availableSubMuscles', () {
    test('returns distinct primaries in anatomical order', () {
      final pool = [ex('a', primary: 'triceps'), ex('b', primary: 'biceps'),
          ex('c', primary: 'biceps'), ex('d', primary: null)];
      expect(availableSubMuscles(pool), ['biceps', 'triceps']);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/exercise_pool_test.dart` → FAIL (file/symbols missing).

- [ ] **Step 3: Create `lib/data/exercise_pool.dart`**

```dart
import '../models/workout_models.dart';
import 'curated_exercises.dart';
import 'muscle_groups.dart';

/// Display order for the equipment filter chips.
const List<String> kEquipmentBuckets = [
  'Barbell', 'Dumbbell', 'Machine', 'Cable',
  'Bodyweight', 'Kettlebell', 'Bands', 'Other',
];

/// Maps a raw catalog `equipment` value onto one of [kEquipmentBuckets].
String equipmentBucket(String? raw) => switch (raw) {
  'barbell' || 'e-z curl bar' => 'Barbell',
  'dumbbell' => 'Dumbbell',
  'machine' => 'Machine',
  'cable' => 'Cable',
  'body only' => 'Bodyweight',
  'kettlebells' => 'Kettlebell',
  'bands' => 'Bands',
  _ => 'Other',
};

/// Anatomical display order for sub-muscle chips (raw primaryMuscle values).
const List<String> kSubMuscleOrder = [
  'chest', 'lats', 'middle back', 'lower back', 'traps',
  'shoulders', 'neck', 'biceps', 'triceps', 'forearms',
  'quadriceps', 'hamstrings', 'glutes', 'calves', 'abductors', 'adductors',
  'abdominals',
];

/// Chip label for a raw primaryMuscle value.
String subMuscleLabel(String raw) => switch (raw) {
  'quadriceps' => 'Quads',
  'middle back' => 'Mid Back',
  'lower back' => 'Lower Back',
  'abdominals' => 'Abs',
  _ => '${raw[0].toUpperCase()}${raw.substring(1)}',
};

/// Distinct primaryMuscle values present in [pool], in [kSubMuscleOrder].
/// The picker shows the sub-muscle filter row only when this has >= 2 entries.
List<String> availableSubMuscles(List<Exercise> pool) {
  final seen = <String>{
    for (final e in pool)
      if (e.primaryMuscle != null) e.primaryMuscle!,
  };
  return [for (final m in kSubMuscleOrder) if (seen.contains(m)) m];
}
```

- [ ] **Step 4: Run to verify pass** — `flutter test test/exercise_pool_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/exercise_pool.dart test/exercise_pool_test.dart
git commit -m "feat(picker): equipment bucketing and sub-muscle helpers"
```

---

### Task 3: `buildCandidatePool` — curated + full modes, ordering, filters, selection preservation

**Files:**
- Modify: `lib/data/exercise_pool.dart`
- Test: `test/exercise_pool_test.dart` (extend)

- [ ] **Step 1: Append the failing tests** (to `main()` in `test/exercise_pool_test.dart`; uses curated ids that survive Task 6's prune — `Barbell_Bench_Press_-_Medium_Grip`, `Dumbbell_Bench_Press` are Chest-curated; `Wide-Grip_Lat_Pulldown` is Back-curated)

```dart
  group('buildCandidatePool — curated mode', () {
    final catalog = [
      ex('Barbell_Bench_Press_-_Medium_Grip', primary: 'chest', equipment: 'barbell'),
      ex('Dumbbell_Bench_Press', primary: 'chest', equipment: 'dumbbell'),
      ex('Wide-Grip_Lat_Pulldown', primary: 'lats', equipment: 'cable'),
      ex('Some_Obscure_Chest_Move', primary: 'chest', equipment: 'machine'),
      ex('my_custom', primary: null, custom: true, muscleGroup: 'Chest'),
    ];

    test('curated mode = curated ids + custom + pinned only', () {
      final pool = buildCandidatePool(
          catalog: catalog, targetGroups: ['Chest'], fullCatalog: false);
      final ids = pool.exercises.map((e) => e.id).toList();
      expect(ids, contains('Barbell_Bench_Press_-_Medium_Grip'));
      expect(ids, contains('my_custom'));
      expect(ids, isNot(contains('Some_Obscure_Chest_Move'))); // not curated
      expect(ids, isNot(contains('Wide-Grip_Lat_Pulldown'))); // wrong bucket
      expect(pool.primaryCount, pool.exercises.length);
    });

    test('pinned ids lead in pinned order', () {
      final pool = buildCandidatePool(
          catalog: catalog, targetGroups: ['Chest'], fullCatalog: false,
          pinnedIds: ['Dumbbell_Bench_Press', 'Barbell_Bench_Press_-_Medium_Grip']);
      expect(pool.exercises[0].id, 'Dumbbell_Bench_Press');
      expect(pool.exercises[1].id, 'Barbell_Bench_Press_-_Medium_Grip');
    });

    test('usage counts float unpinned exercises up', () {
      final pool = buildCandidatePool(
          catalog: catalog, targetGroups: ['Chest'], fullCatalog: false,
          usageCounts: {'Dumbbell_Bench_Press': 5});
      expect(pool.exercises.first.id, 'Dumbbell_Bench_Press');
    });
  });

  group('buildCandidatePool — full mode', () {
    final catalog = [
      ex('Barbell_Bench_Press_-_Medium_Grip', primary: 'chest', equipment: 'barbell'),
      ex('Some_Obscure_Chest_Move', primary: 'chest', equipment: 'machine'),
      ex('A_Chest_Stretch', primary: 'chest', category: 'stretching'),
      ex('A_Cardio_Thing', primary: 'quadriceps', category: 'cardio'),
      ex('Leg_Thing', primary: 'quadriceps'),
    ];

    test('full mode adds bucket-matched tail, alphabetical, after primaryCount', () {
      final pool = buildCandidatePool(
          catalog: catalog, targetGroups: ['Chest'], fullCatalog: true);
      final ids = pool.exercises.map((e) => e.id).toList();
      expect(ids, contains('Some_Obscure_Chest_Move'));
      expect(ids, isNot(contains('Leg_Thing')));
      expect(pool.primaryCount, lessThan(pool.exercises.length));
      expect(ids.indexOf('Some_Obscure_Chest_Move'),
          greaterThanOrEqualTo(pool.primaryCount));
    });

    test('full mode excludes stretching and cardio', () {
      final pool = buildCandidatePool(
          catalog: catalog, targetGroups: ['Chest'], fullCatalog: true);
      final ids = pool.exercises.map((e) => e.id).toList();
      expect(ids, isNot(contains('A_Chest_Stretch')));
    });

    test('Full Body target is a wildcard in full mode', () {
      final pool = buildCandidatePool(
          catalog: catalog, targetGroups: ['Full Body'], fullCatalog: true);
      final ids = pool.exercises.map((e) => e.id).toList();
      expect(ids, contains('Leg_Thing'));
      expect(ids, contains('Some_Obscure_Chest_Move'));
      expect(ids, isNot(contains('A_Cardio_Thing'))); // category still excluded
    });
  });

  group('buildCandidatePool — filters', () {
    final catalog = [
      ex('Barbell_Bench_Press_-_Medium_Grip', primary: 'chest', equipment: 'barbell'),
      ex('Dumbbell_Bench_Press', primary: 'chest', equipment: 'dumbbell', level: 'intermediate'),
    ];

    test('equipment filter', () {
      final pool = buildCandidatePool(
          catalog: catalog, targetGroups: ['Chest'], fullCatalog: false,
          filters: const ExercisePoolFilters(equipmentBuckets: {'Dumbbell'}));
      expect(pool.exercises.single.id, 'Dumbbell_Bench_Press');
    });

    test('sub-muscle, level, favorites, query filters', () {
      expect(buildCandidatePool(catalog: catalog, targetGroups: ['Chest'],
          fullCatalog: false,
          filters: const ExercisePoolFilters(subMuscles: {'triceps'}))
          .exercises, isEmpty);
      expect(buildCandidatePool(catalog: catalog, targetGroups: ['Chest'],
          fullCatalog: false,
          filters: const ExercisePoolFilters(level: 'intermediate'))
          .exercises.single.id, 'Dumbbell_Bench_Press');
      expect(buildCandidatePool(catalog: catalog, targetGroups: ['Chest'],
          fullCatalog: false, favoriteIds: {'Dumbbell_Bench_Press'},
          filters: const ExercisePoolFilters(favoritesOnly: true))
          .exercises.single.id, 'Dumbbell_Bench_Press');
      expect(buildCandidatePool(catalog: catalog, targetGroups: ['Chest'],
          fullCatalog: false,
          filters: const ExercisePoolFilters(query: 'dumbbell'))
          .exercises.single.id, 'Dumbbell_Bench_Press');
    });
  });

  group('preserveSelection', () {
    test('keeps only ids still in the pool', () {
      final pool = buildCandidatePool(
          catalog: [ex('Barbell_Bench_Press_-_Medium_Grip', primary: 'chest')],
          targetGroups: ['Chest'], fullCatalog: false);
      expect(preserveSelection({'Barbell_Bench_Press_-_Medium_Grip', 'gone'}, pool),
          {'Barbell_Bench_Press_-_Medium_Grip'});
    });
  });
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/exercise_pool_test.dart` → FAIL (symbols missing).

- [ ] **Step 3: Append to `lib/data/exercise_pool.dart`**

```dart
/// View-time filters for the picker. All default-empty = no filtering.
class ExercisePoolFilters {
  const ExercisePoolFilters({
    this.equipmentBuckets = const {},
    this.subMuscles = const {},
    this.level,
    this.favoritesOnly = false,
    this.query = '',
  });

  final Set<String> equipmentBuckets; // values from kEquipmentBuckets
  final Set<String> subMuscles; // raw primaryMuscle values
  final String? level;
  final bool favoritesOnly;
  final String query;

  bool get isEmpty =>
      equipmentBuckets.isEmpty &&
      subMuscles.isEmpty &&
      level == null &&
      !favoritesOnly &&
      query.isEmpty;
}

/// Ordered candidate list plus where the curated/pinned section ends. In full
/// mode the remainder renders under a MORE EXERCISES divider.
class ExercisePool {
  const ExercisePool({required this.exercises, required this.primaryCount});

  final List<Exercise> exercises;
  final int primaryCount;
}

/// Canonical bucket for [exercise]: custom exercises match on their authored
/// muscleGroup, built-ins on primaryMuscles[0].
String? exerciseBucket(Exercise exercise) {
  final group = exercise.muscleGroup;
  if (group != null) {
    final normalized = normalizeMuscleGroup(group);
    if (normalized != null) return normalized;
  }
  final primary = exercise.primaryMuscle;
  return primary == null ? null : muscleGroupForDetailed(primary);
}

/// Assembles the picker's candidate list.
///
/// Curated mode ([fullCatalog] false): custom exercises matching the targets +
/// [pinnedIds] + the curated allow-list — today's closed pool. Full mode adds
/// every bucket-matched catalog exercise (`Full Body` target = wildcard, minus
/// stretching/cardio) as an alphabetical tail after [ExercisePool.primaryCount].
/// Order within the primary section: pinned (in order) -> usage desc ->
/// curated order -> name.
ExercisePool buildCandidatePool({
  required List<Exercise> catalog,
  required List<String> targetGroups,
  required bool fullCatalog,
  List<String> pinnedIds = const [],
  Map<String, int> usageCounts = const {},
  Set<String> favoriteIds = const {},
  ExercisePoolFilters filters = const ExercisePoolFilters(),
}) {
  final targets = normalizeTargetMuscleGroups(targetGroups);
  if (targets.isEmpty) {
    return const ExercisePool(exercises: [], primaryCount: 0);
  }

  final byId = {for (final e in catalog) e.id: e};
  final curatedIds = curatedExerciseIdsForMuscleGroups(targets);
  final curatedOrder = {
    for (var i = 0; i < curatedIds.length; i++) curatedIds[i]: i,
  };

  final primary = <Exercise>[];
  final added = <String>{};
  void add(Exercise? e) {
    if (e != null && added.add(e.id)) primary.add(e);
  }

  for (final e in catalog) {
    if (e.isCustom &&
        e.muscleGroup != null &&
        hasTargetMuscle(targets, e.muscleGroup!)) {
      add(e);
    }
  }
  for (final id in pinnedIds) {
    add(byId[id]);
  }
  for (final id in curatedIds) {
    add(byId[id]);
  }

  final pinnedRank = {
    for (var i = 0; i < pinnedIds.length; i++) pinnedIds[i]: i,
  };
  primary.sort((a, b) {
    final p = (pinnedRank[a.id] ?? 1 << 30).compareTo(pinnedRank[b.id] ?? 1 << 30);
    if (p != 0) return p;
    final u = (usageCounts[b.id] ?? 0).compareTo(usageCounts[a.id] ?? 0);
    if (u != 0) return u;
    final c = (curatedOrder[a.id] ?? 1 << 30).compareTo(curatedOrder[b.id] ?? 1 << 30);
    if (c != 0) return c;
    return a.name.compareTo(b.name);
  });

  final tail = <Exercise>[];
  if (fullCatalog) {
    final wildcard = targets.contains('Full Body');
    for (final e in catalog) {
      if (added.contains(e.id)) continue;
      if (e.category == 'stretching' || e.category == 'cardio') continue;
      if (!wildcard) {
        final bucket = exerciseBucket(e);
        if (bucket == null || !targets.contains(bucket)) continue;
      }
      tail.add(e);
    }
    tail.sort((a, b) => a.name.compareTo(b.name));
  }

  bool keep(Exercise e) {
    if (filters.level != null && e.level != filters.level) return false;
    if (filters.favoritesOnly && !favoriteIds.contains(e.id)) return false;
    if (filters.equipmentBuckets.isNotEmpty &&
        !filters.equipmentBuckets.contains(equipmentBucket(e.equipment))) {
      return false;
    }
    if (filters.subMuscles.isNotEmpty) {
      final p = e.primaryMuscle;
      if (p == null || !filters.subMuscles.contains(p)) return false;
    }
    if (filters.query.isNotEmpty &&
        !e.name.toLowerCase().contains(filters.query.toLowerCase())) {
      return false;
    }
    return true;
  }

  final keptPrimary = filters.isEmpty ? primary : primary.where(keep).toList();
  final keptTail = filters.isEmpty ? tail : tail.where(keep).toList();
  return ExercisePool(
    exercises: [...keptPrimary, ...keptTail],
    primaryCount: keptPrimary.length,
  );
}

/// Selection survival across a target change: keeps ids still in [pool].
Set<String> preserveSelection(Set<String> selected, ExercisePool pool) {
  final ids = {for (final e in pool.exercises) e.id};
  return {
    for (final id in selected)
      if (ids.contains(id)) id,
  };
}
```

- [ ] **Step 4: Run to verify pass** — `flutter test test/exercise_pool_test.dart` → PASS (all groups).

- [ ] **Step 5: Commit**

```bash
git add lib/data/exercise_pool.dart test/exercise_pool_test.dart
git commit -m "feat(picker): pure candidate pool builder with full-catalog mode and filters"
```

---

### Task 4: Extract `usageCountsForTargets` (pure refactor under green tests)

**Files:**
- Modify: `lib/services/workout_storage_service.dart:190-261` (`topExerciseIdsForTargets` + new method)

- [ ] **Step 1: Confirm guard tests are green first**

Run: `flutter test test/multi_muscle_targets_test.dart`
Expected: PASS (this suite covers `topExerciseIdsForTargets` at line ~264).

- [ ] **Step 2: Add the extracted method and rewire** — in `WorkoutStorageService`, directly above `topExerciseIdsForTargets`:

```dart
  /// Per-exercise usage among completed sessions matching [targetGroups]:
  /// session count and most recent date. Powers history pre-selection and the
  /// picker's float-up ordering.
  Future<({Map<String, int> counts, Map<String, DateTime> lastSeen})>
  usageCountsForTargets(
    List<String> targetGroups,
    List<Exercise> catalog,
  ) async {
    final targets = normalizeTargetMuscleGroups(targetGroups).toSet();
    final counts = <String, int>{};
    final lastSeen = <String, DateTime>{};
    if (targets.isEmpty) return (counts: counts, lastSeen: lastSeen);

    final catalogById = {for (final exercise in catalog) exercise.id: exercise};
    for (final session in await getSessions()) {
      if (session.isPartial || session.isAbandoned) continue;
      final seenThisSession = <String>{};
      for (final log in session.exercises) {
        if (!seenThisSession.add(log.exerciseId)) continue;
        if (!_exerciseMatchesTargets(
          log.exerciseId,
          session,
          catalogById,
          targets,
        )) {
          continue;
        }
        counts[log.exerciseId] = (counts[log.exerciseId] ?? 0) + 1;
        final currentLast = lastSeen[log.exerciseId];
        if (currentLast == null || session.date.isAfter(currentLast)) {
          lastSeen[log.exerciseId] = session.date;
        }
      }
    }
    return (counts: counts, lastSeen: lastSeen);
  }
```

Then replace the **body** of `topExerciseIdsForTargets` with:

```dart
  Future<List<String>> topExerciseIdsForTargets(
    List<String> targetGroups,
    List<Exercise> catalog, {
    int limit = 3,
  }) async {
    final targets = normalizeTargetMuscleGroups(targetGroups).toSet();
    if (targets.isEmpty || limit <= 0) return const [];

    final curatedOrder = <String, int>{};
    for (final exercise in catalog) {
      curatedOrder.putIfAbsent(exercise.id, () => curatedOrder.length);
    }
    final usage = await usageCountsForTargets(targetGroups, catalog);
    final counts = usage.counts;
    final lastSeen = usage.lastSeen;

    final ids = counts.keys.toList()
      ..sort((a, b) {
        final countCompare = counts[b]!.compareTo(counts[a]!);
        if (countCompare != 0) return countCompare;
        final recentCompare = lastSeen[b]!.compareTo(lastSeen[a]!);
        if (recentCompare != 0) return recentCompare;
        return (curatedOrder[a] ?? 1 << 30).compareTo(
          curatedOrder[b] ?? 1 << 30,
        );
      });

    return ids.take(limit).toList();
  }
```

(The old inline counting loop between the two is deleted — `_exerciseMatchesTargets` stays.)

- [ ] **Step 3: Verify behavior unchanged**

Run: `flutter test test/multi_muscle_targets_test.dart`
Expected: PASS, identical results.

- [ ] **Step 4: Commit**

```bash
git add lib/services/workout_storage_service.dart
git commit -m "refactor(storage): extract usageCountsForTargets for picker ordering"
```

---

### Task 5: Persisted FULL LIST preference

**Files:**
- Modify: `lib/services/workout_defaults_service.dart`
- Test: `test/workout_defaults_show_full_pool_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/workout_defaults_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to false', () async {
    expect(await WorkoutDefaultsService().getShowFullExercisePool(), isFalse);
  });

  test('round-trips true', () async {
    await WorkoutDefaultsService().setShowFullExercisePool(true);
    expect(await WorkoutDefaultsService().getShowFullExercisePool(), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/workout_defaults_show_full_pool_test.dart` → FAIL (method not defined).

- [ ] **Step 3: Implement** — in `WorkoutDefaultsService` add:

```dart
  static const _showFullPoolKey = 'show_full_exercise_pool_v1';

  /// Picker preference: false = curated default list, true = full catalog.
  Future<bool> getShowFullExercisePool() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showFullPoolKey) ?? false;
  }

  Future<void> setShowFullExercisePool(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFullPoolKey, value);
  }
```

- [ ] **Step 4: Run to verify pass** — `flutter test test/workout_defaults_show_full_pool_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/workout_defaults_service.dart test/workout_defaults_show_full_pool_test.dart
git commit -m "feat(picker): persisted FULL LIST preference"
```

---

### Task 6: Curated drift-guard test → data cleanup (prune + declare)

**Files:**
- Test: `test/curated_exercises_test.dart` (create — written FIRST, fails against current data)
- Modify: `lib/data/curated_exercises.dart`, `pubspec.yaml`

- [ ] **Step 1: Write the validation test (it must fail against current data)**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/curated_exercises.dart';
import 'package:workout_track/data/muscle_groups.dart';

/// Deliberate cross-bucket placements: conventional gym categorization beats
/// the catalog's primaryMuscles[0] for these. Additions need a reason here.
const Map<String, Set<String>> kCrossBucketExceptions = {
  'Chest': {'Bench_Press_with_Chains'}, // a bench press despite triceps primary
  'Shoulders': {'Upright_Cable_Row', 'Kettlebell_Sumo_High_Pull'}, // traps primary
  'Core': {'Mountain_Climbers'}, // quads primary, trained as core
};

void main() {
  late Map<String, Map<String, dynamic>> catalog;
  late Set<String> declaredFolders;

  setUpAll(() {
    final data =
        jsonDecode(File('assets/exercises.json').readAsStringSync())
            as List<dynamic>;
    catalog = {
      for (final e in data)
        (e as Map<String, dynamic>)['id'] as String: e,
    };
    declaredFolders = RegExp(r'assets/exercises/exercises/([^/\n]+)/')
        .allMatches(File('pubspec.yaml').readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
  });

  test('every curated id exists in the catalog', () {
    for (final entry in curatedExerciseIdsByMuscleGroup.entries) {
      for (final id in entry.value) {
        expect(catalog.containsKey(id), isTrue,
            reason: '${entry.key}/$id not in exercises.json');
      }
    }
  });

  test('every curated id has a declared image asset folder', () {
    for (final entry in curatedExerciseIdsByMuscleGroup.entries) {
      for (final id in entry.value) {
        expect(declaredFolders.contains(id), isTrue,
            reason: '${entry.key}/$id folder missing from pubspec.yaml');
      }
    }
  });

  test('no curated id is a stretching or cardio entry', () {
    for (final entry in curatedExerciseIdsByMuscleGroup.entries) {
      for (final id in entry.value) {
        final category = catalog[id]!['category'] as String?;
        expect(category, isNot(anyOf('stretching', 'cardio')),
            reason: '${entry.key}/$id is $category');
      }
    }
  });

  test('curated ids align with their bucket, modulo documented exceptions', () {
    for (final entry in curatedExerciseIdsByMuscleGroup.entries) {
      if (entry.key == 'Full Body') continue; // spans all buckets by design
      for (final id in entry.value) {
        if (kCrossBucketExceptions[entry.key]?.contains(id) ?? false) continue;
        final primaries = catalog[id]!['primaryMuscles'] as List<dynamic>;
        final bucket = muscleGroupForDetailed(primaries.first as String);
        expect(bucket, entry.key,
            reason: '${entry.key}/$id has primary ${primaries.first}');
      }
    }
  });
}
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/curated_exercises_test.dart`
Expected: FAIL — asset test (13 ids), category test (7 entries), alignment test (19 entries).

- [ ] **Step 3: Prune `lib/data/curated_exercises.dart`** — delete exactly these id lines from these buckets (each survivor already lives in its correct bucket):

- From `'Chest'`: `Behind_Head_Chest_Stretch`, `Seated_Front_Deltoid`, `Alternating_Renegade_Row`, `Press_Sit-Up`, `Handstand_Push-Ups`, `Push_Press` → 24 remain.
- From `'Back'`: `Overhead_Lat` → 29 remain.
- From `'Arms'`: `Overhead_Triceps`, `Seated_Biceps`, `Handstand_Push-Ups`, `Plyo_Kettlebell_Pushups`, `Push_Press`, `One-Arm_Kettlebell_Snatch`, `Clean_and_Jerk` → 23 remain.
- From `'Shoulders'`: `Seated_Front_Deltoid`, `Overhead_Lat`, `Plyo_Kettlebell_Pushups`, `Neck_Press` → 11 remain.
- From `'Core'`: `Glute_Ham_Raise`, `Alternating_Renegade_Row`, `Plyo_Kettlebell_Pushups`, `One-Arm_Kettlebell_Floor_Press`, `Leg-Over_Floor_Press`, `One-Arm_Kettlebell_Snatch` → 9 remain.
- `'Legs'` and `'Full Body'`: unchanged.

- [ ] **Step 4: Declare the 13 missing folders in `pubspec.yaml`** — insert each line in the existing alphabetical `assets:` list (anchor = the line it goes after):

| New line | Insert after |
|---|---|
| `- assets/exercises/exercises/Air_Bike/` | `- assets/exercises.json` |
| `- assets/exercises/exercises/Arnold_Dumbbell_Press/` | `.../Alternating_Renegade_Row/` |
| `- assets/exercises/exercises/Barbell_Ab_Rollout_-_On_Knees/` | `.../Atlas_Stones/` |
| `- assets/exercises/exercises/Crunches/` | `.../Close-Grip_Front_Lat_Pulldown/` |
| `- assets/exercises/exercises/Dead_Bug/` | `.../Crunches/` (just added) |
| `- assets/exercises/exercises/Dumbbell_Shoulder_Press/` | `.../Dumbbell_One-Arm_Triceps_Extension/` |
| `- assets/exercises/exercises/Face_Pull/` | `.../EZ-Bar_Skullcrusher/` |
| `- assets/exercises/exercises/Hanging_Leg_Raise/` | `.../Handstand_Push-Ups/` |
| `- assets/exercises/exercises/Mountain_Climbers/` | `.../Mixed_Grip_Chin/` |
| `- assets/exercises/exercises/Plank/` | `.../Overhead_Triceps/` |
| `- assets/exercises/exercises/Russian_Twist/` | `.../Romanian_Deadlift/` |
| `- assets/exercises/exercises/Side_Lateral_Raise/` | `.../Seated_One-arm_Cable_Pulley_Rows/` |
| `- assets/exercises/exercises/Standing_Military_Press/` | `.../Standing_Calf_Raises/` |

Then run: `flutter pub get`

- [ ] **Step 5: Run to verify pass** — `flutter test test/curated_exercises_test.dart` → PASS (4 tests).

- [ ] **Step 6: Run neighbors that consume curated data**

Run: `flutter test test/program_prescription_test.dart test/start_workout_program_flow_test.dart test/multi_muscle_targets_test.dart`
Expected: PASS — program prescriptions reference Full Body/Legs ids, all untouched by the prune. If a failure names a pruned id, the test (not the data) must be updated to a surviving id.

- [ ] **Step 7: Commit**

```bash
git add test/curated_exercises_test.dart lib/data/curated_exercises.dart pubspec.yaml
git commit -m "fix(data): validated curated lists - prune off-muscle/stretch entries, declare missing assets"
```

---

### Task 7: Wire the pool builder into `start_workout.dart` (selection preservation)

**Files:**
- Modify: `lib/pages/Workout session/start_workout.dart`

This task swaps internals with **zero intended UI change** (toggle stays off, no new chips yet).

- [ ] **Step 1: Add import and state** — add `import '../../data/exercise_pool.dart';` (keep the `../../data/curated_exercises.dart` import — `programDayStarter` at the top of this file still uses `curatedExerciseIdsForMuscleGroups`). In `_StartWorkoutPageState` add fields:

```dart
  Map<String, int> _usageCounts = const {};
  bool _showFullPool = false;
```

- [ ] **Step 2: Replace `_candidateExercises` with `_buildPool`**

```dart
  ExercisePool _buildPool(
    List<Exercise> catalog, {
    bool applyFilters = true,
  }) {
    return buildCandidatePool(
      catalog: catalog,
      targetGroups: _selectedMuscleGroups,
      fullCatalog: _showFullPool,
      pinnedIds: [
        ...?widget.programCuratedExerciseIds,
        ..._selectedExerciseIds,
      ],
      usageCounts: _usageCounts,
      favoriteIds: _favoriteExerciseIds,
      filters: applyFilters
          ? ExercisePoolFilters(
              level: _levelFilter,
              favoritesOnly: _showFavoritesOnly,
              query: _searchQuery,
            )
          : const ExercisePoolFilters(),
    );
  }
```

Update the two call sites: in `_startSelectedWorkout` replace `_candidateExercises(catalog, applyFilters: false).where(...)` with `_buildPool(catalog, applyFilters: false).exercises.where(...)`; in `_buildExerciseList` replace `_candidateExercises(snapshot.data ?? const [])` with `_buildPool(snapshot.data ?? const []).exercises` (assign to `final filtered` as before). Delete the old `_candidateExercises` method.

- [ ] **Step 3: Fix `_toggleMuscleGroup` (stop wiping selections)**

```dart
  void _toggleMuscleGroup(String muscleGroup) {
    setState(() {
      final selected = _selectedMuscleGroups.toSet();
      if (selected.contains(muscleGroup)) {
        selected.remove(muscleGroup);
      } else {
        selected.add(muscleGroup);
      }
      _selectedMuscleGroups = normalizeTargetMuscleGroups(selected);
    });
    _refreshHistoryPreselection();
  }
```

(The only change: the `_selectedExerciseIds = {};` line is deleted.)

- [ ] **Step 4: Rework `_refreshHistoryPreselection`** — replace the whole method:

```dart
  Future<void> _refreshHistoryPreselection() async {
    final targets = List<String>.from(_selectedMuscleGroups);
    if (targets.isEmpty) {
      if (mounted) setState(() => _selectedExerciseIds = {});
      return;
    }

    final catalog = await _safeExerciseCatalogFuture;
    final usage = await WorkoutStorageService().usageCountsForTargets(
      targets,
      catalog,
    );
    if (!mounted || !_sameTargets(targets, _selectedMuscleGroups)) return;

    // Program mode pre-selects today's full prescribed loadout.
    if (_programMode && widget.programCuratedExerciseIds != null) {
      setState(() {
        _usageCounts = usage.counts;
        _selectedExerciseIds = widget.programCuratedExerciseIds!.toSet();
      });
      return;
    }

    // Manual picks survive a target change when they still match the new
    // targets (checked against the FULL pool so a full-list add survives even
    // while the visible list is curated). History seeds top-3 only when
    // nothing survives.
    final membership = buildCandidatePool(
      catalog: catalog,
      targetGroups: targets,
      fullCatalog: true,
    );
    var next = preserveSelection(_selectedExerciseIds, membership);
    if (next.isEmpty) {
      final top = await WorkoutStorageService().topExerciseIdsForTargets(
        targets,
        catalog,
        limit: 3,
      );
      if (!mounted || !_sameTargets(targets, _selectedMuscleGroups)) return;
      next = top.toSet();
    }
    setState(() {
      _usageCounts = usage.counts;
      _selectedExerciseIds = next;
    });
  }
```

- [ ] **Step 5: Verify** — `flutter analyze` (zero new issues) and:

Run: `flutter test test/start_workout_program_flow_test.dart test/multi_muscle_targets_test.dart test/exercise_pool_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "lib/pages/Workout session/start_workout.dart"
git commit -m "feat(picker): pool-builder wiring + selection survives target changes"
```

---

### Task 8: Lazy sliver list + FULL LIST chip + MORE EXERCISES divider

**Files:**
- Modify: `lib/pages/Workout session/start_workout.dart`

- [ ] **Step 1: Load the persisted toggle** — in `_loadDefaults`, also read the preference:

```dart
  Future<void> _loadDefaults() async {
    final service = WorkoutDefaultsService();
    final duration = await service.getDurationMinutes();
    final rest = await service.getRestSeconds();
    final showFullPool = await service.getShowFullExercisePool();
    if (!mounted) return;
    setState(() {
      _durationMinutes = duration;
      _restSeconds = rest;
      _showFullPool = showFullPool;
    });
  }
```

- [ ] **Step 2: Add the FULL LIST chip** — in `_buildSearchAndFilters`, in the first `Row` right after the FILTER `ArcadeChip`:

```dart
            const SizedBox(width: kSpace2),
            ArcadeChip(
              label: 'FULL LIST',
              selected: _showFullPool,
              onTap: () {
                setState(() => _showFullPool = !_showFullPool);
                WorkoutDefaultsService().setShowFullExercisePool(_showFullPool);
              },
            ),
```

- [ ] **Step 3: Restructure the body to slivers** — replace the `Expanded(child: SingleChildScrollView(...))` block in `build` with:

```dart
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    kSpace4, kSpace4, kSpace4, 0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _StepHeader(label: '1. CHOOSE TARGET'),
                        const SizedBox(height: kSpace2),
                        if (_programMode)
                          _ProgramTargetSummary(
                            label: widget.programDayLabel ?? targetLabel,
                            summary: widget.programFocusSummary ??
                                'Program workout selected.',
                          )
                        else ...[
                          // (existing manual-mode target text + chips Wrap,
                          //  unchanged — moved verbatim from the old Column)
                        ],
                        if (_selectedMuscleGroups.isNotEmpty) ...[
                          const SizedBox(height: kSpace5),
                          const _StepHeader(label: '2. PICK EXERCISES'),
                          const SizedBox(height: kSpace2),
                          Text(
                            _selectedExerciseIds.isEmpty
                                ? 'Choose at least one exercise.'
                                : '${_selectedExerciseIds.length} selected',
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: kSpace3),
                          _buildSearchAndFilters(),
                          const SizedBox(height: kSpace3),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_selectedMuscleGroups.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      kSpace4, 0, kSpace4, kSpace4,
                    ),
                    sliver: _buildExerciseSliver(),
                  ),
              ],
            ),
          ),
```

(The `else ...[ ]` block is the existing manual-mode `Text` + `Wrap` of muscle chips, moved as-is. `_SelectionBar` stays below the `Expanded` unchanged.)

- [ ] **Step 4: Replace `_buildExerciseList` with `_buildExerciseSliver`**

```dart
  Widget _buildExerciseSliver() {
    return FutureBuilder<List<Exercise>>(
      future: _safeExerciseCatalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: kSpace5),
              child: Center(child: PixelLoader()),
            ),
          );
        }
        if (snapshot.hasError) {
          return const SliverToBoxAdapter(
            child: _InfoMessage(label: 'Could not load exercises.'),
          );
        }

        final pool = _buildPool(snapshot.data ?? const []);
        if (pool.exercises.isEmpty) {
          return const SliverToBoxAdapter(
            child: _InfoMessage(label: 'No exercises found.'),
          );
        }

        final showDivider =
            _showFullPool && pool.primaryCount < pool.exercises.length;
        return SliverList.builder(
          itemCount: pool.exercises.length + (showDivider ? 1 : 0),
          itemBuilder: (context, index) {
            var i = index;
            if (showDivider) {
              if (index == pool.primaryCount) {
                return const _MoreExercisesDivider();
              }
              if (index > pool.primaryCount) i = index - 1;
            }
            final exercise = pool.exercises[i];
            return ExerciseCard(
              exercise: exercise,
              showInfoIcon: true,
              showFavorite: false,
              showCheckbox: true,
              isFavorite: _favoriteExerciseIds.contains(exercise.id),
              isSelected: _selectedExerciseIds.contains(exercise.id),
              isCustom: exercise.isCustom,
              onTap: () => _toggleSelectedExercise(exercise.id),
              onInfoPressed: () => _showExercisePreview(exercise),
              onCheckboxToggle: () => _toggleSelectedExercise(exercise.id),
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 5: Add the divider widget** (next to `_InfoMessage` at the bottom of the file):

```dart
class _MoreExercisesDivider extends StatelessWidget {
  const _MoreExercisesDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace3),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: kBorderDark)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: kSpace3),
            child: Text(
              'MORE EXERCISES',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: kMutedText,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: kBorderDark)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Verify** — `flutter analyze` (zero new) and:

Run: `flutter test test/start_workout_program_flow_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add "lib/pages/Workout session/start_workout.dart"
git commit -m "feat(picker): FULL LIST toggle, lazy sliver list, MORE EXERCISES divider"
```

---

### Task 9: Equipment + sub-muscle filter chips

**Files:**
- Modify: `lib/pages/Workout session/start_workout.dart`

- [ ] **Step 1: Add filter state + catalog cache** — fields in `_StartWorkoutPageState`:

```dart
  Set<String> _equipmentFilter = {};
  Set<String> _subMuscleFilter = {};
  List<Exercise> _catalogCache = const [];
```

In `initState`, after `_loadFavoriteExerciseIds();` add:

```dart
    _safeExerciseCatalogFuture.then((catalog) {
      if (mounted) setState(() => _catalogCache = catalog);
    });
```

- [ ] **Step 2: Thread the new filters into `_buildPool`** — the `applyFilters: true` branch becomes:

```dart
          ? ExercisePoolFilters(
              equipmentBuckets: _equipmentFilter,
              subMuscles: _subMuscleFilter,
              level: _levelFilter,
              favoritesOnly: _showFavoritesOnly,
              query: _searchQuery,
            )
```

- [ ] **Step 3: Extend `_buildSearchAndFilters`** —
`hasFilter` becomes:

```dart
    final hasFilter = _levelFilter != null ||
        _showFavoritesOnly ||
        _equipmentFilter.isNotEmpty ||
        _subMuscleFilter.isNotEmpty;
```

The `Clear` button's `setState` also resets the new sets:

```dart
                  _levelFilter = null;
                  _showFavoritesOnly = false;
                  _equipmentFilter = {};
                  _subMuscleFilter = {};
```

(Apply the same two extra resets to the `All` chip inside the expanded panel.)

Inside the `if (_filtersExpanded) ...[` block, after the existing level/Fav row's `SingleChildScrollView`, append the equipment row and the contextual sub-muscle row:

```dart
          const SizedBox(height: kSpace2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final bucket in kEquipmentBuckets) ...[
                  ArcadeChip(
                    label: bucket.toUpperCase(),
                    selected: _equipmentFilter.contains(bucket),
                    onTap: () => setState(() {
                      final next = {..._equipmentFilter};
                      if (!next.remove(bucket)) next.add(bucket);
                      _equipmentFilter = next;
                    }),
                  ),
                  const SizedBox(width: kSpace2),
                ],
              ],
            ),
          ),
          if (_subMuscleChips.length >= 2) ...[
            const SizedBox(height: kSpace2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final muscle in _subMuscleChips) ...[
                    ArcadeChip(
                      label: subMuscleLabel(muscle).toUpperCase(),
                      selected: _subMuscleFilter.contains(muscle),
                      onTap: () => setState(() {
                        final next = {..._subMuscleFilter};
                        if (!next.remove(muscle)) next.add(muscle);
                        _subMuscleFilter = next;
                      }),
                    ),
                    const SizedBox(width: kSpace2),
                  ],
                ],
              ),
            ),
          ],
```

- [ ] **Step 4: Add the `_subMuscleChips` getter** (sub-muscles available in the current pool, ignoring the sub-muscle filter itself so chips don't vanish when used):

```dart
  List<String> get _subMuscleChips {
    if (_catalogCache.isEmpty || _selectedMuscleGroups.isEmpty) return const [];
    final pool = buildCandidatePool(
      catalog: _catalogCache,
      targetGroups: _selectedMuscleGroups,
      fullCatalog: _showFullPool,
      pinnedIds: [
        ...?widget.programCuratedExerciseIds,
        ..._selectedExerciseIds,
      ],
      filters: ExercisePoolFilters(
        equipmentBuckets: _equipmentFilter,
        level: _levelFilter,
        favoritesOnly: _showFavoritesOnly,
        query: _searchQuery,
      ),
    );
    return availableSubMuscles(pool.exercises);
  }
```

- [ ] **Step 5: Verify** — `flutter analyze` (zero new) and:

Run: `flutter test test/start_workout_program_flow_test.dart test/exercise_pool_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "lib/pages/Workout session/start_workout.dart"
git commit -m "feat(picker): equipment and contextual sub-muscle filter chips"
```

---

### Task 10: Widget test — selection survives a target change

**Files:**
- Test: `test/start_workout_selection_test.dart` (create)

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/Workout session/start_workout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('manual pick survives adding a second muscle group',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartWorkoutPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();

    // Select a curated chest lift.
    final bench = find.text('Dumbbell Bench Press');
    await tester.scrollUntilVisible(bench, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(bench);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Add a second target. Old behavior wiped the selection (fresh user has
    // no history, so it became 'Choose at least one exercise.').
    await tester.scrollUntilVisible(find.text('Back'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/start_workout_selection_test.dart`
Expected: PASS (Tasks 7–9 landed the fix; this is the regression lock). If the harness flakes on image decoding or settle timeouts, replace `pumpAndSettle()` after taps with `pump(const Duration(milliseconds: 400))` — the ArcadeChip blink timer runs 160ms.

- [ ] **Step 3: Commit**

```bash
git add test/start_workout_selection_test.dart
git commit -m "test(picker): selection survives muscle-group toggle"
```

---

### Task 11: Documentation fix (stale time-picker description)

**Files:**
- Modify: `CLAUDE.md` (Workout session flow, item 1)

- [ ] **Step 1: Replace the stale bullet**

Old:
```
1. `StartWorkoutPage` — muscle group chips, time picker, exercise picker bottom sheet (multi-select with favorites).
```

New:
```
1. `StartWorkoutPage` — muscle group chips, curated exercise list with a persisted FULL LIST toggle (full catalog, stretching/cardio excluded), filters (equipment, sub-muscle, level, favorites) + search. Duration/rest come from Settings defaults (no on-screen time picker).
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: picker flow description matches shipped behavior"
```

---

### Task 12: Final verification

- [ ] **Step 1:** `flutter analyze` — expected: only the 12 pre-existing avatar/profile test errors (baseline); zero new issues.
- [ ] **Step 2:** `flutter test` — expected: full suite green (the 5 baseline-broken avatar/profile test FILES fail to compile as before; every other suite passes, including the 5 new/extended picker test files).
- [ ] **Step 3:** Manual on Android (`flutter run`, full restart — pubspec assets changed):
  1. Default picker (Chest): curated list, all cards have images (incl. Side Lateral Raise etc. after Task 6), no FULL LIST artifacts.
  2. FULL LIST on → curated section, `MORE EXERCISES` divider, long alphabetical tail; search finds a non-curated movement (e.g. "Svend Press"); smooth scroll.
  3. Equipment chips: DUMBBELL+BODYWEIGHT narrows correctly; CLEAR resets everything.
  4. Arms target → BICEPS/TRICEPS/FOREARMS sub-muscle chips appear and filter.
  5. Toggle survives app restart.
  6. Select an exercise → add second muscle group → selection retained.
  7. Program day start: prescribed lifts pre-selected; FULL LIST expands within the day's muscles only.

---

## Self-review notes (completed)

- **Spec coverage:** §1 pool builder → Tasks 2–3; §2 category → Task 1; §3 UI → Tasks 8–9; §4 selection fixes → Tasks 4, 7, 10; §5 data cleanup → Task 6; §6 validation test → Task 6; §7 docs → Task 11. No gaps.
- **Type consistency:** `ExercisePool.primaryCount`, `buildCandidatePool(...)` named args, `usageCountsForTargets` record fields (`counts`/`lastSeen`), and `_buildPool(catalog, {applyFilters})` are used identically across Tasks 3, 4, 7, 8, 9.
- **Known intentional behavior change:** custom exercises no longer render strictly first in the list — ordering is pinned → usage → curated → name (per approved spec §1).
