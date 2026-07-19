import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ENFORCEMENT — every tappable in the app must route through a haptic-aware tap
/// wrapper (`ArcadeTap` / `HoldDepress` / `PixelButton` / `ArcadeChip`), so haptic
/// feedback is wired **automatically** and can't be forgotten. (The failure this
/// guards: the Crest Forge once shipped with zero haptics because its taps used a
/// raw `GestureDetector` instead of a wrapper.) A raw `GestureDetector(onTap:/
/// onLongPress:)` or `InkWell(...)` bypasses the haptic layer — this test fails on
/// any such tap outside the three escape hatches:
///
///  1. the wrapper implementations themselves ([_wrapperAllowlist]);
///  2. an explicit inline `// haptic-ok: <reason>` marker on the widget's line or
///     the line directly above (a genuine raw gesture — drag/pan/decorative/custom
///     hit area, where a tap haptic would be wrong);
///  3. the [_baseline] of pre-existing files, tolerated until migrated.
///     **SHRINK-ONLY — never add a file here.** Route the new tap through a
///     wrapper instead; that is the whole point.
///
/// The scanner is comment/string-aware (a `GestureDetector(onTap:` inside a string
/// or comment is ignored) and depth-aware (a nested child's `onTap` does not flag
/// its parent). It is a guard, not a compiler — the marker is the precise opt-out.
const Set<String> _wrapperAllowlist = {
  'lib/widgets/motion/phosphor_tap.dart',
  'lib/widgets/motion/hold_depress.dart',
  'lib/widgets/pixel_button.dart',
};

/// Pre-existing raw-tap files, tolerated until migrated. SHRINK-ONLY: do not add.
const Set<String> _baseline = {
  'lib/pages/adventure_page.dart',
  'lib/pages/body_metrics_chart_page.dart',
  'lib/pages/class_reveal_page.dart',
  'lib/pages/exercise_detail.dart',
  'lib/pages/expedition_report_page.dart',
  'lib/pages/home.dart',
  'lib/pages/onboarding/calibration_loading_page.dart',
  'lib/pages/onboarding/calibration_quiz_page.dart',
  'lib/pages/onboarding/class_reveal_screen.dart',
  'lib/pages/onboarding/cold_open_page.dart',
  'lib/pages/onboarding/program_selection_page.dart',
  'lib/pages/onboarding/solution_page.dart',
  'lib/pages/onboarding/start_gate_screen.dart',
  'lib/pages/profile_page.dart',
  'lib/pages/program_detail_page.dart',
  'lib/pages/Workout session/active_workout.dart',
  'lib/pages/Workout session/exercise_session.dart',
  'lib/pages/Workout session/program_completion_reveal.dart',
  'lib/pages/Workout session/workout_summary.dart',
  'lib/widgets/adventure/adventure_card.dart',
  'lib/widgets/companion/bit_companion.dart',
  'lib/widgets/exercise_demo_cabinet.dart',
  'lib/widgets/exercise_demo_player.dart',
  'lib/widgets/muscle_body_map.dart',
  'lib/widgets/pinned_lift_card.dart',
  'lib/widgets/plate_calculator_sheet.dart',
  'lib/widgets/program_day_card.dart',
  'lib/widgets/rest_timer_bar.dart',
  'lib/widgets/room/expedition_dispatch_sheet.dart',
  'lib/widgets/room/quest_board.dart',
  'lib/widgets/room/room_scene.dart',
  'lib/widgets/strength_roster_row.dart',
};

