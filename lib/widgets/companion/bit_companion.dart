import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'bit_sprite.dart' show BitMood;

/// BIT as the room's living companion — a fully-painted, animated port of the
/// prototype's `bit.js` (the companion engine, distinct from the faceless
/// `bit_boot.dart`). Core + four detached plates + a glowing screen-face that
/// carries the [mood]. Idle = hover-bob + plate-breathe + blink; **tap →** the
/// plates flare to cheer, run one full orbit (950ms) still flared, then clack
/// back to neutral in quick whole-pixel steps (~280ms, a stutter not a glide)
/// while breathing resumes. Zero image assets.
///
/// Reduced motion → a still, lit, legible pose (no bob/spin) — still tappable
/// with its Semantics label. BIT is the single brightest thing in the room
/// (handoff GUARDRAILS #2): the pad's cyan is deliberately held dimmer.
///
/// The metal/screen palettes below are canonical procedural sprite-art (same
/// status as `bit_boot.dart`'s `_metal`), not brand tokens.
class BitCompanion extends StatefulWidget {
  const BitCompanion({
    super.key,
    this.mood = BitMood.neutral,
    this.size = 92,
    this.cheerTick = 0,
    this.flashTick = 0,
    this.spamRestArmed = true,
    this.onRestEasterEgg,
  });

  /// The resting mood. Tap flips to [BitMood.cheer] for the spin, then returns.
  final BitMood mood;
  final double size;

  /// Bump this (any new value) to fire BIT's tap-spin programmatically — the
  /// exact flare→orbit→stepped-stutter the user gets by tapping him, reused by
  /// the COLLECT cheer. A no-op under reduced motion (the collect routes on
  /// instantly there, so a flash would only flicker).
  final int cheerTick;

  /// Bump this to fire a one-shot cheer **flash only** — bit.js `cheer()`
  /// (`_cheer = 1`, no orbit): the screen washes white and decays over 650ms.
  /// The ceremony's touchdown beat (the orbit stays reserved for a press).
  /// A no-op under reduced motion, like [cheerTick].
  final int flashTick;

  /// Arms the spam-tap easter egg: five rapid taps (≤350ms apart) tire BIT out
  /// — he slumps to a smooth REST pose, sighs once, holds ~3s, then perks back.
  /// The caller arms it only where it's appropriate (home/idle), so the gag can
  /// never override a more important state (a waiting haul, an away status).
  final bool spamRestArmed;

  /// Fired when the spam-rest episode begins (`true`) and ends (`false`), so the
  /// host can swap BIT's voice bubble to the "I guess bro..." sigh and back.
  final ValueChanged<bool>? onRestEasterEgg;

  @override
  State<BitCompanion> createState() => _BitCompanionState();
}

