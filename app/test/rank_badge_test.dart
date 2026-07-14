import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/arcade_badge.dart';
import 'package:workout_track/widgets/rank_badge.dart';

void main() {
  group('rankColor ladder', () {
    test('top tiers read red, mid tiers warm/green, recruit muted', () {
      expect(rankColor('Legend'), kDanger);
      expect(rankColor('Champion'), kDanger);
      expect(rankColor('Knight'), kAmber);
      expect(rankColor('Squire'), kNeon);
      expect(rankColor('Recruit'), kMutedText);
    });

    test('an unknown rank falls back to muted, never a loud colour', () {
      expect(rankColor('Overlord'), kMutedText);
    });
  });

  testWidgets('RankBadge wires the ladder colour into the shared ArcadeBadge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: RankBadge(rank: 'Champion'),
      ),
    );

    final badge = tester.widget<ArcadeBadge>(find.byType(ArcadeBadge));
    expect(badge.label, 'Champion');
    expect(badge.color, kDanger, reason: 'Champion must render red');
    expect(badge.filled, isFalse, reason: 'only Legend gets the fill wash');
  });

  testWidgets('Legend gets the filled colour wash', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: RankBadge(rank: 'Legend'),
      ),
    );

    final badge = tester.widget<ArcadeBadge>(find.byType(ArcadeBadge));
    expect(badge.color, kDanger);
    expect(badge.filled, isTrue);
  });
}
