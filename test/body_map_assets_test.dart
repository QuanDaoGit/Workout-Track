import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/body_map_regions.dart';

/// Asset manifest + alignment guard (Codex F2 + the asset-dependent-surface
/// learning): every mask the widget references must exist (an `errorBuilder`
/// would otherwise hide a typo'd path silently) and be the **same canvas size**,
/// or masks misregister against the base.
void main() {
  (int, int) pngDims(List<int> bytes) {
    final bd = ByteData.sublistView(Uint8List.fromList(bytes.sublist(0, 24)));
    return (bd.getUint32(16), bd.getUint32(20));
  }

  test('every referenced render asset exists and is uniformly 512×768', () {
    final files = <String>[
      'assets/body_diagram/render/base_front.png',
      'assets/body_diagram/render/base_back.png',
      for (final stem in frontMaskMuscle.keys)
        'assets/body_diagram/render/front/$stem.png',
      for (final stem in backMaskMuscle.keys)
        'assets/body_diagram/render/back/$stem.png',
    ];
    for (final path in files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'missing asset: $path');
      final (w, h) = pngDims(file.readAsBytesSync());
      expect(w, 512, reason: '$path width');
      expect(h, 768, reason: '$path height');
    }
  });
}
