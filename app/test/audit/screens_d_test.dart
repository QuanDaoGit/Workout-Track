import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/character_draft.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/create_exercise_page.dart';
import 'package:workout_track/pages/onboarding/calibration_loading_page.dart';
import 'package:workout_track/pages/onboarding/class_reveal_screen.dart';
import 'package:workout_track/pages/onboarding/name_screen.dart';
import 'package:workout_track/pages/onboarding/program_loading_page.dart';
import 'package:workout_track/pages/onboarding/program_selection_page.dart';
import 'package:workout_track/pages/onboarding/reminders_primer_page.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';

import 'audit_capture.dart';
import 'audit_seed.dart';

const _cal = CalibrationResult(
  goal: BodyGoal.cut, freq: TrainingFreq.mid, exp: Experience.beginner,
  bodyWeightKg: 72, sex: UserProfileSex.preferNotToSay, clazz: CharacterClass.assassin,
);
final _draft = CharacterDraft(calibration: _cal, classConfirmedAt: DateTime(2026, 5, 29, 12));
const _pre = PreClassAnswers(
    goal: BodyGoal.cut, bodyWeightKg: 72, sex: UserProfileSex.preferNotToSay);
final _char = Character(
  name: 'Nova', calibration: _cal, classConfirmedAt: DateTime(2026, 6, 1),
  characterName: 'Nova', createdAt: DateTime(2026, 5, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t90 = const Timeout(Duration(seconds: 90));
  final skip = !autoUpdateGoldenFiles;

  Future<void> cap(WidgetTester t, String name, WidgetBuilder b) async {
    await seedDemo();
    await captureSurface(t, name: name, builder: b, precache: false);
  }

  testWidgets('audit/create_exercise', (t) =>
      cap(t, 'create_exercise', (_) => const CreateExercisePage()), skip: skip, timeout: t90);
  testWidgets('audit/name', (t) =>
      cap(t, 'name', (_) => NameScreen(draft: _draft)), skip: skip, timeout: t90);
  testWidgets('audit/program_selection', (t) =>
      cap(t, 'program_selection', (_) => ProgramSelectionPage(draft: _draft)),
      skip: skip, timeout: t90);
  testWidgets('audit/class_reveal_screen', (t) =>
      cap(t, 'class_reveal_screen',
          (_) => ClassRevealScreen(answers: _pre, onConfirmed: () {})),
      skip: skip, timeout: t90);
  testWidgets('audit/calibration_loading', (t) =>
      cap(t, 'calibration_loading',
          (_) => CalibrationLoadingPage(answers: _pre, onCalibrated: (_) async {}, onReveal: (_) async {})),
      skip: skip, timeout: t90);
  testWidgets('audit/program_loading', (t) =>
      cap(t, 'program_loading',
          (_) => ProgramLoadingPage(result: _cal, onComplete: () {})),
      skip: skip, timeout: t90);
  testWidgets('audit/start_gate', (t) =>
      cap(t, 'start_gate',
          (_) => StartGateScreen(character: _char, avatarSpec: AvatarSpec.fallback)),
      skip: skip, timeout: t90);
  testWidgets('audit/reminders_primer', (t) =>
      cap(t, 'reminders_primer',
          (_) => RemindersPrimerPage(
              character: _char, avatarSpec: AvatarSpec.fallback,
              trainingWeekdays: const {1, 3, 5})),
      skip: skip, timeout: t90);
}
