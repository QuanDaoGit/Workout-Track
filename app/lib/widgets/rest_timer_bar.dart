import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../services/haptic_service.dart';
import '../services/rest_timer_service.dart';
import '../services/sfx_service.dart';
import '../services/ui_sound.dart';
import '../theme/tokens.dart';
import 'arcade_bar.dart';

class RestTimerBar extends StatefulWidget {
  const RestTimerBar({super.key});

  @override
  State<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends State<RestTimerBar>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final snap = RestTimerService.instance.current.value;
      if (snap != null && !snap.isActive) {
        // Rest just elapsed — a single "go" haptic the lifter feels without
        // watching. Only for a *live* finish: if the app was backgrounded past
        // the end, the rest-end notification already covered it, so a stale
        // buzz on resume is suppressed. cancel() de-dupes if another bar (the
        // other rest surface) is mounted, so this fires exactly once.
        if (DateTime.now().difference(snap.endsAt) <
            const Duration(seconds: 3)) {
          HapticService.instance.success();
          // The audible "go" beside the haptic — same exactly-once contract
          // (serialised tickers + the synchronous cancel() below). This is the
          // between-SET surface, so it plays the WEAKER rest sibling; the
          // between-exercise takeover plays the full ready-go chorus.
          SfxService.instance.playUi(UiSound.restGoSet);
        }
        RestTimerService.instance.cancel();
        if (_expanded) _expanded = false;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  double _fraction(RestSnapshot snap) {
    final totalMs = snap.totalSeconds * 1000;
    if (totalMs <= 0) return 0;
    return (snap.remaining.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RestSnapshot?>(
      valueListenable: RestTimerService.instance.current,
      builder: (context, snap, _) {
        if (snap == null || !snap.isActive) return const SizedBox.shrink();

        return AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _ExpandedRestBar(
                  snap: snap,
                  fmt: _fmt,
                  onCollapse: () => setState(() => _expanded = false),
                )
              : _CollapsedRestBar(
                  fraction: _fraction(snap),
                  onTap: () => setState(() => _expanded = true),
                ),
        );
      },
    );
  }
}

class _CollapsedRestBar extends StatelessWidget {
  const _CollapsedRestBar({required this.fraction, required this.onTap});

  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 20,
        width: double.infinity,
        child: Center(
          child: ArcadeBar(
            value: fraction,
            accent: kNeon,
            height: 6,
            flashOnIncrease: false,
          ),
        ),
      ),
    );
  }
}

class _ExpandedRestBar extends StatelessWidget {
  const _ExpandedRestBar({
    required this.snap,
    required this.fmt,
    required this.onCollapse,
  });

  final RestSnapshot snap;
  final String Function(Duration) fmt;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final remaining = snap.remaining;
    final totalCells = (snap.totalSeconds / 15).ceil().clamp(1, 24);
    final litCells = (remaining.inSeconds / 15).ceil().clamp(0, totalCells);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(color: kNeon),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCollapse,
                child: Row(
                  children: [
                    Text(
                      'REST',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ArcadeBar.segments(
                        totalCells: totalCells,
                        litCells: litCells,
                        height: 8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      fmt(remaining),
                      style: AppFonts.shareTechMono(
                        color: kNeon,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // haptic-ok: fires its own beat inline — the skip release + tap.
            GestureDetector(
              onTap: () {
                HapticService.instance.tap();
                SfxService.instance.playUi(UiSound.skip);
                RestTimerService.instance.cancel();
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: kMutedText),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SKIP',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