class _BitCompanionState extends State<BitCompanion>
    with TickerProviderStateMixin {
  Ticker? _idle;
  final ValueNotifier<double> _time = ValueNotifier<double>(5.0);
  // Tap = two phases. _spin flares the plates and runs one full orbit with them
  // held flared; when it finishes, _retract clacks them back to neutral in
  // whole-pixel steps (a deliberate stutter, not a glide).
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..addStatusListener(_onSpinStatus);
  late final AnimationController _retract = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..addStatusListener(_onRetractStatus);
  // One-shot cheer FLASH (no orbit) — bit.js cheer(): value 0→1 over the 650ms
  // decay window; the painter reads flash intensity as (1 − value).
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _reduce = false;
  late BitMood _mood = widget.mood;

  // Spam-tap easter egg. Poke BIT five times fast (≤350ms apart) and he tires
  // of it: [_restMorph] eases him neutral→rest (0→1) — a smooth slump — he sighs
  // through the room bubble, holds ~3s, then reverses home. [_resting] gates all
  // further taps for the whole episode so poking a tired BIT does nothing.
  late final AnimationController _restMorph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340), // sink into rest (an exhale)
    reverseDuration: const Duration(milliseconds: 300), // perk back up
  )..addStatusListener(_onRestMorphStatus);
  bool _resting = false;
  int _spamTaps = 0;
  int _lastTapMs = 0;
  Timer? _restHoldTimer;

  static const int _spamThreshold = 5; // the 5th rapid tap triggers rest
  static const int _spamGapMs = 350; // presses ≤350ms apart count as spamming
  static const Duration _restHold = Duration(seconds: 3);

  void _onSpinStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _spin.reset();
      // Orbit done with plates still flared — drop the face to its resting mood
      // and stutter the plates home.
      setState(() => _mood = widget.mood);
      _retract.forward(from: 0);
    }
  }

  void _onRetractStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _retract.reset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _idle?.stop();
      _time.value = 5.0; // frozen idle frame
    } else {
      _idle ??= createTicker((d) => _time.value = d.inMicroseconds / 1e6);
      if (!_idle!.isActive) _idle!.start();
    }
  }

  @override
  void didUpdateWidget(BitCompanion old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood && !_spin.isAnimating && !_resting) {
      setState(() => _mood = widget.mood);
    }
    // External cheer trigger (COLLECT) — fire the same orbit. Reduced motion is
    // a deliberate no-op: collect routes instantly, a flash would only flicker.
    // Suppressed mid-rest so a stray cheer can't override the slump.
    if (widget.cheerTick != old.cheerTick && !_reduce && !_resting) {
      _fireCheer();
    }
    // Flash-only trigger (touchdown): the screen wash without the orbit.
    if (widget.flashTick != old.flashTick && !_reduce && !_resting) {
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _restHoldTimer?.cancel();
    _idle?.dispose();
    _spin.dispose();
    _retract.dispose();
    _flash.dispose();
    _restMorph.dispose();
    _time.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_resting) return; // poking a tired BIT does nothing until he recovers
    if (widget.spamRestArmed) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _spamTaps = (now - _lastTapMs <= _spamGapMs) ? _spamTaps + 1 : 1;
      _lastTapMs = now;
      if (_spamTaps >= _spamThreshold) {
        _spamTaps = 0;
        _enterRest();
        return;
      }
    }
    if (_reduce) {
      // No orbit when motion is off — a brief cheer flash only.
      setState(() => _mood = BitMood.cheer);
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted && !_resting) setState(() => _mood = widget.mood);
      });
      return;
    }
    _fireCheer();
  }

  /// The flare→orbit→stepped-stutter, shared by a user tap and the external
  /// [BitCompanion.cheerTick] (COLLECT). Caller guarantees motion is on.
  void _fireCheer() {
    _retract.reset(); // re-tap mid-retract restarts cleanly
    setState(() => _mood = BitMood.cheer);
    _spin.forward(from: 0);
  }

  /// Spam-tap easter egg — enter REST: cancel any cheer (he deflates), slump to
  /// rest (smoothly, or instantly under reduced motion), tell the host to show
  /// the "I guess bro..." sigh, and arm the 3s recovery.
  void _enterRest() {
    _restHoldTimer?.cancel();
    // Stop the orbit but KEEP _mood (cheer) as the morph's "from", so the slump
    // eases cheer→rest directly — no one-frame flash of neutral in between.
    _spin.reset();
    _retract.reset();
    setState(() => _resting = true);
    widget.onRestEasterEgg?.call(true);
    if (_reduce) {
      _restMorph.value = 1.0; // instant slump — still a legible rest pose
    } else {
      _restMorph.forward(from: 0);
    }
    _restHoldTimer = Timer(_restHold, _exitRest);
  }

  /// Recovery after the hold: flip the host bubble back to advice now, then perk
  /// BIT back to neutral (smoothly, or instantly under reduced motion). [_resting]
  /// clears when the reverse morph fully dismisses (see [_onRestMorphStatus]).
  void _exitRest() {
    if (!mounted) return;
    widget.onRestEasterEgg?.call(false);
    // Perk back up: set the morph's "from" to the resting mood so the reverse
    // eases rest→neutral (he recovers to neutral, never back through cheer).
    if (_reduce) {
      setState(() {
        _mood = widget.mood;
        _resting = false;
      });
      _restMorph.value = 0.0;
    } else {
      setState(() => _mood = widget.mood);
      _restMorph.reverse();
    }
  }

  void _onRestMorphStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _resting) {
      setState(() => _resting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'BIT, your companion',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _BitCompanionPainter(
              time: _time,
              spin: _spin,
              retract: _retract,
              flash: _flash,
              restMorph: _restMorph,
              mood: _mood,
              reduceMotion: _reduce,
            ),
          ),
        ),
      ),
    );
  }
}

