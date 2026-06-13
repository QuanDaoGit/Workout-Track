import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../models/character_class.dart';
import '../avatar/ironbit_avatar.dart';

/// The traveling character: the user's own procedural pixel face on a
/// code-drawn chibi body, in the avatar grid language (zero image assets, so
/// all ~8,100 faces work automatically). Two leg frames + a 1px head bob
/// read as "walking" in pixel dialect; [frame] is driven by the diorama's
/// clock. Class color tints the gear band.
class PixelWalker extends StatelessWidget {
  const PixelWalker({
    super.key,
    required this.spec,
    required this.characterClass,
    this.frame = 0,
    this.size = 40,
  });

  final AvatarSpec spec;
  final CharacterClass? characterClass;

  /// 0 or 1 — alternating stride frames.
  final int frame;

  /// Head width in logical pixels; the body scales from it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final cell = size / 20; // one sprite pixel
    final bodyHeight = cell * _bodyRows;
    final bob = frame.isEven ? 0.0 : cell;
    return SizedBox(
      width: size,
      // Head overlaps the body's top row so the neck seam stays hidden
      // through the bob.
      height: size + bodyHeight - cell + cell,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: size - cell,
            left: 0,
            child: CustomPaint(
              size: Size(size, bodyHeight),
              painter: _WalkerBodyPainter(
                frame: frame,
                trim: characterClass?.themeColor ?? const Color(0xFF4D4D72),
              ),
            ),
          ),
          Positioned(
            top: bob,
            left: 0,
            child: IronbitAvatar(spec: spec, size: size),
          ),
        ],
      ),
    );
  }

  static const _bodyRows = 10;
}

class _WalkerBodyPainter extends CustomPainter {
  const _WalkerBodyPainter({required this.frame, required this.trim});

  final int frame;
  final Color trim;

  // Body grids, avatar legend style: t torso, d torso shade, C class trim,
  // l leg, b boot, . transparent. 20 wide × 10 tall.
  static const _stride = [
    '......tttttttt......',
    '.....tttttttttt.....',
    '.....ttttttttttd....',
    '.....CCCCCCCCCC.....',
    '......tttttttt......',
    '......dttttttd......',
    '.....ll......ll.....',
    '.....ll......ll.....',
    '....ll........ll....',
    '....bb........bb....',
  ];

  static const _passing = [
    '......tttttttt......',
    '.....tttttttttt.....',
    '.....ttttttttttd....',
    '.....CCCCCCCCCC.....',
    '......tttttttt......',
    '......dttttttd......',
    '.......ll..ll.......',
    '.......ll..ll.......',
    '.......ll..ll.......',
    '.......bb..bb.......',
  ];

  static const _torso = Color(0xFF2A2A48);
  static const _torsoShade = Color(0xFF1F1F33);
  static const _leg = Color(0xFF32324E);
  static const _boot = Color(0xFF14141F);

  Color? _colorFor(String ch) => switch (ch) {
    't' => _torso,
    'd' => _torsoShade,
    'C' => trim,
    'l' => _leg,
    'b' => _boot,
    _ => null,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final grid = frame.isEven ? _stride : _passing;
    // Snap gridlines to whole pixels (avatar painter idiom — no AA means
    // fractional cells would seam).
    final xEdges = List<double>.generate(
      21,
      (i) => (i * size.width / 20).roundToDouble(),
    );
    final yEdges = List<double>.generate(
      grid.length + 1,
      (i) => (i * size.height / grid.length).roundToDouble(),
    );
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (var x = 0; x < 20; x++) {
        final color = _colorFor(row[x]);
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTRB(xEdges[x], yEdges[y], xEdges[x + 1], yEdges[y + 1]),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WalkerBodyPainter old) =>
      old.frame != frame || old.trim != trim;
}
