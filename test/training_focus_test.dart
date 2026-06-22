import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/training_focus.dart';
import 'package:workout_track/widgets/onboarding/option_question.dart';

void main() {
  group('TrainingFocus', () {
    test('fromName round-trips every value; unknown/null → null', () {
      for (final f in TrainingFocus.values) {
        expect(TrainingFocus.fromName(f.name), f);
      }
      expect(TrainingFocus.fromName(null), isNull);
      expect(TrainingFocus.fromName('bogus'), isNull);
    });

    test('seeds the documented cold-start rep targets', () {
      expect(TrainingFocus.strength.defaultReps, 5);
      expect(TrainingFocus.muscle.defaultReps, 8);
      expect(TrainingFocus.endurance.defaultReps, 15);
    });

    test('every value carries a title, subtext and a control/ui asset icon', () {
      for (final f in TrainingFocus.values) {
        expect(f.title, isNotEmpty);
        expect(f.subtext, isNotEmpty);
        expect(f.assetIcon, startsWith('assets/icons/control/ui/'));
        expect(f.assetIcon, endsWith('.png'));
      }
    });
  });

  testWidgets('OptionList renders a pixel assetIcon as a full-color Image '
      '(not a tinted Material Icon)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionList(
            hasAnySelection: false,
            options: [
              OptionDef(
                title: 'STRENGTH',
                subtext: 'heavy lifts. low reps.',
                assetIcon: TrainingFocus.strength.assetIcon,
                isSelected: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });
}
