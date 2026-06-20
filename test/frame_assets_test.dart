import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/loot_registry.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/loot_item.dart';
import 'package:workout_track/widgets/loot_avatar_frame.dart';

List<LootItem> get _frames => lootRegistry
    .where((i) => i.category == LootCategory.avatarFrame)
    .toList();

List<String> get _allFramePaths => [
  for (final f in _frames)
    for (var i = 0; i < f.frameCount; i++) f.frameAt(i),
];

Widget _host(LootItem f, {bool reduce = false}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        // Nested below MaterialApp so the widget actually reads this value.
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: Center(
          child: LootAvatarFrame(
            avatarSpec: AvatarSpec.fallback,
            framePath: f.assetPath,
            frameCount: f.frameCount,
            animate: true,
            size: 130,
          ),
        ),
      ),
    ),
  ),
);

String _currentFrameAsset(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as AssetImage).assetName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every declared frame asset (incl. animation frames) is bundled', () async {
    expect(_allFramePaths.length, greaterThanOrEqualTo(26)); // 6 static + 2×10
    for (final path in _allFramePaths) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: '$path missing/empty');
    }
  });

  testWidgets('renders every frame without throwing', (tester) async {
    for (final f in _frames) {
      await tester.pumpWidget(_host(f));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull, reason: f.id);
    }
    await tester.pumpWidget(const SizedBox()); // dispose → cancel timers
  });

  testWidgets('frame image wires an errorBuilder fallback', (tester) async {
    final stone = _frames.firstWhere((f) => f.id == 'frame_stone');
    await tester.pumpWidget(_host(stone));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.errorBuilder, isNotNull);
  });

  testWidgets('animated frame holds the poster under reduced motion', (
    tester,
  ) async {
    final inferno = _frames.firstWhere((f) => f.id == 'frame_inferno');
    await tester.pumpWidget(_host(inferno, reduce: true));
    expect(_currentFrameAsset(tester), inferno.frameAt(0));
    await tester.pump(const Duration(seconds: 1));
    expect(_currentFrameAsset(tester), inferno.frameAt(0)); // never advanced
  });

  testWidgets('reduced motion toggled AFTER mount freezes on the poster', (
    tester,
  ) async {
    final voidFrame = _frames.firstWhere((f) => f.id == 'frame_void');
    await tester.pumpWidget(_host(voidFrame, reduce: false));
    await tester.pump(const Duration(milliseconds: 300)); // advance a few frames

    await tester.pumpWidget(_host(voidFrame, reduce: true)); // toggle on
    await tester.pump();
    expect(_currentFrameAsset(tester), voidFrame.frameAt(0)); // frozen
    await tester.pumpWidget(const SizedBox());
  });

  test('new 260 frames keep the avatar aperture clear (no clip/drift)', () async {
    // Every non-legacy frame must be 260×260 with the central 20/26 aperture
    // (avatar footprint ≈ px 30..229) fully transparent — so no frame style or
    // animation frame ever paints over / crops the procedural face (Codex C1).
    final newFrames = _frames.where((f) => f.id != 'frame_iron');
    for (final f in newFrames) {
      for (var i = 0; i < f.frameCount; i++) {
        final path = f.frameAt(i);
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 260, reason: '$path width');
        expect(image.height, 260, reason: '$path height');
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int alphaAt(int x, int y) => bytes.getUint8((y * 260 + x) * 4 + 3);
        // Sample safely inside the 200px aperture (34..226) — any opaque pixel
        // here would occlude the avatar.
        for (var y = 34; y <= 226; y += 12) {
          for (var x = 34; x <= 226; x += 12) {
            expect(
              alphaAt(x, y),
              0,
              reason: '$path opaque at ($x,$y) would clip the avatar',
            );
          }
        }
      }
    }
  });
}
