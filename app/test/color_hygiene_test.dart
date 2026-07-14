import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Anti-rot guard for the colour-token system.
///
/// Tokenised colours must come from a token in `lib/theme/tokens.dart`
/// (`kNeon`, `kAmber`, …, and the neutrals `kBg`/`kCard`/`kBorder`/`kText`),
/// never a raw `Color(0x..)` literal. This test fails if any token hex reappears
/// as a `Color()` constructor outside the allow-list, so a future edit can't
/// silently re-hardcode `Color(0xFF00FF9C)` instead of `kNeon`.
///
/// Scope: every hex that has a token — brand accents AND neutrals. The
/// white/black absolutes (FFFFFF/000000) are intentionally excluded from the hex
/// set: their common spelling `Colors.white`/`.black` is caught by the Material
/// check below, and raw `Color(0xFFFFFFFF/000000)` is heavily used by sprite-art
/// / effect painters. New UI should still use `kWhite`/`kBlack`.
///
/// Exceptions: `tokens.dart` (the definitions) and the procedural **sprite-art**
/// painters, which own bespoke raw-hex palettes (the documented exception). When
/// you add a new sprite painter that needs a brand hue in its palette, add it to
/// [allow] — that keeps "is this art or UI?" a conscious decision.
void main() {
  // RGB values that have a token. A raw Color() of any of these outside the
  // allow-list is a violation. Keep in sync with tokens.dart. (FFFFFF/000000 are
  // intentionally absent — see the file header.)
  const tokenHexes = <String>{
    // Brand accents
    '00FF9C', // kNeon
    '009955', // kNeonDark
    'FFD700', // kAmber
    'FFA500', // kAmberDark
    '00BFFF', // kCyan
    'FF2D55', // kDanger
    'FF4DCD', // kGemMagenta
    // Neutrals — surfaces, borders, text
    '11111F', // kBg
    '15152C', // kBgGradientTop
    '0E0E1B', // kBgGradientBottom
    '1C1C34', // kCard
    '232342', // kSurface2
    '2A2A4E', // kSurface3
    '36365E', // kBorder
    '45437A', // kBorderVariant
    '2A2A3E', // kBorderDark
    'E8E8FF', // kText
    '9494B8', // kMutedText
    '555577', // kDim
    '6B6B8A', // kSlate
  };

  // Files permitted to hold these literals: the token definitions + procedural
  // sprite-art palettes (raw hex is correct there — they're art, not UI).
  const allow = <String>{
    'lib/theme/tokens.dart',
    'lib/widgets/companion/bit_companion.dart',
    'lib/widgets/companion/bit_core_engine.dart',
    'lib/widgets/adventure/bit_route_walker.dart',
    'lib/widgets/streak_orbit_icon.dart',
    'lib/widgets/room/bit_pad_light.dart',
    'lib/widgets/room/coffer.dart',
  };

  // Color(0x + optional 2-digit alpha + a token RGB, anchored so a *different*
  // colour that merely contains the substring isn't flagged.
  final tokenLiteral = RegExp(
    r'Color\(0x[0-9A-Fa-f]{0,2}(' + tokenHexes.join('|') + r')\b',
    caseSensitive: false,
  );

  test('no raw token-color literals outside tokens + sprite-art', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll(r'\', '/');
      if (allow.any(rel.endsWith)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (tokenLiteral.hasMatch(lines[i])) {
          offenders.add('$rel:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Raw token-colour hex found — use the token from tokens.dart '
          '(kNeon/kAmber/kCyan/kDanger, or a neutral kBg/kCard/kBorder/kText). '
          'If this is a new sprite-art painter, add it to the allow-list '
          'instead:\n${offenders.join('\n')}',
    );
  });

  // Material palette colours bypass the token system. Only `transparent` is
  // allowed (a true no-paint sentinel with no brand meaning); everything else
  // has a token (kWhite / kBlack / kText / …). Dart's RegExp supports the
  // negative lookahead that ripgrep does not, so excluding transparent is exact.
  final materialColor = RegExp(r'\bColors\.(?!transparent\b)[A-Za-z]');

  test('no Material Colors.* except transparent', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll(r'\', '/');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (materialColor.hasMatch(lines[i])) {
          offenders.add('$rel:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Material Colors.* found — use a token (kWhite / kBlack / kText / …) '
          'or Colors.transparent only:\n${offenders.join('\n')}',
    );
  });
}
