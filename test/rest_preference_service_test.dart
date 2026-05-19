import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/services/rest_preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RestPreferenceService.defaultForClass', () {
    test('Tank rests 180 seconds', () {
      expect(
        RestPreferenceService.defaultForClass(CharacterClass.tank),
        180,
      );
    });

    test('Bruiser rests 90 seconds', () {
      expect(
        RestPreferenceService.defaultForClass(CharacterClass.bruiser),
        90,
      );
    });

    test('Assassin rests 60 seconds', () {
      expect(
        RestPreferenceService.defaultForClass(CharacterClass.assassin),
        60,
      );
    });
  });

  group('RestPreferenceService persistence', () {
    test('get returns null when nothing is set', () async {
      final service = RestPreferenceService();
      expect(await service.get(), isNull);
    });

    test('round-trip persists the value', () async {
      final service = RestPreferenceService();
      await service.set(105);
      expect(await service.get(), 105);
    });

    test('set overwrites the previous value', () async {
      final service = RestPreferenceService();
      await service.set(60);
      await service.set(150);
      expect(await service.get(), 150);
    });
  });
}