void main() {
  test('no raw tappable bypasses the haptic wrappers (outside the baseline)', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll('\\', '/');
      if (_wrapperAllowlist.contains(rel) || _baseline.contains(rel)) continue;
      final source = entity.readAsStringSync();
      final code = _blankCommentsAndStrings(source);
      final lines = source.split('\n');
      for (final offset in _rawTappableOffsets(code)) {
        final lineIdx = '\n'.allMatches(source.substring(0, offset)).length;
        if (_markedOk(lines, lineIdx)) continue;
        violations.add('$rel:${lineIdx + 1}');
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'These raw GestureDetector(onTap:)/InkWell taps bypass the haptic tap '
          'wrappers, so their haptics are silently missing. Route each through '
          'ArcadeTap / HoldDepress / PixelButton / ArcadeChip (haptics auto-wire), '
          'or mark `// haptic-ok: <reason>` for a genuine raw gesture:\n  '
          '${violations.join('\n  ')}',
    );
  });

  test('no bare FilledButton/TextButton bypasses the sound-kit wrappers', () {
    // SFX v2: the raw Material buttons were the silent-bypass class that made
    // the soundscape feel piecemeal — ArcadeFilled / ArcadeTextButton wire
    // commit-time haptic + kit sound. Escapes: `// button-ok: <reason>` on the
    // line or the line above (a button whose handler owns its beat, e.g. the
    // SAVE-set button), the wrapper file itself, and [_buttonBaseline]
    // (SHRINK-ONLY — never add a file).
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll('\\', '/');
      if (rel == 'lib/widgets/arcade_filled.dart' ||
          _buttonBaseline.contains(rel)) {
        continue;
      }
      final source = entity.readAsStringSync();
      final code = _blankCommentsAndStrings(source);
      final lines = source.split('\n');
      for (final m in RegExp(
        r'(?<![A-Za-z0-9_$.])(?:FilledButton|TextButton)(?:\.icon)?\s*\(',
      ).allMatches(code)) {
        final lineIdx = '\n'.allMatches(source.substring(0, m.start)).length;
        final line = lines[lineIdx];
        // Skip non-constructor uses (styleFrom, themes, type annotations).
        if (line.contains('.styleFrom') ||
            line.contains('ThemeData') ||
            line.contains('ButtonTheme')) {
          continue;
        }
        final ok =
            line.contains('button-ok') ||
            (lineIdx > 0 && lines[lineIdx - 1].contains('button-ok'));
        if (!ok) violations.add('$rel:${lineIdx + 1}');
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'These raw FilledButton/TextButton presses have no haptic and no kit '
          'sound. Use ArcadeFilled / ArcadeTextButton (feedback auto-wires), '
          'or mark `// button-ok: <reason>` when the handler owns its beat:\n  '
          '${violations.join('\n  ')}',
    );
  });
}

/// Pre-existing raw-button files tolerated until migrated. SHRINK-ONLY.
const Set<String> _buttonBaseline = {};

bool _markedOk(List<String> lines, int lineIdx) =>
    lines[lineIdx].contains('haptic-ok') ||
    (lineIdx > 0 && lines[lineIdx - 1].contains('haptic-ok'));

bool _isIdent(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// Blank out comment + string-literal characters (preserving length + newlines)
/// so the construct scan can never match inside one. Handles //, /* */, ', ",
/// and triple-quoted strings; interpolation is left as-is (rare + harmless here).
String _blankCommentsAndStrings(String s) {
  final out = StringBuffer();
  var i = 0;
  final n = s.length;
  String at(int k) => k < n ? s[k] : '';
  while (i < n) {
    final c = s[i];
    if (c == '/' && at(i + 1) == '/') {
      while (i < n && s[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (c == '/' && at(i + 1) == '*') {
      out.write('  ');
      i += 2;
      while (i < n && !(s[i] == '*' && at(i + 1) == '/')) {
        out.write(s[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (i < n) {
        out.write('  ');
        i += 2;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      final q = c;
      final triple = at(i + 1) == q && at(i + 2) == q;
      final close = triple ? '$q$q$q' : q;
      out.write(' ' * close.length);
      i += close.length;
      while (i < n) {
        if (s[i] == r'\') {
          out.write('  ');
          i += 2;
          continue;
        }
        if (s.startsWith(close, i)) {
          out.write(' ' * close.length);
          i += close.length;
          break;
        }
        out.write(s[i] == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Offsets of `GestureDetector`/`InkWell` constructions that carry an `onTap:` or
/// `onLongPress:` at their own arg level (depth 1), in already-blanked [code].
Iterable<int> _rawTappableOffsets(String code) sync* {
  for (final name in const ['GestureDetector', 'InkWell']) {
    var from = 0;
    while (true) {
      final idx = code.indexOf(name, from);
      if (idx < 0) break;
      from = idx + name.length;
      if (idx > 0 && _isIdent(code[idx - 1])) continue; // identifier boundary
      var p = from;
      while (p < code.length && (code[p] == ' ' || code[p] == '\n' || code[p] == '\t')) {
        p++;
      }
      if (p >= code.length || code[p] != '(') continue;
      var depth = 0;
      var tappable = false;
      for (var q = p; q < code.length; q++) {
        final ch = code[q];
        if (ch == '(') {
          depth++;
          continue;
        }
        if (ch == ')') {
          depth--;
          if (depth == 0) break;
          continue;
        }
        if (depth == 1 && (q == 0 || !_isIdent(code[q - 1]))) {
          for (final kw in const ['onTap', 'onLongPress']) {
            if (!code.startsWith(kw, q)) continue;
            var r = q + kw.length;
            while (r < code.length && code[r] == ' ') {
              r++;
            }
            if (r < code.length && code[r] == ':') tappable = true;
          }
        }
      }
      if (tappable) yield idx;
    }
  }
}