// ── palette (verbatim from bit.js METAL) ─────────────────────────────────────
const Map<String, Color> _metal = {
  'k': Color(0xFF0B0B14),
  'd': Color(0xFF1E1E2E),
  'q': Color(0xFF0A0A12),
  'm': Color(0xFF34344E),
  'M': Color(0xFF2A2A40),
  'l': Color(0xFF4B4B6E),
  'L': Color(0xFF6E6E92),
  'c': Color(0xFF15B8B0),
  'C': Color(0xFF5EE8DD),
};

// Screen ramps (edge..centre), eye color, mouth, and plate-spread per mood.
// BIT's light is a readout: NEUTRAL = its own turquoise identity; CHEER echoes
// reward-amber; ALERT = dim turquoise (low power); REST = dim recovery-cyan.
// (Colour pass: NEUTRAL was cyan→turquoise, CHEER was green→amber, ALERT was
// amber→dim-turquoise — so BIT collides with no status hue.)
const Map<BitMood, List<Color>> _ramps = {
  BitMood.neutral: [
    Color(0xFF0A5A5E), Color(0xFF0F9EA0), Color(0xFF23D6CC), Color(0xFF73F2E8),
  ],
  BitMood.cheer: [
    Color(0xFF7A5200), Color(0xFFC99400), Color(0xFFFFD21F), Color(0xFFFFEC8C),
  ],
  BitMood.alert: [
    Color(0xFF0B3A40), Color(0xFF0E6E70), Color(0xFF16A39A), Color(0xFF46D0C4),
  ],
  BitMood.rest: [
    Color(0xFF06303E), Color(0xFF0A5570), Color(0xFF117CA8), Color(0xFF2C9AD8),
  ],
};
const Map<BitMood, Color> _glow = {
  BitMood.neutral: Color(0xFF17D6CC),
  BitMood.cheer: Color(0xFFFFD700),
  BitMood.alert: Color(0xFF0E6E70),
  BitMood.rest: Color(0xFF0E4F74),
};
const Map<BitMood, Color> _eyeCol = {
  BitMood.neutral: Color(0xFFFFFFFF),
  BitMood.cheer: Color(0xFFFFFDF0),
  BitMood.alert: Color(0xFFDFF7F2),
  BitMood.rest: Color(0xFFCFEAF7),
};
const Map<BitMood, List<List<int>>> _eyes = {
  BitMood.neutral: [[3, 3], [3, 4], [6, 3], [6, 4]],
  BitMood.cheer: [[2, 2], [3, 2], [2, 3], [3, 3], [6, 2], [7, 2], [6, 3], [7, 3]],
  BitMood.alert: [[2, 4], [3, 4], [6, 4], [7, 4]],
  BitMood.rest: [[2, 5], [3, 5], [6, 5], [7, 5]],
};
const Map<BitMood, List<List<int>>> _blinkEyes = {
  BitMood.neutral: [[3, 4], [6, 4]],
  BitMood.cheer: [[2, 3], [3, 3], [6, 3], [7, 3]],
  BitMood.alert: [[2, 4], [3, 4], [6, 4], [7, 4]],
  BitMood.rest: [[2, 5], [3, 5], [6, 5], [7, 5]],
};
const Map<BitMood, List<List<int>>> _mouth = {
  BitMood.neutral: [[4, 6], [5, 6]],
  BitMood.cheer: [[4, 6], [5, 6], [4, 7], [5, 7]],
  BitMood.alert: [[4, 6], [5, 6]],
  BitMood.rest: [],
};
const Map<BitMood, double> _moodSpread = {
  BitMood.neutral: 0,
  BitMood.cheer: 4,
  BitMood.alert: -1,
  BitMood.rest: -1,
};

