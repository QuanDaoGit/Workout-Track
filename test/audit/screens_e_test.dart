import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/program_models.dart';
import 'package:workout_track/pages/Workout session/program_completion_reveal.dart';
import 'package:workout_track/pages/create_exercise_page.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';
import 'package:workout_track/pages/onboarding/rank_assessed_page.dart';

import 'audit_capture.dart';
import 'audit_seed.dart';

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
  testWidgets('audit/calibration_quiz', (t) =>
      cap(t, 'calibration_quiz',
          (_) => CalibrationQuizPage(
              questions: const [
                QuizQuestion.goal, QuizQuestion.frequency,
                QuizQuestion.experience, QuizQuestion.weightSex,
              ],
              onComplete: (_) {})),
      skip: skip, timeout: t90);
  testWidgets('audit/rank_assessed', (t) =>
      cap(t, 'rank_assessed',
          (_) => const RankAssessedPage(stats: {'STR': 42, 'AGI': 38, 'END': 45})),
      skip: skip, timeout: t90);
  testWidgets('audit/program_completion_reveal', (t) =>
      cap(t, 'program_completion_reveal',
          (_) => ProgramCompletionRevealScreen(
              completion: ProgramCompletion(
                  programId: 'full_body_3x', titleId: 'title_iron_will',
                  sessions: 24, completedAt: DateTime(2026, 6, 26)))),
      skip: skip, timeout: t90);
}
