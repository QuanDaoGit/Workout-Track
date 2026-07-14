import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/pages/adventure_page.dart';
import 'package:workout_track/pages/avatar_customizer_page.dart';
import 'package:workout_track/pages/body_metrics_chart_page.dart';
import 'package:workout_track/pages/body_metrics_history_page.dart';
import 'package:workout_track/pages/body_metrics_onboarding_page.dart';
import 'package:workout_track/pages/class_reveal_page.dart';
import 'package:workout_track/pages/goal_selection_page.dart';
import 'package:workout_track/pages/workout_page.dart';

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

  testWidgets('audit/workout_logs', (t) =>
      cap(t, 'workout_logs', (_) => const WorkoutLogsPage()),
      skip: skip, timeout: t90);
  testWidgets('audit/workout_library', (t) =>
      cap(t, 'workout_library', (_) => const WorkoutLibraryPage()),
      skip: skip, timeout: t90);
  testWidgets('audit/goal_selection', (t) =>
      cap(t, 'goal_selection', (_) => const GoalSelectionPage()),
      skip: skip, timeout: t90);
  testWidgets('audit/avatar_customizer', (t) =>
      cap(t, 'avatar_customizer', (_) => const AvatarCustomizerPage()),
      skip: skip, timeout: t90);
  testWidgets('audit/body_metrics_chart', (t) =>
      cap(t, 'body_metrics_chart', (_) => const BodyMetricsChartPage()),
      skip: skip, timeout: t90);
  testWidgets('audit/body_metrics_history', (t) =>
      cap(t, 'body_metrics_history', (_) => const BodyMetricsHistoryPage()),
      skip: skip, timeout: t90);
  testWidgets('audit/body_metrics_onboarding', (t) =>
      cap(t, 'body_metrics_onboarding', (_) => const BodyMetricsOnboardingPage()),
      skip: skip, timeout: t90);
  testWidgets('audit/adventure', (t) =>
      cap(t, 'adventure', (_) => const AdventurePage()),
      skip: skip, timeout: t90);
  testWidgets('audit/class_reveal', (t) =>
      cap(t, 'class_reveal',
          (_) => const ClassRevealPage(characterClass: CharacterClass.assassin)),
      skip: skip, timeout: t90);
}