// ── grid builders (ported verbatim from bit.js / bit_boot.dart) ──────────────
List<List<String>> _bevelBlock(int w, int h, int cut) {
  bool inside(int x, int y) =>
      x >= 0 &&
      x < w &&
      y >= 0 &&
      y < h &&
      (x + y) >= cut &&
      ((w - 1 - x) + y) >= cut &&
      (x + (h - 1 - y)) >= cut &&
      ((w - 1 - x) + (h - 1 - y)) >= cut;
  final g = List.generate(
    h,
    (y) => List.generate(w, (x) => inside(x, y) ? 'm' : '.'),
  );
  bool isIn(int x, int y) =>
      x >= 0 && x < w && y >= 0 && y < h && g[y][x] != '.';
  final s = [for (final r in g) [...r]];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (g[y][x] == '.') continue;
      final up = isIn(x, y - 1),
          dn = isIn(x, y + 1),
          lf = isIn(x - 1, y),
          rt = isIn(x + 1, y);
      if (!up) {
        s[y][x] = 'L';
      } else if (!dn) {
        s[y][x] = 'd';
      } else if (!lf) {
        s[y][x] = 'l';
      } else if (!rt) {
        s[y][x] = 'M';
      }
    }
  }
  for (var y = 1; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (s[y][x] == 'm' && s[y - 1][x] == 'L') s[y][x] = 'l';
    }
  }
  return s;
}

List<List<String>> _outlinePass(List<List<String>> g) {
  final h = g.length, w = g[0].length;
  final out = [for (final r in g) [...r]];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (g[y][x] != '.') continue;
      var adj = false;
      for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        final nx = x + d[0], ny = y + d[1];
        if (nx >= 0 &&
            nx < w &&
            ny >= 0 &&
            ny < h &&
            g[ny][nx] != '.' &&
            g[ny][nx] != 'k') {
          adj = true;
          break;
        }
      }
      if (adj) out[y][x] = 'k';
    }
  }
  return out;
}

void _addDot(List<List<String>> g, int x, int y) {
  if (y >= 0 && y < g.length && x >= 0 && x < g[0].length && g[y][x] != '.') {
    g[y][x] = 'C';
    if (x + 1 < g[0].length && g[y][x + 1] != '.') g[y][x + 1] = 'c';
  }
}

List<List<String>> _buildCore() {
  final g = _bevelBlock(16, 16, 3);
  for (var y = 2; y <= 13; y++) {
    for (var x = 2; x <= 13; x++) {
      final ring = (x == 2 || x == 13 || y == 2 || y == 13);
      if (x >= 3 && x <= 12 && y >= 3 && y <= 12) {
        g[y][x] = 'q';
      } else if (ring) {
        g[y][x] = (x == 2 || y == 2) ? 'd' : 'k';
      }
    }
  }
  for (var y = 5; y <= 10; y++) {
    g[y][1] = 'd';
  }
  g[5][1] = 'k';
  g[10][1] = 'k';
  g[7][2] = 'l';
  return _outlinePass(g);
}

List<List<String>> _plateTop() {
  final g = _bevelBlock(18, 5, 3);
  _addDot(g, 3, 3);
  _addDot(g, 13, 3);
  return _outlinePass(g);
}

List<List<String>> _plateBottom() {
  final g = _bevelBlock(18, 5, 3);
  _addDot(g, 3, 1);
  _addDot(g, 13, 1);
  return _outlinePass(g);
}

List<List<String>> _plateLeft() {
  final g = _bevelBlock(5, 14, 2);
  _addDot(g, 2, 2);
  _addDot(g, 2, 11);
  return _outlinePass(g);
}

List<List<String>> _plateRight() {
  final g = _bevelBlock(5, 14, 2);
  _addDot(g, 1, 2);
  _addDot(g, 1, 11);
  return _outlinePass(g);
}

class _Plate {
  _Plate(this.grid, int x, int y, this.dirX, this.dirY)
    : hw = grid[0].length / 2,
      hh = grid.length / 2 {
    nvx = (x + hw) - 20; // home offset from core centre (20,20)
    nvy = (y + hh) - 20;
  }
  final List<List<String>> grid;
  final double hw, hh;
  final double dirX, dirY;
  late final double nvx, nvy;
}

final List<List<String>> _coreGrid = _buildCore();
final List<_Plate> _platesC = [
  _Plate(_plateTop(), 11, 5, 0, -1),
  _Plate(_plateBottom(), 11, 30, 0, 1),
  _Plate(_plateLeft(), 5, 13, -1, 0),
  _Plate(_plateRight(), 30, 13, 1, 0),
];

