import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/program_models.dart';
import 'package:workout_track/pages/home.dart';

void main() {
  test('first quest launches the program Day 1 on a program workout day', () {
    const day = ProgramDay(
      dayNumber: 1,
      type: ProgramDayType.workout,
      focus: MuscleFocus.fullBody,
      label: 'FULL BODY A',
    );

    final plan = firstQuestMissionPlan(day);

    expect(plan.launchesProgramDay, isTrue);
    expect(plan.detail, 'Begin Day 1 · FULL BODY A.');
  });

  test('first quest falls back to the blank picker without a program', () {
    final plan = firstQuestMissionPlan(null);

    expect(plan.launchesProgramDay, isFalse);
    expect(plan.detail, 'Log your first workout to begin.');
  });

  test('first quest falls back to the blank picker on a rest-day-first case', () {
    const restDay = ProgramDay(
      dayNumber: 1,
      type: ProgramDayType.rest,
      label: 'REST',
    );

    final plan = firstQuestMissionPlan(restDay);

    expect(plan.launchesProgramDay, isFalse);
    expect(plan.detail, 'Log your first workout to begin.');
  });
}
