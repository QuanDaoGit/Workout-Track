import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/xp_service.dart';

void main() {
  test('XP progress is shown within the current level span', () {
    final progress = XpService.progressForTotalXP(224);

    expect(progress.level, 3);
    expect(progress.levelBaseXP, 200);
    expect(progress.nextLevelXP, 500);
    expect(progress.currentLevelXP, 24);
    expect(progress.levelSpanXP, 300);
    expect(progress.label, '24 / 300 XP');
    expect(progress.fraction, closeTo(24 / 300, 0.0001));
  });
}
