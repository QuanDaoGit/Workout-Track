import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/services/calibration_service.dart';
import 'package:workout_track/services/class_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Vanguard gating', () {
    test('unlockLevel is 10 for Vanguard, 1 for the rest', () {
      expect(CharacterClass.vanguard.unlockLevel, 10);
      expect(CharacterClass.assassin.unlockLevel, 1);
      expect(CharacterClass.bruiser.unlockLevel, 1);
      expect(CharacterClass.tank.unlockLevel, 1);
    });

    test(
      'availableRespecClasses excludes current and gates Vanguard at L10',
      () async {
        final svc = ClassService();
        await svc.selectClass(CharacterClass.assassin);

        final below = await svc.availableRespecClasses(9);
        expect(below, isNot(contains(CharacterClass.assassin))); // current
        expect(below, isNot(contains(CharacterClass.vanguard))); // L<10
        expect(
          below,
          containsAll([CharacterClass.bruiser, CharacterClass.tank]),
        );

        final atTen = await svc.availableRespecClasses(10);
        expect(atTen, contains(CharacterClass.vanguard));
      },
    );
  });

  group('respec lock window', () {
    test('locked during the 7-day signup soft lock', () async {
      final svc = ClassService();
      await svc.selectClass(CharacterClass.bruiser);
      final confirmedAt = DateTime(2026, 1, 1, 12);
      await CalibrationService().markClassConfirmed(at: confirmedAt);

      // Day 3 — still locked.
      final day3 = await svc.respecStatus(
        now: confirmedAt.add(const Duration(days: 3)),
      );
      expect(day3.availability, RespecAvailability.locked);
      expect(day3.daysRemaining, 4);

      // Day 8 — available.
      final day8 = await svc.respecStatus(
        now: confirmedAt.add(const Duration(days: 8)),
      );
      expect(day8.availability, RespecAvailability.available);
    });

    test('legacy users with no confirm time are not locked', () async {
      final svc = ClassService();
      await svc.selectClass(CharacterClass.bruiser);
      // No markClassConfirmed call.
      final status = await svc.respecStatus(now: DateTime(2026, 1, 1));
      expect(status.availability, RespecAvailability.available);
    });
  });

  group('respec + 30-day cooldown', () {
    test('respec records former path, sets cooldown, then frees up', () async {
      final svc = ClassService();
      await svc.selectClass(CharacterClass.assassin);
      final confirmedAt = DateTime(2026, 1, 1);
      await CalibrationService().markClassConfirmed(at: confirmedAt);

      final respecTime = DateTime(2026, 2, 1); // well past the 7-day lock
      await svc.respec(CharacterClass.tank, now: respecTime);

      final state = await svc.getState();
      expect(state!.currentClass, CharacterClass.tank);
      expect(state.mostRecentFormerClass!.clazz, CharacterClass.assassin);
      expect(state.nextRespecAt, respecTime.add(const Duration(days: 30)));

      // 10 days later — still on cooldown.
      final cd = await svc.respecStatus(
        now: respecTime.add(const Duration(days: 10)),
      );
      expect(cd.availability, RespecAvailability.cooldown);
      expect(cd.daysRemaining, 20);

      // 31 days later — available again.
      final free = await svc.respecStatus(
        now: respecTime.add(const Duration(days: 31)),
      );
      expect(free.availability, RespecAvailability.available);
    });

    test('former paths accumulate across multiple respecs', () async {
      final svc = ClassService();
      await svc.selectClass(CharacterClass.assassin);
      await CalibrationService().markClassConfirmed(at: DateTime(2026, 1, 1));

      await svc.respec(CharacterClass.bruiser, now: DateTime(2026, 2, 1));
      await svc.respec(CharacterClass.tank, now: DateTime(2026, 3, 5));

      final state = await svc.getState();
      expect(state!.formerClasses.map((f) => f.clazz).toList(), [
        CharacterClass.assassin,
        CharacterClass.bruiser,
      ]);
      expect(state.currentClass, CharacterClass.tank);
    });
  });
}
