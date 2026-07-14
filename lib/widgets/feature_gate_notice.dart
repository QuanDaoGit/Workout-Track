import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/feature_gate_service.dart';
import '../theme/tokens.dart';

/// One-per-gate-per-shell-session analytics debounce (Codex P7) — the notice
/// itself still shows on every tap (feedback), only the event is deduped.
final Set<FeatureGate> _lockedViewLogged = {};

@visibleForTesting
void resetLockedNoticeDebounceForTest() => _lockedViewLogged.clear();

/// The shared locked-tap feedback for every gated entry point: a brief
/// floating notice carrying the gate's invitation copy (never debt-framed —
/// what training opens, not what the user owes).
void showFeatureLockedNotice(BuildContext context, FeatureGate gate) {
  final spec = featureGateSpecs[gate]!;
  if (_lockedViewLogged.add(gate)) {
    AnalyticsService.instance.logFeatureLockedViewed(gate.name);
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          spec.lockedNotice,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            height: 1.6,
            color: kText,
          ),
        ),
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardRadius),
          side: const BorderSide(color: kBorder, width: 1.2),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}
