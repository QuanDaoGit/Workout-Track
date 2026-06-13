import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../models/character_class.dart';
import '../avatar/ironbit_avatar.dart';

/// The traveling character: the user's own procedural pixel face stacked on
/// the shared **generic body sprite** (a 4-frame 24×42 walk strip authored at
/// `assets/adventure/body/`). The face is per-user (identity hook); the body
/// is generic (no per-avatar skin recolor). [frame] (0–3) is driven by the
/// diorama clock. If the body sheet is missing, it degrades to the code-drawn
/// chibi body (errorBuilder) so a face always walks.
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

  /// 0–3 — walk-cycle frame index.
  final int frame;

  /// Head width in logical pixels; the 24×42 body canvas scales from it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final cell = size / 20; // one sprite pixel (head is 20px wide)
    final canvasW = 24 * cell;
    final canvasH = 42 * cell;
    // Freeze the walk frame under reduced motion (the diorama also stops, but
    // PixelWalker may render in static contexts too).
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final f = reduceMotion ? 0 : (frame % 4);
    final trim = characterClass?.themeColor ?? const Color(0xFF4D4D72);
    return SizedBox(
      width: canvasW,
      height: canvasH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Generic body sprite — fills the 24×42 canvas; feet at row 40.
          Positioned.fill(
            child: Image.asset(
              'assets/adventure/body/frames/walk_$f.png',
              filterQuality: FilterQuality.none,
              fit: BoxFit.fill,
              errorBuilder: (_, _, _) => Padding(
                // Code-body fallback sits below the head anchor (rows ~15+).
                padding: EdgeInsets.only(top: 15 * cell),
                child: CustomPaint(
                  painter: _WalkerBodyPainter(frame: f, trim: trim),
                ),
              ),
            ),
          ),
          // The user's procedural face stacks at the rig head anchor (x+2, y0).
          Positioned(
            left: 2 * cell,
            top: 0,
            child: IronbitAvatar(spec: spec, size: size),
          ),
        ],
      ),
    );
  }
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
