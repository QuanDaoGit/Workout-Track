import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/world_window.dart';

/// Pins the world-window's hour → sky mapping to an average, season-agnostic
/// day (sunrise ≈ 6, noon ≈ 12, sunset ≈ 18; night owns every dark hour).
/// Names are historical: evening = the night (moon) frame, afternoon = sunset.
void main() {
  // Any calendar day works — only the hour is read.
  RoomTimeOfDay at(int hour) => roomTimeOfDayNow(DateTime(2026, 3, 21, hour));

  group('roomTimeOfDayNow', () {
    test('the dark hours — including across midnight — are night', () {
      // The regression this guards: 00:00 used to paint a sunrise.
      for (final h in [0, 1, 3, 5, 19, 21, 23]) {
        expect(at(h), RoomTimeOfDay.evening, reason: '$h:00 should be night');
      }
    });

    test('sunrise is the early-morning band', () {
      expect(at(6), RoomTimeOfDay.morning);
      expect(at(8), RoomTimeOfDay.morning);
    });

    test('daylight spans mid-morning to late afternoon', () {
      expect(at(9), RoomTimeOfDay.noon);
      expect(at(12), RoomTimeOfDay.noon);
      expect(at(16), RoomTimeOfDay.noon);
    });

    test('sunset brackets the ~18:00 average sundown', () {
      expect(at(17), RoomTimeOfDay.afternoon);
      expect(at(18), RoomTimeOfDay.afternoon);
    });

    test('boundaries flip on exactly the right hour', () {
      expect(at(5), RoomTimeOfDay.evening); // last pre-dawn night hour
      expect(at(6), RoomTimeOfDay.morning); // sunrise starts
      expect(at(9), RoomTimeOfDay.noon); // daylight starts
      expect(at(17), RoomTimeOfDay.afternoon); // sunset starts
      expect(at(19), RoomTimeOfDay.evening); // night returns
    });

    test('every hour resolves to one bucket (no gaps)', () {
      for (var h = 0; h < 24; h++) {
        expect(() => at(h), returnsNormally);
      }
    });
  });
}
