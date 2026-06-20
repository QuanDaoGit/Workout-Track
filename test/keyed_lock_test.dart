import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/keyed_lock.dart';
import 'package:workout_track/services/workout_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyedLock — mechanism', () {
    test('serialises same-key read-modify-write (no lost update)', () async {
      final lock = KeyedLock();
      var counter = 0;
      // Each action reads, yields, then writes — the classic lost-update window.
      // Unlocked + concurrent, all five would read 0 and write 1 (counter == 1).
      Future<void> increment() => lock.synchronized('k', () async {
        final v = counter;
        await Future<void>.delayed(Duration.zero);
        counter = v + 1;
      });
      await Future.wait([for (var i = 0; i < 5; i++) increment()]);
      expect(counter, 5);
    });

    test('different keys run concurrently', () async {
      final lock = KeyedLock();
      var active = 0;
      var maxActive = 0;
      Future<void> work(String key) => lock.synchronized(key, () async {
        active++;
        maxActive = active > maxActive ? active : maxActive;
        await Future<void>.delayed(Duration.zero);
        active--;
      });
      await Future.wait([work('a'), work('b')]);
      expect(maxActive, 2); // a and b overlapped
    });

    test('a throwing action does not wedge the queue', () async {
      final lock = KeyedLock();
      final order = <String>[];
      final failing = lock.synchronized('k', () async {
        order.add('a-start');
        throw StateError('boom');
      });
      await expectLater(failing, throwsStateError);
      await lock.synchronized('k', () async => order.add('b-ran'));
      expect(order, ['a-start', 'b-ran']);
    });
  });

  group('Wired into services — concurrent writers do not lose updates', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('two concurrent gem awards both persist', () async {
      final gem = GemService();
      await Future.wait([
        gem.awardQuestGems(
          claimKey: 'a',
          amount: 5,
          label: 'A',
          now: DateTime(2026, 1, 1),
        ),
        gem.awardQuestGems(
          claimKey: 'b',
          amount: 7,
          label: 'B',
          now: DateTime(2026, 1, 1),
        ),
      ]);
      expect(await gem.balance(), 12);
      expect((await gem.ledger()).length, 2);
    });

    test('two concurrent session saves both persist', () async {
      final store = WorkoutStorageService();
      // Partial sessions skip the post-save orchestration → the save is a pure
      // read-modify-write on workout_sessions, the exact race surface.
      await Future.wait([
        store.saveSession(_partialSession('a')),
        store.saveSession(_partialSession('b')),
      ]);
      final ids = (await store.getSessions()).map((s) => s.id).toSet();
      expect(ids, {'a', 'b'});
    });
  });
}

WorkoutSession _partialSession(String id) => WorkoutSession(
  id: id,
  date: DateTime(2026, 1, 1),
  muscleGroup: 'Chest',
  targetDurationMinutes: 30,
  actualDurationSeconds: 600,
  exercises: const [],
  estimatedCalories: 50,
  isPartial: true,
);
