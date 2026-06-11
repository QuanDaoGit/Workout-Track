import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../theme/tokens.dart';

/// Renders the layered 20x20 pixel-face avatar at any size with zero image
/// assets. Grid data is copied verbatim from the design source
/// ("Avatar System.html") — if the design changes, re-copy the grids.
///
/// Render at integer multiples of 20 (40, 60, 96, 160...) so every sprite
/// pixel maps to whole screen pixels; the painter snaps gridlines so other
/// sizes stay seam-free regardless.
class IronbitAvatar extends StatelessWidget {
  const IronbitAvatar({super.key, required this.spec, this.size = 60});

  final AvatarSpec spec;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Pixel avatar',
      child: CustomPaint(
        size: Size.square(size),
        painter: IronbitAvatarPainter(spec),
      ),
    );
  }
}

class IronbitAvatarPainter extends CustomPainter {
  IronbitAvatarPainter(this.spec);

  final AvatarSpec spec;

  static const int _grid = 20;

  Color? _colorFor(String ch) {
    final skin = _skins[spec.skin]!;
    final hair = _hairColors[spec.hairColor]!;
    return switch (ch) {
      's' => skin.base,
      'S' => skin.shade,
      'o' || 'm' => skin.outline,
      'w' || 't' => _white,
      'e' => _eyeColors[spec.eyes],
      'b' || 'd' => hair.shade,
      'h' => hair.base,
      'H' => hair.highlight,
      _ => null, // '.'
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    // Snap gridlines to whole pixels so adjacent cells share exact edges —
    // no AA means fractional cell widths would otherwise seam.
    final edges = List<double>.generate(
      _grid + 1,
      (i) => (i * side / _grid).roundToDouble(),
    );
    final paintObj = Paint()..isAntiAlias = false;
    // Layer order matters: expression overpaints eyes (wink closes one eye),
    // hair overpaints everything.
    final layers = [
      _head,
      _eyesGrid,
      _expressionGrids[spec.expression]!,
      _hairGrids[spec.hair]!,
    ];
    for (final grid in layers) {
      for (var y = 0; y < _grid; y++) {
        final row = grid[y];
        for (var x = 0; x < _grid; x++) {
          final color = _colorFor(row[x]);
          if (color == null) continue;
          paintObj.color = color;
          canvas.drawRect(
            Rect.fromLTRB(edges[x], edges[y], edges[x + 1], edges[y + 1]),
            paintObj,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(IronbitAvatarPainter oldDelegate) =>
      oldDelegate.spec != spec;
}

/// Palette swatches for the customizer's color-bearing option chips.
Color avatarSkinSwatch(AvatarSkin skin) => _skins[skin]!.base;

Color avatarEyeSwatch(AvatarEyes eyes) => _eyeColors[eyes]!;

Color avatarHairColorSwatch(AvatarHairColor color) => _hairColors[color]!.base;

/// All sprite grids by debug name — for tests that verify grid shape.
@visibleForTesting
Map<String, List<String>> debugAvatarGrids() => {
  'head': _head,
  'eyes': _eyesGrid,
  for (final e in _expressionGrids.entries) 'expr ${e.key.name}': e.value,
  for (final e in _hairGrids.entries) 'hair ${e.key.name}': e.value,
};

// ---------------------------------------------------------------------------
// Palettes (sprite art values from the design source — not theme tokens,
// except the neon/cyan eyes which intentionally match the app accents)
// ---------------------------------------------------------------------------

class _Skin {
  const _Skin(this.base, this.shade, this.outline);

  final Color base, shade, outline;
}

const Map<AvatarSkin, _Skin> _skins = {
  AvatarSkin.tone01: _Skin(
    Color(0xFFFFE3C4),
    Color(0xFFE5B98F),
    Color(0xFF8A5A40),
  ),
  AvatarSkin.tone02: _Skin(
    Color(0xFFF2C89C),
    Color(0xFFD29B6A),
    Color(0xFF6E4530),
  ),
  AvatarSkin.tone03: _Skin(
    Color(0xFFD9A066),
    Color(0xFFB27A45),
    Color(0xFF5C3A22),
  ),
  AvatarSkin.tone04: _Skin(
    Color(0xFFA87048),
    Color(0xFF7E4F2E),
    Color(0xFF3F2719),
  ),
  AvatarSkin.tone05: _Skin(
    Color(0xFF6F4827),
    Color(0xFF54331A),
    Color(0xFF2E1B0E),
  ),
};

const Map<AvatarEyes, Color> _eyeColors = {
  AvatarEyes.brown: Color(0xFF8B5A2B),
  AvatarEyes.blue: Color(0xFF4D7CFF),
  AvatarEyes.hazel: Color(0xFFC29A4B),
  AvatarEyes.green: Color(0xFF44B04A),
  AvatarEyes.neon: kNeon,
  AvatarEyes.cyan: kCyan,
};

class _Hair {
  const _Hair(this.base, this.highlight, this.shade);

  final Color base, highlight, shade;
}

const Map<AvatarHairColor, _Hair> _hairColors = {
  AvatarHairColor.black: _Hair(
    Color(0xFF32324E),
    Color(0xFF4D4D72),
    Color(0xFF1F1F33),
  ),
  AvatarHairColor.brown: _Hair(
    Color(0xFF6B4628),
    Color(0xFF8C633C),
    Color(0xFF462C18),
  ),
  AvatarHairColor.blonde: _Hair(
    Color(0xFFD9B45C),
    Color(0xFFEFD68C),
    Color(0xFFA37F38),
  ),
  AvatarHairColor.red: _Hair(
    Color(0xFFA8482A),
    Color(0xFFCC6B3D),
    Color(0xFF75301B),
  ),
  AvatarHairColor.gray: _Hair(
    Color(0xFF9A9AAA),
    Color(0xFFC2C2D0),
    Color(0xFF6A6A7E),
  ),
};

const Color _white = Color(0xFFFFFFFF);

// ---------------------------------------------------------------------------
// Sprite grids — 20x20, one char per pixel. Legend:
//   . transparent | o outline | s skin | S skin shade
//   w highlight   | e eye     | b brow | m mouth | t teeth
//   h hair        | H hair highlight  | d hair shade
// ---------------------------------------------------------------------------

const String _blankRow = '....................';

List<String> _sparse(Map<int, String> rows) =>
    List<String>.generate(20, (i) => rows[i] ?? _blankRow);

final List<String> _head = [
  '....................',
  '....................',
  '....................',
  '......oooooooo......',
  '.....osssssssso.....',
  '....oSssssssssso....',
  '....oSssssssssso....',
  '....oSssssssssso....',
  '....oSssssssssso....',
  '....oSssssssssso....',
  '....oSssssssssso....',
  '....oSsssSssssso....',
  '....oSssssssssso....',
  '....oSssssssssso....',
  '.....oSssssssso.....',
  '......ooSsssoo......',
  '........oooo........',
  '....................',
  '....................',
  '....................',
];

final List<String> _eyesGrid = _sparse({
  8: '.......we..we.......',
  9: '.......ee..ee.......',
});

final Map<AvatarExpression, List<String>> _expressionGrids = {
  AvatarExpression.ready: _sparse({
    6: '.......bb..bb.......',
    13: '.........mm.........',
  }),
  AvatarExpression.grin: _sparse({
    5: '.......bb..bb.......',
    12: '.......mttttm.......',
    13: '........mmmm........',
  }),
  AvatarExpression.focused: _sparse({
    5: '.......b....b.......',
    6: '........b..b........',
    13: '........mmmm........',
  }),
  AvatarExpression.sad: _sparse({
    5: '........b..b........',
    6: '.......b....b.......',
    12: '.........mm.........',
    13: '........m..m........',
  }),
  AvatarExpression.shock: _sparse({
    5: '.......bb..bb.......',
    12: '.........mm.........',
    13: '.........mm.........',
  }),
  AvatarExpression.wink: _sparse({
    6: '.......bb..bb.......',
    8: '...........ss.......',
    9: '...........mm.......',
    12: '...........m........',
    13: '........mmm.........',
  }),
};

final Map<AvatarHair, List<String>> _hairGrids = {
  AvatarHair.spike: _sparse({
    1: '.....h...h...H......',
    2: '....hhh.hhh.hHH.....',
    3: '....hhhhhhhhhHHh....',
    4: '....hhhhhhhhhhhh....',
    5: '....h.h..h..h..h....',
    6: '....h..........h....',
  }),
  AvatarHair.swept: _sparse({
    1: '.....hhhhhhhhh......',
    2: '....hhhhhhHHHHhh....',
    3: '....hhhhhhhhHHhh....',
    4: '....hh....hhhhhh....',
    5: '....h.......hhhh....',
    6: '....h.........hh....',
  }),
  AvatarHair.buzz: _sparse({
    2: '......hhhHHhhh......',
    3: '.....hhhhhhhhhh.....',
    4: '....hh........hh....',
    5: '....h..........h....',
  }),
  AvatarHair.curly: _sparse({
    0: '....hhhhhhhhhhhh....',
    1: '...hhhhHHhhhhhhhh...',
    2: '..hhhhhhhhhhhhhhhh..',
    3: '..hhhdhhhhhdhhhhhh..',
    4: '..hhhhhhhdhhhhhhhh..',
    5: '..hhh..........hhh..',
    6: '...hh..........hh...',
    7: '...hd..........dh...',
    8: '...d............d...',
  }),
  AvatarHair.bob: _sparse({
    1: '.....hhhhhhhhhh.....',
    2: '....hHHhhhhhhhhh....',
    3: '...hhhhhhhhhhhhhh...',
    4: '...hhhhhhhhhhhhhh...',
    5: '...hh..........hh...',
    6: '...hh..........hh...',
    7: '...hh..........hh...',
    8: '...hh..........hh...',
    9: '...hh..........hh...',
    10: '...hh..........hh...',
    11: '...hh..........hh...',
    12: '..hhh..........hhh..',
    13: '..dhh..........hhd..',
  }),
  AvatarHair.long: _sparse({
    1: '.....hhhhhhhhhh.....',
    2: '....hhhhHHHHhhhh....',
    3: '...hhhhhhhhhhhhhh...',
    4: '...hhhhhhhhhhhhhh...',
    5: '...hh..........hh...',
    6: '...hh..........hh...',
    7: '...hh..........hh...',
    8: '...hh..........hh...',
    9: '...hh..........hh...',
    10: '...hh..........hh...',
    11: '...hh..........hh...',
    12: '...hh..........hh...',
    13: '...hd..........dh...',
    14: '...dd..........dd...',
    15: '....d..........d....',
  }),
  AvatarHair.bun: _sparse({
    0: '........hHHh........',
    1: '.......hhhhhh.......',
    2: '......hhhhhhhh......',
    3: '.....hhhhhhhhhh.....',
    4: '....hh........hh....',
    5: '....h..........h....',
  }),
  AvatarHair.pony: _sparse({
    1: '.....hhhHHhhhhh.....',
    2: '....hhhhhhhhhhhhh...',
    3: '....hh........hhhh..',
    4: '....h..........hhh..',
    5: '....h...........hh..',
    6: '................hh..',
    7: '................hh..',
    8: '.................h..',
    9: '.................d..',
  }),
  AvatarHair.bald: _sparse({}),
};
