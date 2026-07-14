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

  /// The quest-claim burst sound — a soft "power blip" fired at the claim impact
  /// (t0), synced with the card's flash/shard burst. Source: Juhani Junkala's
  /// "512 Sound Effects (8-bit style)" pack (`sfx_sounds_powerup15`, low-passed),
  /// released **CC0 / public domain** — ships without attribution. Replaces the
  /// old ascending arpeggio (`quest_claim.wav`), which read too "rising/sparkle"
  /// against the chunky pixel burst.
  Future<void> playQuestClaim() =>
      _play('audio/quest_claim_burst.wav', volume: 0.7);

  /// The finish-arc **level-up chime** — the celebratory hit at each level the XP
  /// bar crosses. The star of the arc's audio, so it sits loudest. A discrete
  /// reward (like the level-up haptic), it fires even under reduced motion —
  /// muting is the Sound toggle's job, not reduced-motion's. Source: same CC0
  /// Juhani Junkala 512-pack as [playQuestClaim] (a fanfare), ships without
  /// attribution.
  Future<void> playLevelUp() => _play('audio/level_up.wav', volume: 0.7);

  /// The **"bar running up" riser** — a synthesized chiptune square-wave sweep
  /// that STEPS up in pitch (C4→C6) as the XP bar climbs, resolving into the
  /// level chime at the crossing. A generated tone (not a pack sample) so the
  /// rise is exact and tunable — regenerate via `python ops/gen_xp_riser.py`.
  /// Accompanies the fill animation, so callers skip it under reduced motion
  /// (the bar snaps).
  Future<void> playXpRiser() => _play('audio/xp_riser.wav', volume: 0.6);

  /// A short **rolling tally** for the STAT GAINS count-up (one shot for the
  /// whole row, not one-per-number — the single player would cut those off, and
  /// a per-number train would drone). Accompanies the roll, so callers skip it
  /// under reduced motion (the numbers snap).
  Future<void> playStatCounter() =>
      _play('audio/stat_counter.wav', volume: 0.5);

  // ── BIT Session-Complete ceremony micro-cues ───────────────────────────────
  // Faithful synths of the ceremony handoff's WebAudio tones (gain ratio baked
  // into the wavs — regenerate via `python ops/gen_ceremony_sfx.py`). All three
  // accompany the ceremony animation, which never plays under reduced motion.

  /// The quiet **arrival tick** (330 Hz, 35 ms) as BIT appears dormant (t=150ms).
  Future<void> playCeremonyTick() =>
      _play('audio/ceremony_tick.wav', volume: 0.7);

  /// The **surge release chime** (660→990 Hz) as BIT bursts into cheer (t=500ms).
  Future<void> playCeremonyChime() =>
      _play('audio/ceremony_chime.wav', volume: 0.7);

  /// The **landing impact thud** as BIT slams into its seat (t=2550ms) — a
  /// sub-bass pitch-drop punch + dust-burst noise (user-directed upgrade of
  /// the handoff's quiet 210 Hz blip: a strong landing, not a beep).
  Future<void> playCeremonyLand() =>
      _play('audio/ceremony_land.wav', volume: 0.8);

  /// The **feature-unlock fanfare** — the NEW SYSTEM ONLINE victory hit at the
  /// unlock ceremony's surge (t=500ms): a power-on riser into a rising C-major
  /// arpeggio resolving on a held C6+G5 chord with a sparkle. Synthesized
  /// (regenerate via `python ops/gen_unlock_sfx.py`); replaced the borrowed
  /// session-ceremony chime, which read as "a beep, not victorious".
  Future<void> playUnlockFanfare() =>
      _play('audio/unlock_fanfare.wav', volume: 0.75);

  /// The **banked-flight dash fwoosh** (t=1050ms) — a square-wave doppler
  /// pitch ride (with vibrato) over a quiet noise air-layer, tracking the
  /// flight's speed curve; authored to fade to silence by 1.40s so the landing
  /// hit never cuts live energy (Codex F3).
  Future<void> playCeremonyFlight() =>
      _play('audio/ceremony_flight.wav', volume: 0.7);

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
