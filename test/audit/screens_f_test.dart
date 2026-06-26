import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/pages/profile_page.dart';
import 'package:workout_track/pages/root_page.dart';
import 'package:workout_track/services/exercise_catalog_service.dart';

import 'audit_capture.dart';
import 'audit_seed.dart';

// Heavy shells that need the real-event-loop `settle` to drain their deep load
// chains. (workout_logs + adventure are NOT here: they stall on rootBundle/plugin
// I/O inside their own fake-zone _load — their content is covered by the
// _body_map_* and expedition_dock_* component goldens instead.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t120 = const Timeout(Duration(seconds: 120));
  final skip = !autoUpdateGoldenFiles;

  Future<void> cap(WidgetTester t, String name, WidgetBuilder b) async {
    await seedDemo();
    // Warm the static catalog cache so any inner getFullCatalog() is synchronous.
    await t.runAsync(() => ExerciseCatalogService().getFullCatalog());
    await captureSurface(t, name: name, builder: b, precache: false, settle: true);
  }

  testWidgets('audit/profile', (t) =>
      cap(t, 'profile', (_) => const ProfilePage()), skip: skip, timeout: t120);
  testWidgets('audit/root', (t) =>
      cap(t, 'root', (_) => const RootPage()), skip: skip, timeout: t120);
}
