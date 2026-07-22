import 'package:flutter/material.dart';

/// Time-of-day buckets for the world-window. The names are historical; each
/// maps to the sky the art actually paints:
///   morning   → sunrise  (sun low on the horizon, warm orange)
///   noon      → daylight (bright blue, sun high)
///   afternoon → sunset   (sun setting, golden dusk)
///   evening   → night    (crescent moon + stars, dark navy)
enum RoomTimeOfDay { morning, noon, afternoon, evening }

/// Maps the wall-clock hour to the window's sky.
///
/// Tuned to an *average* day, season-agnostic: it roughly anchors to
/// equinox-style timing (sunrise ~06:00, solar noon ~12:00, sunset ~18:00) as a
/// neutral baseline — an approximation, since real wall-clock sky time drifts
/// with longitude-in-timezone and DST, which doesn't matter for decorative art.
/// Crucially, night
/// (the moon frame) now owns every dark hour — including across midnight,
/// through pre-dawn — instead of the old table that painted a sunrise at 00:00.
///
///   00:00–05:59  night     (dark, pre-dawn)
///   06:00–08:59  sunrise
///   09:00–16:59  daylight
///   17:00–18:59  sunset
///   19:00–23:59  night
RoomTimeOfDay roomTimeOfDayNow([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 6) return RoomTimeOfDay.evening; // pre-dawn night
  if (h < 9) return RoomTimeOfDay.morning; // sunrise
  if (h < 17) return RoomTimeOfDay.noon; // daylight
  if (h < 19) return RoomTimeOfDay.afternoon; // sunset
  return RoomTimeOfDay.evening; // night
}

/// The room's world-window — pixel-art decor on the wall that shifts by time of
/// day (handoff `components/04-world-window.md`). A static frame (the APNG's
/// first frame, crisp/nearest-neighbour) plus a matching colored glow that
/// gently breathes onto the surrounding wall — the calm, pressure-free pull
/// that makes returning feel alive.
///
/// Drive [timeOfDay] from the device clock (default: [roomTimeOfDayNow]). The
/// glow colors are ambient sky-light art (not brand tokens), so a soft
/// `RadialGradient` is the right tool here (only the *pad* light must be pixel).
class WorldWindow extends StatefulWidget {
  const WorldWindow({super.key, this.timeOfDay});

  /// Defaults to the current device clock when null.
  final RoomTimeOfDay? timeOfDay;

  @override
  State<WorldWindow> createState() => _WorldWindowState();
}

class _WorldWindowState extends State<WorldWindow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _glow
        ..stop()
        ..value = 0.5;
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tod = widget.timeOfDay ?? roomTimeOfDayNow();
    final glowColor = _glowColors[tod]!;
    return LayoutBuilder(
      builder: (context, c) {
        final gi = c.maxWidth * 0.18; // glow bleed beyond the frame
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -gi,
              top: -gi,
              right: -gi,
              bottom: -gi,
              child: AnimatedBuilder(
                animation: _glow,
                builder: (context, _) => Opacity(
                  opacity: 0.45 + 0.18 * _glow.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [glowColor, glowColor.withValues(alpha: 0)],
                        stops: const [0, 0.68],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                _assets[tod]!,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
                gaplessPlayback: true,
                semanticLabel: 'World window',
                errorBuilder: (context, error, stack) =>
                    DecoratedBox(decoration: BoxDecoration(color: glowColor)),
              ),
            ),
          ],
        );
      },
    );
  }
}

const Map<RoomTimeOfDay, String> _assets = {
  RoomTimeOfDay.morning: 'assets/room/window_morning.png',
  RoomTimeOfDay.noon: 'assets/room/window_noon.png',
  RoomTimeOfDay.afternoon: 'assets/room/window_afternoon.png',
  RoomTimeOfDay.evening: 'assets/room/window_evening.png',
};

// Ambient sky-glow tints (art, not brand) — from components/04-world-window.md.
const Map<RoomTimeOfDay, Color> _glowColors = {
  RoomTimeOfDay.morning: Color(0x61FFB060),
  RoomTimeOfDay.noon: Color(0x667FB6E8),
  RoomTimeOfDay.afternoon: Color(0x6BE0682A),
  RoomTimeOfDay.evening: Color(0x5C6F90D8),
};
