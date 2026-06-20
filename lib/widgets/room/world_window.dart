import 'package:flutter/material.dart';

/// Time-of-day buckets for the world-window.
enum RoomTimeOfDay { morning, noon, afternoon, evening }

/// Maps a wall-clock time to one of the four window states.
RoomTimeOfDay roomTimeOfDayNow([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 11) return RoomTimeOfDay.morning;
  if (h < 16) return RoomTimeOfDay.noon;
  if (h < 19) return RoomTimeOfDay.afternoon;
  return RoomTimeOfDay.evening;
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
