import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/widgets/avatar/ironbit_avatar.dart';

void main() {
  group('AvatarSpec', () {
    test('json round-trips every field', () {
      const spec = AvatarSpec(
        skin: AvatarSkin.tone05,
        eyes: AvatarEyes.cyan,
        hair: AvatarHair.pony,
        hairColor: AvatarHairColor.red,
        expression: AvatarExpression.wink,
      );
      expect(AvatarSpec.fromJson(spec.toJson()), spec);
    });

    test('fromJson falls back per-field on unknown/missing values', () {
      final spec = AvatarSpec.fromJson({
        'skin': 'tone04',
        'eyes': 'laser', // unknown → fallback
        'hair': null, // missing → fallback
        'hairColor': 'gray',
        // expression absent → fallback
      });
      expect(spec.skin, AvatarSkin.tone04);
      expect(spec.eyes, AvatarSpec.fallback.eyes);
      expect(spec.hair, AvatarSpec.fallback.hair);
      expect(spec.hairColor, AvatarHairColor.gray);
      expect(spec.expression, AvatarSpec.fallback.expression);
      expect(AvatarSpec.fromJson(null), AvatarSpec.fallback);
    });

    test('defaults are gender-seeded via hair only', () {
      expect(AvatarDefaults.forSex(UserProfileSex.male).hair, AvatarHair.buzz);
      expect(
        AvatarDefaults.forSex(UserProfileSex.female).hair,
        AvatarHair.long,
      );
      expect(
        AvatarDefaults.forSex(UserProfileSex.preferNotToSay).hair,
        AvatarHair.swept,
      );
      // Everything else stays the neutral fallback.
      for (final sex in UserProfileSex.values) {
        final spec = AvatarDefaults.forSex(sex);
        expect(spec.skin, AvatarSpec.fallback.skin);
        expect(spec.eyes, AvatarSpec.fallback.eyes);
        expect(spec.hairColor, AvatarSpec.fallback.hairColor);
        expect(spec.expression, AvatarSpec.fallback.expression);
      }
    });

    test('random is deterministic per seed and stays friendly', () {
      expect(AvatarSpec.random(Random(7)), AvatarSpec.random(Random(7)));
      for (var seed = 0; seed < 50; seed++) {
        final spec = AvatarSpec.random(Random(seed));
        expect(
          AvatarSpec.friendlyExpressions,
          contains(spec.expression),
          reason: 'seed $seed produced ${spec.expression}',
        );
      }
    });
  });

  group('sprite grids', () {
    test('every grid is 20 rows of 20 legal chars', () {
      const legal = '.osSwebmthHd';
      final grids = debugAvatarGrids();
      expect(grids, isNotEmpty);
      grids.forEach((name, grid) {
        expect(grid.length, 20, reason: '$name row count');
        for (var i = 0; i < grid.length; i++) {
          expect(grid[i].length, 20, reason: '$name row $i length');
          for (final ch in grid[i].split('')) {
            expect(
              legal.contains(ch),
              isTrue,
              reason: '$name row $i has illegal char "$ch"',
            );
          }
        }
      });
    });
  });

  group('IronbitAvatar widget', () {
    testWidgets('renders a labeled sprite for every option combination axis', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IronbitAvatar(spec: AvatarSpec.fallback, size: 60),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Pixel avatar'), findsOneWidget);

      // Smoke every hair + expression grid through the painter.
      for (final hair in AvatarHair.values) {
        for (final expression in AvatarExpression.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: IronbitAvatar(
                  spec: AvatarSpec.fallback.copyWith(
                    hair: hair,
                    expression: expression,
                  ),
                  size: 40,
                ),
              ),
            ),
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  });
}
