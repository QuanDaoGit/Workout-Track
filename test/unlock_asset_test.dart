import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/loot_registry.dart';
import 'package:workout_track/models/loot_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loot registry uses unlock asset paths only', () {
    final visualItems = lootRegistry.where(
      (item) => item.category != LootCategory.titleBadge,
    );

    for (final item in visualItems) {
      expect(item.assetPath, startsWith('assets/unlocks/'), reason: item.id);
      expect(
        item.assetPath,
        isNot(startsWith('assets/loot/placeholders')),
        reason: item.id,
      );
      expect(File(item.assetPath).existsSync(), isTrue, reason: item.assetPath);
    }

    for (final path in [commonChestAsset, bossChestAsset]) {
      expect(path, startsWith('assets/unlocks/chests/'));
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('unlock assets have expected dimensions', () {
    for (final item in lootRegistry) {
      if (item.category == LootCategory.titleBadge) continue;

      final size = _pngSize(item.assetPath);
      switch (item.category) {
        case LootCategory.avatarFrame:
          expect(size, (width: 80, height: 80), reason: item.id);
        case LootCategory.homeTheme:
          expect(size, (width: 360, height: 200), reason: item.id);
        case LootCategory.battleEffect:
          expect(size, (width: 48, height: 48), reason: item.id);
        case LootCategory.titleBadge:
          fail('Title badges are text-only.');
      }
    }

    expect(_pngSize(commonChestAsset), (width: 64, height: 64));
    expect(_pngSize(bossChestAsset), (width: 64, height: 64));
  });

  test('avatar frame centers are transparent', () async {
    final frames = lootRegistry.where(
      (item) => item.category == LootCategory.avatarFrame,
    );

    for (final frame in frames) {
      final alpha = await _centerAlpha(frame.assetPath);
      expect(alpha, 0, reason: frame.id);
    }
  });
}

({int width, int height}) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24), reason: path);
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16, Endian.big),
    height: data.getUint32(20, Endian.big),
  );
}

Future<int> _centerAlpha(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final width = image.width;
  final height = image.height;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  expect(byteData, isNotNull, reason: path);

  final x = width ~/ 2;
  final y = height ~/ 2;
  final offset = ((y * width) + x) * 4;
  return byteData!.getUint8(offset + 3);
}
