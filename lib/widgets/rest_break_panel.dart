import 'dart:async';

import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../services/rest_timer_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'companion/bit_mood_core.dart';

/// The between-exercise rest beat: a focal takeover that replaces the workout
/// overview list while the post-Finish-Exercise rest counts down. BIT settles
/// into its [BitPose.rest] (floating sub-pixel, plates breathing, dimmed) — the
/// app's recovery-is-protective doctrine made visible — beside a live countdown,
/// ±15s controls, and a single neon SKIP REST that returns the user to logging.
///
/// Owns a dispose-managed 1s ticker (never a service-owned `Timer`, which leaks
/// as a flutter_test pending timer): it refreshes the countdown and, on a *live*
/// rest-end, fires one guarded success haptic then [RestTimerService.cancel] —
/// the same contract the thin [RestTimerBar] uses, de-duped via `cancel()`. The
/// host (`active_workout`) keeps this panel the sole rest surface and cancels the
/// service on every page exit, so there is exactly one haptic owner per phase.
class RestBreakPanel extends StatefulWidget {
  const RestBreakPanel({
    super.key,
    required this.onSkip,
    this.nextExerciseName,
  });

  /// SKIP REST — cancels the rest and hands control back to the host so the
  /// exercise list returns ("keep logging").
  final VoidCallback onSkip;

  /// Name of the next un-cleared exercise, shown so the user can eye the next
  /// movement without leaving rest. Omitted (line hidden) when null/empty.
  final String? nextExerciseName;

  @override
  State<RestBreakPanel> createState() => _RestBreakPanelState();
}

class _RestBreakPanelState extends State<RestBreakPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final snap = RestTimerService.instance.current.value;
      if (snap != null && !snap.isActive) {
        // Rest just elapsed — one "go" haptic for a *live* finish only (a stale
        // backgrounded expiry is covered by the rest-end notification, so a buzz
        // on resume is suppressed). cancel() de-dupes if another rest surface is
        // mounted, so this fires exactly once.
        if (DateTime.now().difference(snap.endsAt) <
            const Duration(seconds: 3)) {
          HapticService.instance.success();
        }
        RestTimerService.instance.cancel();
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

  String _spoken(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final parts = <String>[if (m > 0) '$m min', '$s sec'];
    return 'Rest, ${parts.join(' ')} remaining';
  }

  @override
  Widget build(BuildContext context) {
    final snap = RestTimerService.instance.current.value;
    // Defensive: the host only mounts this while a rest is active, but if it has
    // just been cancelled the host will unmount us on the next frame.
    if (snap == null) return const SizedBox.shrink();
    final remaining = snap.remaining;
    final next = widget.nextExerciseName?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace4,
        vertical: kSpace5,
      ),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kCyan),
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: neonGlow(color: kCyan, opacity: 0.12, blur: 18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BitMoodCore(pose: BitPose.rest, reveal: 1, size: 96),
          const SizedBox(height: kSpace3),
          Semantics(
            liveRegion: true,
            label: _spoken(remaining),
            excludeSemantics: true,
            child: Text(
              // PressStart2P to match the session ELAPSED clock (one timer face).
              _fmt(remaining),
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 30,
                color: kCyan,
              ),
            ),
          ),
          const SizedBox(height: kSpace2),
          Text(
            'Recover. Breathe. The next lift waits.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: kMutedText),
          ),
          if (next != null && next.isNotEmpty) ...[
            const SizedBox(height: kSpace2),
            Text(
              'NEXT · $next',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ],
          const SizedBox(height: kSpace5),
          Row(
            children: [
              Expanded(
                child: _AdjustButton(
                  label: '−15s',
                  semanticLabel: 'Subtract 15 seconds of rest',
                  onTap: () => RestTimerService.instance.adjust(-15),
                ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(
                child: _AdjustButton(
                  label: '+15s',
                  semanticLabel: 'Add 15 seconds of rest',
                  onTap: () => RestTimerService.instance.adjust(15),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace2),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                HapticService.instance.tap(); // skip the rest, back to logging
                widget.onSkip();
              },
              style: FilledButton.styleFrom(
                backgroundColor: kCyan,
                foregroundColor: kBg,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kCardRadius),
                ),
              ),
              child: Text(
                'SKIP REST',
                style: AppFonts.shareTechMono(
                  color: kBg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A secondary ±15s control: muted-bordered, mono-labelled, ≥44px tall, with its
/// own Semantics name (the glyph label reads poorly to a screen reader).
class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FilledButton(
        onPressed: () {
          // Coalesced so a fast ±15s tap-storm stays a tick, not a buzz.
          HapticService.instance.fireCoalesced(HapticIntent.selection);
          onTap();
        },
        style: FilledButton.styleFrom(
          backgroundColor: kCard,
          foregroundColor: kText,
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: kMutedText),
        ),
        child: Text(
          label,
          style: AppFonts.shareTechMono(
            color: kText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
