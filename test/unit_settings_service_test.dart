import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/services/unit_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('defaults', () {
    test('weight defaults to lbs, height to ft-in', () async {
      final service = UnitSettingsService();
      expect(await service.weightUnit(), WeightUnit.lbs);
      expect(await service.heightUnit(), LengthUnit.ftIn);
    });
  });

  group('persistence', () {
    test('weight unit round-trips', () async {
      final service = UnitSettingsService();
      await service.setWeightUnit(WeightUnit.kg);
      expect(await service.weightUnit(), WeightUnit.kg);
    });

    test('height unit round-trips', () async {
      final service = UnitSettingsService();
      await service.setHeightUnit(LengthUnit.cm);
      expect(await service.heightUnit(), LengthUnit.cm);
    });
  });

  group('Units runtime holder', () {
    test('load reads persisted values into the statics', () async {
      final service = UnitSettingsService();
      await service.setWeightUnit(WeightUnit.kg);
      await service.setHeightUnit(LengthUnit.cm);

      await Units.load();
      expect(Units.weight, WeightUnit.kg);
      expect(Units.height, LengthUnit.cm);
    });

    test('setWeight/setHeight update the static and persist', () async {
      await Units.setWeight(WeightUnit.lbs);
      await Units.setHeight(LengthUnit.ftIn);
      expect(Units.weight, WeightUnit.lbs);
      expect(Units.height, LengthUnit.ftIn);

      // A fresh load reflects what was persisted.
      await Units.load();
      expect(Units.weight, WeightUnit.lbs);
      expect(Units.height, LengthUnit.ftIn);
    });
  });
}
