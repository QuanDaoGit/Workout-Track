import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'ui_sound.dart';

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

  /// Dedicated channel for the Charge Ritual boost cues, so the general
  /// single-player [_play] (e.g. a next-screen sound during the transition)
  /// can't cut the ignite mid-flight. The riser → ignite still resolve on THIS
  /// channel (ignite replaces the riser here); a general SFX leaves it alone.
  AudioPlayer? _boost;

  /// Test seam: invoked with the asset path on every play attempt, BEFORE the
  /// [enabled] gate, so a test can assert which cues fire on which edge with no
  /// real audio. Install in setUp, clear in tearDown — never left set in prod.
  @visibleForTesting
  static void Function(String cue)? debugOnPlay;

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

  // ── Interaction tier — the pooled low-latency micro channel ────────────────
  // Unlike the ceremony channel above (one player, interrupt-on-play), these
  // fire through per-asset [AudioPool]s in [PlayerMode.lowLatency] so a tick
  // can never cut a playing fanfare and tap-to-sound stays tight. Assets are
  // authored to a loudness ladder (tap 0.10 < warn 0.20 < set-log 0.22 <
  // rest 0.30 < ceremony 0.32 peaks — `ops/gen_ui_sfx.py`), so everything
  // plays at full volume and the hierarchy is baked in.

  /// Extra gate for the broad tap-tick layer only (the Settings "UI sounds"
  /// sub-toggle, `UiSoundSettingsService`, default on). Core-loop sounds
  /// (set-log / rest-end / warning) ride the master [enabled] alone.
  static bool uiSoundsEnabled = true;

  /// Injectable clock for the per-class cooldowns (mirrors
  /// `HapticService.nowProvider` so tests advance time deterministically).
  static DateTime Function() nowProvider = DateTime.now;

  /// Test seam: invoked with the asset path for every sound that passes its
  /// gates/cooldowns, *before* the platform call (which has no implementation
  /// in widget tests) — so tests assert plays without the plugin.
  @visibleForTesting
  static void Function(String assetPath)? onPlayForTest;

  /// Broad-layer rate limit: a machine-gunned button can't stack ticks.
  static const Duration uiTapCooldown = Duration(milliseconds: 60);

  /// Burst guard for rapid sequential logging (corrections / warm-ups
  /// back-to-back) — variants alone don't prevent fatigue (Codex).
  static const Duration setLoggedCooldown = Duration(milliseconds: 1000);

  /// The arbiter window (Codex, SFX v2): after any non-micro role fires
  /// (warn / skip / rest / signature), micro ticks are suppressed briefly so
  /// one gesture never stacks a tick under its louder sound.
  static const Duration microSuppress = Duration(milliseconds: 80);

  DateTime? _lastMicroAt;
  DateTime? _lastNonMicroAt;
  final Map<UiSound, DateTime> _lastConfirmAt = {};
  final Map<UiSound, int> _variantCursor = {};

  final Map<String, Future<AudioPool>> _poolFutures = {};
  final Set<String> _deadPools = {};

  /// Route ALL app audio into a mix-with-others sonification context.
  ///
  /// audioplayers' Android default is `AUDIOFOCUS_GAIN` + `USAGE_MEDIA` — every
  /// sound requests full audio focus, which can PAUSE the user's own
  /// music/podcast mid-workout (the exact bug Hevy shipped and fixed in
  /// 1.26.11). `audioFocus: none` mixes instead of stealing;
  /// sonification/assistanceSonification declares "short UI feedback, not a
  /// media session". Global on purpose: the latent defect lives on the
  /// *ceremony* channel too. Called once at boot; fail-open (no plugin in
  /// widget tests).
  /// True under `flutter test`. Touching audioplayers AT ALL in that env is
  /// unsafe — constructing an [AudioPlayer] (which [AudioPool.create] does
  /// internally) kicks off an *unawaited, memoized* global-init future inside
  /// the package whose MissingPluginException escapes any try/catch and fails
  /// the surrounding test zone (and, once memoized, hangs awaits from other
  /// zones). So in tests the platform layer is skipped entirely — the
  /// [onPlayForTest] recorder, which fires after all gates, IS the observable
  /// playback contract.
  static final bool _isFlutterTest = () {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }();

  Future<void> applyGlobalAudioContext() async {
    if (_isFlutterTest) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      debugPrint('SfxService: applyGlobalAudioContext failed: $e');
    }
  }

  /// Pre-create the micro pools so the first tap doesn't pay pool-construction
  /// latency. Fire-and-forget from boot (never awaited on the splash path);
  /// every per-asset failure is swallowed and the pool marked dead so playback
  /// degrades to silence, never a throw into boot.
  Future<void> warmUpUiPools() async {
    if (_isFlutterTest) return;
    final assets = kUiSoundSpecs.values.expand((s) => s.assets);
    for (final asset in assets) {
      try {
        await _pool(asset);
      } catch (e) {
        _poolFutures.remove(asset);
        _deadPools.add(asset);
        debugPrint('SfxService: pool warm-up failed for $asset: $e');
      }
    }
  }

  Future<AudioPool> _pool(String asset) =>
      // `??=` with a synchronous RHS is race-free: two rapid first taps share
      // one create future instead of building two pools.
      _poolFutures[asset] ??= AudioPool.create(
        source: AssetSource(asset),
        maxPlayers: 2,
        playerMode: PlayerMode.lowLatency,
      );

  Future<void> _playPooled(String asset) async {
    onPlayForTest?.call(asset);
    if (_isFlutterTest || _deadPools.contains(asset)) return;
    try {
      final pool = await _pool(asset);
      await pool.start();
    } catch (e) {
      // Non-essential: degrade this asset to silence (test env / device audio
      // failure) rather than ever surfacing to the caller.
      _poolFutures.remove(asset);
      _deadPools.add(asset);
      debugPrint('SfxService: pooled play failed for $asset: $e');
    }
  }

  /// Play a kit sound by ROLE — the single entry point for the interaction
  /// tier (SFX v2). Applies the spec's gates (master / sub-toggle), the
  /// cooldown class, the arbiter (non-micro suppresses micro for
  /// [microSuppress]), and variant rotation. See `ui_sound.dart` for the
  /// registry + the grammar.
  Future<void> playUi(UiSound sound) {
    final spec = kUiSoundSpecs[sound]!;
    if (!enabled) return Future<void>.value();
    if (spec.subToggle && !uiSoundsEnabled) return Future<void>.value();
    final now = nowProvider();
    switch (spec.cooldown) {
      case UiSoundCooldown.micro:
        final lastMicro = _lastMicroAt;
        if (lastMicro != null && now.difference(lastMicro) < uiTapCooldown) {
          return Future<void>.value();
        }
        final lastLoud = _lastNonMicroAt;
        if (lastLoud != null && now.difference(lastLoud) < microSuppress) {
          // A louder role just fired for this gesture — the tick yields.
          return Future<void>.value();
        }
        _lastMicroAt = now;
      case UiSoundCooldown.confirm:
        final last = _lastConfirmAt[sound];
        if (last != null && now.difference(last) < setLoggedCooldown) {
          return Future<void>.value();
        }
        _lastConfirmAt[sound] = now;
        _lastNonMicroAt = now;
      case UiSoundCooldown.none:
        _lastNonMicroAt = now;
    }
    final idx = (_variantCursor[sound] ?? 0) % spec.assets.length;
    _variantCursor[sound] = idx + 1;
    return _playPooled(spec.assets[idx]);
  }

  // Thin named delegates — existing call sites and tests stay stable.
  Future<void> playUiTap() => playUi(UiSound.tick);
  Future<void> playSetLogged() => playUi(UiSound.setLogged);
  Future<void> playUiWarn() => playUi(UiSound.warn);

  /// Between-EXERCISE rest elapsed (the full ready-go chorus). The
  /// between-SET surface plays [UiSound.restGoSet] instead — the weaker
  /// sibling. Both best-effort over the user's own music; the rest-end
  /// notification remains the reliable backgrounded path; call sites dedupe
  /// via the live-finish guard + `RestTimerService.cancel()`.
  Future<void> playRestGo() => playUi(UiSound.restGoExercise);

  /// Restore every static + instance mutable knob this service exposes —
  /// cooldown stamps, variant cursors, injected clock, test recorder, pool
  /// caches — so one test's state can't silence or redirect the next (Codex).
  @visibleForTesting
  void resetForTest() {
    enabled = true;
    uiSoundsEnabled = true;
    nowProvider = DateTime.now;
    onPlayForTest = null;
    _lastMicroAt = null;
    _lastNonMicroAt = null;
    _lastConfirmAt.clear();
    _variantCursor.clear();
    _poolFutures.clear();
    _deadPools.clear();
  }

  // ── Charge Ritual boost cues (dedicated channel) ────────────────────────────
  // Hybrid V2 riser + E2 boom/whoosh ignition, auditioned & selected; synthesized
  // via `python ops/gen_boost_sfx.py`. Fire on the pour-start / ignition / release
  // phase edges. Skipped by the `enabled` gate + reduced-SFX like every cue.

  /// The ~3s hold-to-charge **riser** — a detuned-saw glide + rising energy
  /// sweep, starting on pour-start (hold OR the accessible auto-fill tap).
  Future<void> playBoostCharge() =>
      _playBoost('audio/boost_charge.wav', volume: 0.65);

  /// The **ignition** at 100% — a sub-bass boom + a descending power-cycle
  /// whoosh (voiced to the CRT collapse). Replaces the riser on the boost
  /// channel (the resolve).
  Future<void> playBoostIgnite() =>
      _playBoost('audio/boost_ignite.wav', volume: 0.7);

  /// The short descending **power-down** blip when the hold is released before
  /// 100% (the pour drains back).
  Future<void> playBoostRelease() =>
      _playBoost('audio/boost_release.wav', volume: 0.55);

  Future<void> _playBoost(String assetPath, {double volume = 1.0}) async {
    debugOnPlay?.call(assetPath);
    if (!enabled) return;
    // Claim the channel SYNCHRONOUSLY (create + assign before any await) so a
    // rapid re-trigger sees THIS player as its `previous` and stops it — no
    // null-window where two fire-and-forget boost cues can overlap (Codex review).
    final player = AudioPlayer()..setReleaseMode(ReleaseMode.release);
    final previous = _boost;
    _boost = player;
    if (previous != null) {
      try {
        await previous.stop();
        await previous.dispose();
      } catch (_) {
        // best effort
      }
    }
    try {
      await player.play(AssetSource(assetPath), volume: volume);
    } catch (e) {
      debugPrint('SfxService: failed to play $assetPath: $e');
    }
  }

  Future<void> _play(String assetPath, {double volume = 1.0}) async {
    debugOnPlay?.call(assetPath);
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
    final current = _current;
    final boost = _boost;
    _current = null;
    _boost = null;
    try {
      await current?.dispose();
      await boost?.dispose();
    } catch (_) {
      // ignore
    }
  }
}
