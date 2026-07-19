import 'package:flutter/material.dart';

import '../services/sfx_service.dart';
import '../services/ui_sound.dart';
import '../theme/tokens.dart';
import 'companion/bit_core_engine.dart' show bitGlow;

/// The app's ONE transient notice — a center-screen CRT plate that powers on
/// from a scanline, holds, and collapses back to the line (mockup Option A).
/// Replaces every Material SnackBar (three styles had grown for one concept).
///
/// Contract:
/// - **Center screen**, game-HUD convention; never blocks interaction — the
///   plate is [IgnorePointer], and the full-screen tap observer is a
///   [HitTestBehavior.translucent] Listener, which receives every pointer
///   event while returning FALSE from hit-testing, so the overlay entries and
///   routes beneath it still get the same tap.
/// - **Tap anywhere dismisses immediately** — and the tap still performs its
///   normal action (dismissal is observation, never consumption).
/// - **Non-stacking:** a new notice replaces the current one instantly
///   (the old `hideCurrentSnackBar()` semantics, load-bearing for rapid
///   set-logging notices).
/// - **Timer-free lifecycle:** one AnimationController spans power-on → hold
///   → power-off. No dart:async Timer — a pending timer fails widget-test
///   teardown, and the whole suite asserts notices after a bare `pump()`.
/// - **Reduced motion** (`disableAnimations || accessibleNavigation`): the
///   plate snaps fully formed, holds, snaps away.
enum ArcadeNoticeDuration { standard, short }

OverlayEntry? _current;

@visibleForTesting
void resetArcadeNoticeForTest() {
  if (_current?.mounted ?? false) _current!.remove();
  _current = null;
}

void showArcadeNotice(
  BuildContext context,
  String message, {
  ArcadeNoticeDuration duration = ArcadeNoticeDuration.standard,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  if (_current?.mounted ?? false) _current!.remove();
  // The plate's CRT power-on, heard — a quiet notification blip (SFX v2).
  SfxService.instance.playUi(UiSound.notice);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ArcadeNoticePlate(
      message: message,
      holdMs: duration == ArcadeNoticeDuration.short ? 1000 : 2000,
      onDone: () {
        if (identical(_current, entry)) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

const int _kInMs = 260;
const int _kOutMs = 160;

class _ArcadeNoticePlate extends StatefulWidget {
  const _ArcadeNoticePlate({
    required this.message,
    required this.holdMs,
    required this.onDone,
  });

  final String message;
  final int holdMs;
  final VoidCallback onDone;

  @override
  State<_ArcadeNoticePlate> createState() => _ArcadeNoticePlateState();
}

class _ArcadeNoticePlateState extends State<_ArcadeNoticePlate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final int _totalMs;
  bool _reduce = false;

  double get _fOut => (_totalMs - _kOutMs) / _totalMs;
  double get _fIn => _kInMs / _totalMs;

  @override
  void initState() {
    super.initState();
    _totalMs = _kInMs + widget.holdMs + _kOutMs;
    // Eager controller assignment (never a lazy field initializer — the
    // reduced-motion dispose path would lazily construct it during dispose).
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reduce = media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Jump to the power-off segment; from mid-power-on the plate blips full
  /// for one frame then collapses — reads as a fast dismissal, never a snap.
  void _dismiss() {
    if (!mounted || _c.status == AnimationStatus.completed) return;
    if (_c.value < _fOut) _c.forward(from: _fOut);
  }

  // ── the Option-A curve: scanline → stepped vertical expand → collapse ─────
  /// Vertical scale of the plate at controller value [t].
  double _scaleY(double t) {
    if (_reduce) return 1;
    if (t < _fIn) {
      final p = t / _fIn;
      if (p < 0.35) return 0.04; // the held scanline beat
      if (p < 0.70) {
        // Stepped expand (5 quantized steps) with a 1.06 overshoot peak.
        final e = (p - 0.35) / 0.35;
        final stepped = (e * 5).ceil() / 5;
        return 0.04 + (1.06 - 0.04) * stepped;
      }
      return 1.06 - 0.06 * ((p - 0.70) / 0.30); // settle
    }
    if (t >= _fOut) {
      final p = (t - _fOut) / (1 - _fOut);
      if (p < 0.55) return 1 - (1 - 0.06) * (p / 0.55) * (p / 0.55);
      return 0.04;
    }
    return 1;
  }

  double _opacity(double t) {
    if (t >= _fOut) {
      final p = (t - _fOut) / (1 - _fOut);
      return p < 0.55 ? 1 : 1 - (p - 0.55) / 0.45;
    }
    if (_reduce) return 1;
    return t < _fIn * 0.10 ? 0 : 1;
  }

  /// The bright scanline shows only while the plate is line/expanding.
  double _lineOpacity(double t) {
    if (_reduce) return 0;
    if (t < _fIn) {
      final p = t / _fIn;
      if (p < 0.35) return 1;
      if (p < 0.70) return 0.6;
      return 0;
    }
    if (t >= _fOut) {
      final p = (t - _fOut) / (1 - _fOut);
      return p >= 0.55 ? 0.9 : 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // No Material ancestor on a bare overlay entry — provide our own so the
    // text never paints the yellow no-Material debug underline.
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen tap observer: translucent = receives every pointer-down
        // AND lets the tap continue to whatever is underneath. Down-only, so
        // a long-press-triggered notice isn't dismissed by its own release.
        // haptic-ok: passive dismiss observer, performs no action of its own
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _dismiss(),
          child: const SizedBox.expand(),
        ),
        _buildPlate(),
      ],
    );
  }

  Widget _buildPlate() {
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Never short-circuit to an empty tree at opacity 0 — the whole
            // suite asserts notices with a single bare pump(), so the Text
            // must exist from the very first frame.
            final op = _opacity(t).clamp(0.0, 1.0);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace5),
                  child: Opacity(
                    opacity: op,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform(
                          transform: Matrix4.diagonal3Values(
                            1,
                            _scaleY(t).clamp(0.04, 1.2),
                            1,
                          ),
                          alignment: Alignment.center,
                          child: Semantics(
                            liveRegion: true,
                            label: widget.message,
                            excludeSemantics: true,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: kSpace4,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: kCard,
                                borderRadius: BorderRadius.circular(
                                  kCardRadius,
                                ),
                                border: Border.all(
                                  color: kBorder,
                                  width: kPrimaryCardBorderWidth,
                                ),
                              ),
                              child: Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 8,
                                  height: 1.8,
                                  color: kText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The CRT scanline riding the power transitions.
                        if (_lineOpacity(t) > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              color: bitGlow.withValues(
                                alpha: _lineOpacity(t).clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