double _easeInOutCubic(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

double _noise(double t) {
  final s = math.sin(t * 12.9898) * 43758.5453;
  return s - s.floorToDouble();
}

/// Deterministic 0..1 hash noise, exported so the hologram can decide
/// glitch/jitter frames as a pure function of time (never `Random` in paint).
double bitNoise(double t) => _noise(t);

/// Paint a metal grid (core / a plate) at native scale [s], origin in native
/// cells. Top-level so both the companion painter and the hologram render the
/// **identical** BIT sprite. `sil` paints a flat silhouette.
void drawBitGrid(
  Canvas canvas,
  List<List<String>> grid,
  double s,
  double oxN,
  double oyN, {
  bool sil = false,
}) {
  final paint = Paint()..isAntiAlias = false;
  for (var y = 0; y < grid.length; y++) {
    final row = grid[y];
    for (var x = 0; x < row.length; x++) {
      final col = sil ? const Color(0xFF08080E) : _metal[row[x]];
      if (col == null) continue;
      paint.color = col;
      canvas.drawRect(Rect.fromLTWH((oxN + x) * s, (oyN + y) * s, s, s), paint);
    }
  }
}

/// Paint BIT's 10×10 glowing screen-face at native scale [s].
///
/// [alpha] dims the whole screen (ramp + scanlines + face) — bit.js's
/// `drawScreen` `ctx.globalAlpha`, used by the ceremony's anticipation inhale.
/// The default 1.0 skips the layer entirely (the shipped paths are untouched).
void drawBitScreen(
  Canvas canvas,
  double s,
  double oxN,
  double oyN,
  List<Color> ramp,
  BitMood mood,
  bool blink,
  double cheer, {
  double alpha = 1.0,
}) {
  final dimmed = alpha < 1.0;
  if (dimmed) {
    canvas.saveLayer(
      Rect.fromLTWH(oxN * s, oyN * s, 10 * s, 10 * s),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
    );
  }
  final paint = Paint()..isAntiAlias = false;
  void px(double x, double y, double w, double h, Color c) {
    paint.color = c;
    canvas.drawRect(
      Rect.fromLTWH((oxN + x) * s, (oyN + y) * s, w * s, h * s),
      paint,
    );
  }

  for (var y = 0; y < 10; y++) {
    for (var x = 0; x < 10; x++) {
      final dx = x - 4.5, dy = y - 4.5;
      final d = math.sqrt(dx * dx + dy * dy);
      final idx = d < 1.5 ? 3 : (d < 2.9 ? 2 : (d < 4.2 ? 1 : 0));
      px(x.toDouble(), y.toDouble(), 1, 1, ramp[idx]);
    }
  }
  for (var y = 0; y < 10; y += 2) {
    px(0, y.toDouble(), 10, 1, const Color.fromRGBO(2, 8, 12, 0.18));
  }
  final eyeCol = _eyeCol[mood]!;
  for (final e in (blink ? _blinkEyes[mood]! : _eyes[mood]!)) {
    px(e[0].toDouble(), e[1].toDouble(), 1, 1, eyeCol);
  }
  for (final m in _mouth[mood]!) {
    px(m[0].toDouble(), m[1].toDouble(), 1, 1, eyeCol);
  }
  if (cheer > 0.01) {
    px(0, 0, 10, 10, Color.fromRGBO(242, 255, 255, math.min(0.55, cheer * 0.65)));
  }
  if (dimmed) canvas.restore();
}

/// JS `Math.round` (ties toward +∞) — bit.js rounds `sink`/`bob`/`breathe`
/// this way, and Dart's `.round()` (ties away from zero) diverges on negative
/// half-values (the anticipation pop makes `sink` negative).
double _jsRound(double x) => (x + 0.5).floorToDouble();

/// Paint one **ceremony** frame of BIT — the Session-Complete overlay's 200px
/// instance. A faithful transcription of bit.js `renderInst` for the ceremony's
/// instance state (`mood:'REST'` at mount, `setMood('CHEER')` at the surge),
/// driven entirely by the caller's clock so every frame is deterministic:
///
/// - [tms] — ceremony clock in ms (drives bob/breathe/glow shimmer).
/// - [surgedForMs] — ms since the surge (`setMood('CHEER')` at t=500); negative
///   before it. Derives the 200ms mood-ramp lerp, the face switch at ramp 0.5,
///   the cheer flash (1 → 0 over 650ms), the plate-spread follow (REST −1 →
///   CHEER 4, the continuous form of bit.js's `s += (T−s)·dt/120` Euler step),
///   and the REST droop.
/// - [antic] — `setAnticipation` value; may be **negative** (the overshoot pop:
///   BIT rises + plates spread; the glow/screen dims gate on `max(0, antic)`).
/// - [idleAmp] — `setIdleAmp` 0..1 (0 while dormant, ramped in after the surge).
/// - [spinT] — `spin(1500)` progress 0..1; eased `easeInOutCubic → 2π` here,
///   exactly like bit.js (plates land home at 1).
/// - [blink] — forced blink (the double "sign of life" @380/@455).
///
/// Ground glow (bit.js's blurred gradient div) is painted as a radial-gradient
/// ellipse at the same box (64%×16%, bottom 4%). Scanlines always on ('face'
/// screen). The caller owns the flight transform (translate/rotate/scale).
void paintCeremonyBit(
  Canvas canvas,
  Size size, {
  required double tms,
  required double surgedForMs,
  required double antic,
  required double idleAmp,
  required double spinT,
  required bool blink,
}) {
  final s = size.width / 44.0;
  final surged = surgedForMs >= 0;

  // Instance state (bit.js updateInst), as pure functions of the clock.
  final mt = surged ? (surgedForMs / 200).clamp(0.0, 1.0) : 0.0;
  final cheer = surged ? (1 - surgedForMs / 650).clamp(0.0, 1.0) : 0.0;
  final spread = surged ? 4 - 5 * math.exp(-surgedForMs / 120) : -1.0;
  final droop = surged ? 0.0 : 2.0; // _target === 'REST' ? 2 : 0
  final faceMood = mt >= 0.5 ? BitMood.cheer : BitMood.rest; // _mt >= 0.5

  final restR = _ramps[BitMood.rest]!, cheerR = _ramps[BitMood.cheer]!;
  final ramp = [
    for (var i = 0; i < 4; i++) Color.lerp(restR[i], cheerR[i], mt)!,
  ];
  final glowCol = Color.lerp(_glow[BitMood.rest], _glow[BitMood.cheer], mt)!;

  // renderInst geometry.
  final sink = _jsRound(antic * 3);
  final bob = _jsRound(math.sin(tms / 780) * idleAmp);
  final breathe = _jsRound(math.sin(tms / 610 + 1.3) * idleAmp);
  final anticDim = math.max(0.0, antic);

  // Ground glow — bit.js's div: width 64%, height 16%, bottom 4% of the host,
  // radial gradient glowCol → transparent at 70%, slight blur.
  final glowBase = surged ? 0.5 : 0.32; // REST base 0.32
  final glowOp = ((glowBase + 0.16 * math.sin(tms / 780)) * (1 - anticDim * 0.75))
      .clamp(0.0, 1.0);
  if (glowOp > 0.01) {
    final host = size.width;
    final gw = host * 0.64, gh = host * 0.16;
    final gc = Offset(host / 2, host * 0.96 - gh / 2);
    canvas.save();
    canvas.translate(gc.dx, gc.dy);
    canvas.scale(1, gh / gw);
    canvas.drawCircle(
      Offset.zero,
      gw / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [glowCol.withValues(alpha: glowOp), const Color(0x00000000)],
          stops: const [0.0, 0.7],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: gw / 2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    canvas.restore();
  }

  final spreadF = spread + breathe + cheer * 3 - antic * 3;
  final shake = cheer > 0.02 ? (_noise(tms / 20) - 0.5) * 2.4 * cheer : 0.0;
  final theta = spinT > 0 ? _easeInOutCubic(spinT.clamp(0.0, 1.0)) * 2 * math.pi : 0.0;
  final cos = math.cos(theta), sin = math.sin(theta);
  const gx = 2.0, gy = 2.0;
  const ocx = gx + 20.0; // GX + CORE_CX
  final ocy = gy + 20.0 + bob + sink; // GY + CORE_CY + bob + sink

  for (final p in _platesC) {
    final ex = p.nvx + p.dirX * spreadF;
    final ey = p.nvy + p.dirY * spreadF;
    final rvx = ex * cos - ey * sin;
    final rvy = ex * sin + ey * cos;
    // bit.js drawGrid rounds its origin (JS Math.round) — chunky cell motion.
    drawBitGrid(
      canvas,
      p.grid,
      s,
      _jsRound(ocx + rvx - p.hw + shake),
      _jsRound(ocy + rvy - p.hh + droop),
    );
  }
  drawBitGrid(canvas, _coreGrid, s, gx + 12, gy + 12 + bob + sink);
  // Screen: sa = appear² · (1 − max(0,antic)·0.55); appear is 1 here.
  drawBitScreen(
    canvas,
    s,
    gx + 15,
    gy + 15 + bob + sink,
    ramp,
    faceMood,
    blink,
    cheer,
    alpha: 1 - anticDim * 0.55,
  );
}

/// Paint BIT's **idle** sprite (no glow, no spin) at the given [opacity] — the
/// shared entry point the hologram post-processes. [tms] is time in ms (drives
/// bob/breathe/blink); pass `reduceMotion: true` to freeze a still pose. Plates
/// sit at the mood's resting spread; the core + screen carry [mood].
void paintBitSprite(
  Canvas canvas,
  double s, {
  required double tms,
  BitMood mood = BitMood.neutral,
  double opacity = 1.0,
  bool reduceMotion = false,
}) {
  final bob = reduceMotion ? 0.0 : 1.5 * math.sin(tms / 390);
  final breathe = reduceMotion ? 0 : math.sin(tms / 610 + 1.3).round();
  final blink = !reduceMotion && ((tms / 1000) % 3.4) < 0.11;
  final spreadF = (_moodSpread[mood] ?? 0).toDouble() + breathe;
  final droop = mood == BitMood.rest ? 2.0 : 0.0;
  const gx = 2, gy = 2, coreCx = 20.0, coreCy = 20.0;
  final ocx = gx + coreCx, ocy = gy + coreCy + bob;

  canvas.saveLayer(
    Rect.fromLTWH(0, 0, 44 * s, 44 * s),
    Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
  );
  for (final p in _platesC) {
    final ex = p.nvx + p.dirX * spreadF;
    final ey = p.nvy + p.dirY * spreadF;
    drawBitGrid(canvas, p.grid, s, ocx + ex - p.hw, ocy + ey - p.hh + droop);
  }
  drawBitGrid(canvas, _coreGrid, s, (gx + 12).toDouble(), gy + 12 + bob);
  drawBitScreen(
    canvas,
    s,
    (gx + 15).toDouble(),
    gy + 15 + bob,
    _ramps[mood]!,
    mood,
    blink,
    0,
  );
  canvas.restore();
}

class _BitCompanionPainter extends CustomPainter {
  _BitCompanionPainter({
    required this.time,
    required this.spin,
    required this.retract,
    required this.flash,
    required this.restMorph,
    required this.mood,
    required this.reduceMotion,
  }) : super(repaint: Listenable.merge([time, spin, retract, flash, restMorph]));

  final ValueListenable<double> time;

  /// 0→1 over the tap orbit; plates stay flared the whole way.
  final Animation<double> spin;

  /// 0→1 right after the orbit; recedes the flared plates home in pixel steps.
  final Animation<double> retract;

  /// 0→1 over the flash-only cheer decay (bit.js `cheer()`); intensity is
  /// `1 − value` while running, 0 when dismissed — the default state changes
  /// nothing in the shipped paint.
  final Animation<double> flash;

  /// 0→1 neutral→rest for the spam-tap easter egg — a smooth slump. 0 leaves the
  /// base [mood] untouched (so the cheer orbit renders exactly as before).
  final Animation<double> restMorph;
  final BitMood mood;
  final bool reduceMotion;

  static const int _gx = 2, _gy = 2;
  static const double _coreCx = 20, _coreCy = 20;

  /// Plate flare (native px) held through the orbit, then stepped back to 0.
  static const double _flareSpread = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44.0;
    final t = reduceMotion ? 5.0 : time.value;
    final tms = t * 1000;
    final spinT = reduceMotion ? 0.0 : spin.value;
    final retractT = reduceMotion ? 0.0 : retract.value;
    final spinning = spinT > 0;
    // Status, not value>0: the retract's first frame is value 0 (still fully
    // flared), and it must count as retracting or the plates flick to neutral
    // for one frame before stepping home.
    final retracting =
        !reduceMotion && retract.status == AnimationStatus.forward;

    final bob = reduceMotion ? 0.0 : 1.5 * math.sin(tms / 390);
    final breathe = reduceMotion ? 0 : math.sin(tms / 610 + 1.3).round();

    final spinCheer = spinning
        ? (1 - spinT * 950 / 650).clamp(0.0, 1.0)
        : 0.0;
    // Flash-only cheer (touchdown): full wash at fire, decaying over 650ms.
    // Dismissed (the shipped default) contributes 0.
    final flashCheer =
        (!reduceMotion && flash.status == AnimationStatus.forward)
        ? (1 - flash.value).clamp(0.0, 1.0)
        : 0.0;
    final cheer = math.max(spinCheer, flashCheer);
    final blink = !reduceMotion && (t % 3.4) < 0.11;
    final theta = _easeInOutCubic(spinT) * 2 * math.pi;
    final cos = math.cos(theta), sin = math.sin(theta);

    // Spam-tap easter egg: a smooth slump toward REST (eased). We lerp from the
    // CURRENT [mood] (cheer at entry / neutral on the way back) → rest, so the
    // transition never flashes through a stray frame of neutral; the discrete
    // eyes/mouth switch at the midpoint. Keyed off the controller STATUS (not
    // value>0) so the first forward frame — value 0 — still renders the from-mood,
    // not the resting base. Dismissed ⇒ no episode ⇒ the base mood verbatim (the
    // cheer orbit is unaffected).
    final morph = Curves.easeInOut.transform(restMorph.value.clamp(0.0, 1.0));
    final inRest = restMorph.status != AnimationStatus.dismissed;
    final List<Color> ramp;
    final Color glowCol;
    final BitMood faceMood;
    final double restSpread;
    final double droop;
    if (inRest) {
      final fromR = _ramps[mood]!, restR = _ramps[BitMood.rest]!;
      ramp = [
        for (var i = 0; i < 4; i++) Color.lerp(fromR[i], restR[i], morph)!,
      ];
      glowCol = Color.lerp(_glow[mood], _glow[BitMood.rest], morph)!;
      faceMood = morph >= 0.5 ? BitMood.rest : mood;
      final fromSpread = (_moodSpread[mood] ?? 0).toDouble();
      final toSpread = (_moodSpread[BitMood.rest] ?? -1).toDouble();
      restSpread = fromSpread + (toSpread - fromSpread) * morph;
      droop = 2.0 * morph; // BIT slumps
    } else {
      ramp = _ramps[mood]!;
      glowCol = _glow[mood]!;
      faceMood = mood;
      restSpread = (_moodSpread[mood] ?? 0).toDouble();
      droop = mood == BitMood.rest ? 2.0 : 0.0;
    }

    // Plate flare: snap out and hold through the orbit, then recede home in
    // WHOLE-PIXEL steps (ceil) so it clacks back — a pixel stutter, not a glide.
    final double flare;
    if (spinning) {
      flare = _flareSpread;
    } else if (retracting) {
      flare = (_flareSpread * (1 - retractT)).ceilToDouble();
    } else {
      flare = restSpread;
    }
    final spreadF = flare + breathe;
    final shake = (cheer > 0.02 && !reduceMotion)
        ? (_noise(t * 50) - 0.5) * 2.4 * cheer
        : 0.0;

    final ocx = _gx + _coreCx; // 22
    final ocy = _gy + _coreCy + bob; // 22 + bob

    // Rim glow — BIT's own cyan halo (the drop-shadow in the web build).
    canvas.drawCircle(
      Offset(ocx * s, ocy * s),
      13 * s,
      Paint()
        ..color = glowCol.withValues(alpha: 0.16 + 0.40 * cheer)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 * s),
    );

    // Plates orbit the core (positional only — bit.js does not spin each plate).
    for (final p in _platesC) {
      final ex = p.nvx + p.dirX * spreadF;
      final ey = p.nvy + p.dirY * spreadF;
      final rvx = ex * cos - ey * sin;
      final rvy = ex * sin + ey * cos;
      drawBitGrid(
        canvas,
        p.grid,
        s,
        ocx + rvx - p.hw + shake,
        ocy + rvy - p.hh + droop,
      );
    }
    drawBitGrid(canvas, _coreGrid, s, (_gx + 12).toDouble(), _gy + 12 + bob);
    drawBitScreen(
      canvas,
      s,
      (_gx + 15).toDouble(),
      _gy + 15 + bob,
      ramp,
      faceMood,
      blink,
      cheer,
    );
  }

  @override
  bool shouldRepaint(covariant _BitCompanionPainter old) =>
      old.reduceMotion != reduceMotion || old.mood != mood;
}
