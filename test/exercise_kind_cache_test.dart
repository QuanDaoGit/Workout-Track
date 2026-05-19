import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseKindCache.instance.resetForTest();
  });

  group('ExerciseKindCache.classify', () {
    test('mechanic compound → compound', () async {
      final kind = await ExerciseKindCache.instance.classify(
        'bench',
        mechanic: 'compound',
      );
      expect(kind, ExerciseKind.compound);
    });

    test('mechanic isolation → isolation', () async {
      final kind = await ExerciseKindCache.instance.classify(
        'curl',
        mechanic: 'isolation',
      );
      expect(kind, ExerciseKind.isolation);
    });

    test('observed weight-zero set → bodyweight wins over mechanic', () async {
      final kind = await ExerciseKindCache.instance.classify(
        'pullup',
        mechanic: 'compound',
        observedSets: const [SetEntry(weight: 0, reps: 8)],
      );
      expect(kind, ExerciseKind.bodyweight);
    });

    test('equipment body only + null mechanic → bodyweight', () async {
      final kind = await ExerciseKindCache.instance.classify(
        'pushup',
        mechanic: null,
        equipment: 'body only',
      );
      expect(kind, ExerciseKind.bodyweight);
    });

    test('null mechanic + non-body equipment → compound default', () async {
      final kind = await ExerciseKindCache.instance.classify(
        'unknown',
        mechanic: null,
        equipment: 'barbell',
      );
      expect(kind, ExerciseKind.compound);
    });

    test(
      'classification is sticky — later weighted sets do not flip a bodyweight cache',
      () async {
        // First call: pure bodyweight.
        final initial = await ExerciseKindCache.instance.classify(
          'dip',
          mechanic: 'compound',
          observedSets: const [SetEntry(weight: 0, reps: 10)],
        );
        expect(initial, ExerciseKind.bodyweight);

        // Reload cache from prefs (simulates app restart).
        ExerciseKindCache.instance.resetForTest();

        // Second call: user has now added a weighted vest.
        final later = await ExerciseKindCache.instance.classify(
          'dip',
          mechanic: 'compound',
          observedSets: const [SetEntry(weight: 20, reps: 8)],
        );
        // Still bodyweight — rep target should not flip mid-program.
        expect(later, ExerciseKind.bodyweight);
      },
    );

    test('cached value survives a memo reset (round-trip through prefs)', () async {
      await ExerciseKindCache.instance.classify(
        'squat',
        mechanic: 'compound',
      );
      ExerciseKindCache.instance.resetForTest();
      final reloaded = await ExerciseKindCache.instance.classify(
        'squat',
        // Pretend the mechanic field changed; cache should still win.
        mechanic: 'isolation',
      );
      expect(reloaded, ExerciseKind.compound);
    });
  });
}
