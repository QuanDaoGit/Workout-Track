import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/stat_radar_read.dart';

void main() {
  group('StatRadarRead', () {
    test('returns neutral meaning for each visible axis', () {
      expect(StatRadarRead.visibleStats, ['STR', 'AGI', 'END']);
      expect(StatRadarRead.meaningForAxis('STR'), 'POWER');
      expect(StatRadarRead.meaningForAxis('AGI'), 'CONTROL');
      expect(StatRadarRead.meaningForAxis('END'), 'STAMINA');
      expect(StatRadarRead.meaningForAxis('DEF'), 'BALANCED');
    });

    test('defines one shared axis-to-class readability contract', () {
      expect(StatRadarRead.classForAxis('STR'), 'bruiser');
      expect(StatRadarRead.classForAxis('AGI'), 'assassin');
      expect(StatRadarRead.classForAxis('END'), 'tank');
      expect(StatRadarRead.axisForClass('bruiser'), 'STR');
      expect(StatRadarRead.axisForClass('assassin'), 'AGI');
      expect(StatRadarRead.axisForClass('tank'), 'END');
      expect(StatRadarRead.readableClassNames, ['assassin', 'bruiser', 'tank']);
      expect(StatRadarRead.classForAxis('VIT'), isNull);
      expect(StatRadarRead.axisForClass('vanguard'), isNull);
    });

    test('detects readable dominant builds', () {
      expect(
        StatRadarRead.dominantAxis({'STR': 5640, 'AGI': 3460, 'END': 2970}),
        'STR',
      );
      expect(
        StatRadarRead.buildRead({'STR': 5640, 'AGI': 3460, 'END': 2970}),
        'POWER',
      );

      expect(
        StatRadarRead.dominantAxis({'STR': 3360, 'AGI': 5120, 'END': 3320}),
        'AGI',
      );
      expect(
        StatRadarRead.buildRead({'STR': 3360, 'AGI': 5120, 'END': 3320}),
        'CONTROL',
      );

      expect(
        StatRadarRead.dominantAxis({'STR': 3530, 'AGI': 3190, 'END': 4540}),
        'END',
      );
      expect(
        StatRadarRead.buildRead({'STR': 3530, 'AGI': 3190, 'END': 4540}),
        'STAMINA',
      );
    });

    test('returns balanced for near ties', () {
      expect(
        StatRadarRead.dominantAxis({'STR': 3400, 'AGI': 3200, 'END': 3150}),
        isNull,
      );
      expect(
        StatRadarRead.buildRead({'STR': 3400, 'AGI': 3200, 'END': 3150}),
        'BALANCED',
      );
    });
  });
}
