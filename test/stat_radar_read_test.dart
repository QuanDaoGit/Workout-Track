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
        StatRadarRead.dominantAxis({'STR': 564, 'AGI': 346, 'END': 297}),
        'STR',
      );
      expect(
        StatRadarRead.buildRead({'STR': 564, 'AGI': 346, 'END': 297}),
        'POWER',
      );

      expect(
        StatRadarRead.dominantAxis({'STR': 336, 'AGI': 512, 'END': 332}),
        'AGI',
      );
      expect(
        StatRadarRead.buildRead({'STR': 336, 'AGI': 512, 'END': 332}),
        'CONTROL',
      );

      expect(
        StatRadarRead.dominantAxis({'STR': 353, 'AGI': 319, 'END': 454}),
        'END',
      );
      expect(
        StatRadarRead.buildRead({'STR': 353, 'AGI': 319, 'END': 454}),
        'STAMINA',
      );
    });

    test('returns balanced for near ties', () {
      expect(
        StatRadarRead.dominantAxis({'STR': 340, 'AGI': 320, 'END': 315}),
        isNull,
      );
      expect(
        StatRadarRead.buildRead({'STR': 340, 'AGI': 320, 'END': 315}),
        'BALANCED',
      );
    });
  });
}
