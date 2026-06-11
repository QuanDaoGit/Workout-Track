import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The app's sound effects. Intentionally tiny: fire-and-forget one-shots, every
/// call guarded so audio is never load-bearing.
///
/// Sound is *non-essential feedback* — a missing plugin (widget tests), an
/// unsupported platform, or a device audio failure must never break the flow
/// that triggered it. Failures are caught and logged (not surfaced) so they stay
/// visible during development without affecting the caller. Toggle [enabled] off
/// to mute (the Settings -> Sound switch).
///
/// Each shot uses a **fresh** [AudioPlayer]: a single reused player won't
/// reliably replay the same asset (after the first playback the native player is
/// in a stopped/completed state bound to the same source URL, so a second
/// `play()` of that URL doesn't re-prepare → silence). The previous player is
/// stopped + disposed first, which also makes a rapid re-trigger interrupt the
/// in-progress chime and restart it.
class SfxService {
  SfxService._();

  static final SfxService instance = SfxService._();

  /// Global mute switch (the Settings sound toggle / tests). When false, all
  /// playback is a no-op.
  static bool enabled = true;

  AudioPlayer? _current;

  /// The quest-claim chime — the app's first sound. One ascending chiptune
  /// arpeggio (`assets/audio/quest_claim.wav`).
  Future<void> playQuestClaim() => _play('audio/quest_claim.wav', volume: 0.7);

  Future<void> _play(String assetPath, {double volume = 1.0}) async {
    if (!enabled) return;

    // Interrupt + release any chime still playing.
    final previous = _current;
    _current = null;
    if (previous != null) {
      try {
        await previous.stop();
        await previous.dispose();
      } catch (_) {
        // best effort — the old player may already be released
      }
    }

    try {
      final player = AudioPlayer()..setReleaseMode(ReleaseMode.release);
      _current = player;
      await player.play(AssetSource(assetPath), volume: volume);
    } catch (e) {
      // Non-essential: never surface audio failure to the caller, but log it so
      // it isn't silently invisible during development.
      debugPrint('SfxService: failed to play $assetPath: $e');
    }
  }

  Future<void> dispose() async {
    final player = _current;
    _current = null;
    try {
      await player?.dispose();
    } catch (_) {
      // ignore
    }
  }
}
