import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/adventure_routes.dart';

/// Asset-manifest guard (Codex finding): every path the Adventure registry
/// references must actually be bundled — a missing pubspec entry or renamed
/// file fails here instead of degrading silently on device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every adventure route asset is bundled', () async {
    for (final route in adventureRoutes) {
      for (final asset in [
        route.emblemAsset,
        route.skyAsset,
        route.farAsset,
        route.groundAsset,
      ]) {
        final data = await rootBundle.load(asset);
        expect(data.lengthInBytes, greaterThan(0), reason: asset);
      }
    }
  });

  test('every find icon is bundled', () async {
    for (final find in adventureFinds) {
      final data = await rootBundle.load(find.iconAsset);
      expect(data.lengthInBytes, greaterThan(0), reason: find.iconAsset);
    }
  });

  test('the generic body sprite frames + generic emblem are bundled', () async {
    // v3 core surfaces: the 4-frame walk strip and the no-expedition emblem.
    // A non-recursive pubspec decl or a rename would fail here, not on device.
    for (var f = 0; f < 4; f++) {
      final asset = 'assets/adventure/body/frames/walk_$f.png';
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
    final emblem = await rootBundle.load(
      'assets/adventure/emblem_adventure_mode.png',
    );
    expect(emblem.lengthInBytes, greaterThan(0));
  });

  test('flavor pools are non-empty and route ids unique', () {
    final ids = adventureRoutes.map((r) => r.id).toSet();
    expect(ids.length, adventureRoutes.length);
    for (final route in adventureRoutes) {
      expect(route.flavorLines, isNotEmpty, reason: route.id);
    }
    final findIds = adventureFinds.map((f) => f.id).toSet();
    expect(findIds.length, adventureFinds.length);
  });
}
