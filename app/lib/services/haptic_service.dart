import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// The semantic intent a surface fires. Lets a widget (e.g. `PixelButton`) take
/// a single value and defer the actual feel to [HapticService.fire] — so the
/// device feel stays tunable in one place. [HapticIntent.none] is the explicit
/// opt-out for a surface whose handler already fires its own haptic.
enum HapticIntent { none, selection, tap, success, reward, warning }

/// The app's haptic feedback. Intentionally tiny: fire-and-forget one-shots,
/// every call guarded so haptics are never load-bearing.
///
/// Haptics are *non-essential feedback* — a missing platform impl (widget
/// tests), an unsupported device, or an OEM that suppresses a given constant
/// must never break the flow that triggered it. Failures are caught and logged
/// (not surfaced) so they stay visible during development without affecting the
/// caller. Toggle [enabled] off to mute (the Settings -> Haptics switch, loaded
/// from `HapticSettingsService` at boot).
///
/// Call sites name **intent**, not raw impact levels, so the device feel can be
/// tuned in one place — and later *upgraded* (e.g. a designed `vibration`-package
/// pattern for [reward]/[warning]) — without touching a single caller.
///
/// Built on Flutter's [HapticFeedback], which routes through Android's
/// `View.performHapticFeedback()`: it needs **no `VIBRATE` permission** and it
/// **respects the user's system touch-feedback setting**. Haptics are tactile,
/// not a vestibular trigger, so they are deliberately **not** gated by
/// reduced-motion — they carry their own [enabled] opt-out instead.
class HapticService {
  HapticService._();

  static final HapticService instance = HapticService._();

  /// Global mute switch (the Settings haptics toggle / tests). When false, all
  /// haptics are a no-op.
  static bool enabled = true;

  /// A discrete choice landed — a chip, tab, segment, toggle, or picker tick.
  Future<void> selection() => _fire(HapticFeedback.selectionClick);

  /// A light, ordinary button press.
  Future<void> tap() => _fire(HapticFeedback.lightImpact);

  /// A confirmed action landed — a set logged, a sheet saved, a commit.
  Future<void> success() => _fire(HapticFeedback.mediumImpact);

  /// A celebratory earn — a quest claim, a level-up, a milestone.
  ///
  /// Currently a medium impact (matching the app's existing reward feel); this
  /// is the single seam for the later landmark upgrade — a designed
  /// `vibration`-package pattern with a `heavyImpact` fallback — so lifting it
  /// here lifts every reward beat at once.
  Future<void> reward() => _fire(HapticFeedback.mediumImpact);

  /// A heavier bump for a destructive / irreversible confirm.
  Future<void> warning() => _fire(HapticFeedback.heavyImpact);

  /// Constant amplitude (1–255) of the XP-bar climb buzz. Moderate so an ~800ms
  /// sustain reads as "the bar is running up", not an alarm.
  static const int kClimbBuzzAmplitude = 110;

  /// Whether this device has a vibrator — resolved once, lazily. Only the raw
  /// `vibration`-driven methods below consult it; the stock impact methods route
  /// through `HapticFeedback` and never touch it. Null until first checked.
  static bool? _hasVibrator;

  Future<bool> _ensureVibrator() async {
    final cached = _hasVibrator;
    if (cached != null) return cached;
    try {
      return _hasVibrator = (await Vibration.hasVibrator()) == true;
    } catch (_) {
      return _hasVibrator = false;
    }
  }

  /// A **continuous, constant-strength** vibration for [durationMs] — the "bar
  /// running up" motion (deliberately a short sustain, not the discrete-tick
  /// house default; a caller opted into it). Unlike the one-shot impact methods
  /// this drives the raw vibrator (needs the `VIBRATE` permission) so it can hold
  /// a steady buzz. Gated by [enabled], fails open, and no-ops on a device
  /// without a vibrator. Reduced-motion callers skip it (it rides the fill
  /// animation). Cut it early with [stopBuzz]; a fresh call replaces any ongoing
  /// buzz.
  Future<void> climbBuzz({
    required int durationMs,
    int amplitude = kClimbBuzzAmplitude,
  }) async {
    if (!enabled) return;
    try {
      if (!await _ensureVibrator()) return;
      await Vibration.vibrate(duration: durationMs, amplitude: amplitude);
    } catch (e) {
      debugPrint('HapticService: climbBuzz failed: $e');
    }
  }

  /// Stop any ongoing [climbBuzz] / [flightSwell] immediately.
  Future<void> stopBuzz() async {
    try {
      await Vibration.cancel();
    } catch (_) {
      // best effort
    }
  }

  /// Whether the vibrator supports per-segment amplitude — resolved once,
  /// lazily. Gates the shaped [flightSwell]: without amplitude control a long
  /// intensities pattern collapses into a constant on/off drone (the exact
  /// thing the intensity doctrine forbids), so those devices fall back to
  /// discrete pulses instead (Codex F2).
  static bool? _hasAmplitude;

  Future<bool> _ensureAmplitudeControl() async {
    final cached = _hasAmplitude;
    if (cached != null) return cached;
    try {
      return _hasAmplitude = (await Vibration.hasAmplitudeControl()) == true;
    } catch (_) {
      return _hasAmplitude = false;
    }
  }

  /// The ceremony flight's **shaped swell** — a 1.5s amplitude envelope that
  /// tracks BIT's banked-flight speed curve (soft through the pull-back,
  /// peaking briefly through the acceleration, decaying into the settle). A
  /// designed contour, not a drone: it needs real amplitude control, so on
  /// devices without it the swell degrades to **three discrete pulses**
  /// (liftoff / apex / approach) rather than 1.5s of constant buzz. Rides the
  /// flight animation (never fires under reduced motion — the ceremony doesn't
  /// run there). Cancel with [stopBuzz] on skip/dispose.
  Future<void> flightSwell() async {
    if (!enabled) return;
    try {
      if (!await _ensureVibrator()) return;
      if (await _ensureAmplitudeControl()) {
        // 10 × 150ms segments; intensities follow the flight arc, peak 120.
        await Vibration.vibrate(
          pattern: const [0, 150, 0, 150, 0, 150, 0, 150, 0, 150,
              0, 150, 0, 150, 0, 150, 0, 150, 0, 150],
          intensities: const [0, 20, 0, 35, 0, 55, 0, 80, 0, 105,
              0, 120, 0, 100, 0, 70, 0, 40, 0, 20],
        );
      } else {
        // Discrete fallback: liftoff / apex (~750ms) / approach (~1300ms).
        await Vibration.vibrate(pattern: const [0, 35, 715, 35, 515, 40]);
      }
    } catch (e) {
      debugPrint('HapticService: flightSwell failed: $e');
    }
  }

  /// The touchdown **thump** — one firm bump as BIT lands in its seat, synced
  /// with the landing thud + dust puff. Falls back to a medium impact without a
  /// raw vibrator (tests / no-vibrator devices).
  Future<void> landThump() async {
    if (!enabled) return;
    try {
      if (await _ensureVibrator()) {
        await Vibration.vibrate(duration: 60, amplitude: 165);
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('HapticService: landThump failed: $e');
    }
  }

  /// The level-up **stamp** — two firm bumps ~75ms apart (the designed pattern
  /// this class's doc always anticipated as the [reward] upgrade seam). A
  /// discrete reward, so like [reward] it may fire even under reduced motion;
  /// gated only by [enabled]. Falls back to a double medium impact when the raw
  /// vibrator is unavailable (tests / no-vibrator devices).
  Future<void> levelUp() async {
    if (!enabled) return;
    try {
      if (await _ensureVibrator()) {
        // pattern = [waitMs, onMs, waitMs, onMs] → two stamped bumps.
        await Vibration.vibrate(pattern: const [0, 60, 75, 85]);
      } else {
        await HapticFeedback.mediumImpact();
        await HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('HapticService: levelUp failed: $e');
    }
  }

  /// The hold-to-boost **rising swell** — ONE pre-baked, gap-free waveform whose
  /// amplitude climbs floor→near-max over ~1.4s (the pour duration), so it feels
  /// like power building. Fired once when the pour begins and cancelled with
  /// [stopBuzz] on every release path (never re-issued per frame: repeatedly
  /// calling vibrate() cancel-restarts the motor on Android and stutters the
  /// envelope — research + Codex F4). A *rising* shape reads as "building" and,
  /// because it keeps changing, dodges the numbing "drone" of a flat buzz. Not
  /// gated by reduced motion (haptics carry their own toggle); no amplitude
  /// control degrades to one sustained buzz for the same span.
  Future<void> boostSwell() async {
    if (!enabled) return;
    try {
      if (!await _ensureVibrator()) return;
      if (await _ensureAmplitudeControl()) {
        // 10 gap-free 140ms segments (1400ms) rising 40→230 — a single continuous
        // buzz that strengthens toward the ignition.
        await Vibration.vibrate(
          pattern: const [0, 140, 140, 140, 140, 140, 140, 140, 140, 140, 140],
          intensities: const [0, 40, 60, 85, 110, 140, 170, 195, 215, 230, 230],
        );
      } else {
        await Vibration.vibrate(duration: 1400);
      }
    } catch (e) {
      debugPrint('HapticService: boostSwell failed: $e');
    }
  }

  /// The boost **climax** — the sharp, categorically-different stamp the instant
  /// the meter hits 100% (ignite): a firm full-amplitude hit + a second "locked
  /// in" stamp, so the buildup resolves into an *event* (research: the climax
  /// must feel distinct from the rise). Heavy-impact fallback without a vibrator.
  Future<void> boostClimax() async {
    if (!enabled) return;
    try {
      if (await _ensureVibrator()) {
        if (await _ensureAmplitudeControl()) {
          await Vibration.vibrate(
            pattern: const [0, 70, 40, 55],
            intensities: const [255, 210],
          );
        } else {
          await Vibration.vibrate(pattern: const [0, 70, 40, 55]);
        }
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('HapticService: boostClimax failed: $e');
    }
  }

  /// Whether the vibrator accepts custom waveform patterns — resolved once,
  /// lazily, like [_hasAmplitude]. A vibrator without it would silently drop
  /// (or throw on) `Vibration.vibrate(pattern:)`, so [bitPurr] degrades to the
  /// plain selection tick there instead (Codex F5).
  static bool? _hasCustomVibration;

  Future<bool> _ensureCustomVibration() async {
    final cached = _hasCustomVibration;
    if (cached != null) return cached;
    try {
      return _hasCustomVibration =
          (await Vibration.hasCustomVibrationsSupport()) == true;
    } catch (_) {
      return _hasCustomVibration = false;
    }
  }

  /// Minimum spacing between two purrs — slightly over the envelope length so
  /// a rapid re-tap can never cancel-restart the motor mid-envelope (restarts
  /// stutter; see [boostSwell]'s doc). Purely time-based via [nowProvider].
  static const Duration purrWindow = Duration(milliseconds: 300);

  DateTime? _purrStartedAt;

  /// BIT's press **purr** — the tactile twin of his cheer orbit: one soft,
  /// gap-free ~280ms rise-and-fall envelope (peak amplitude well under the
  /// reward tier — a creature response, not an event). Devices without
  /// amplitude control get a designed soft double-pulse ("b-brr"), NEVER a
  /// flat sustained buzz (the no-drone doctrine); devices without a raw
  /// vibrator or without waveform support fall back to the plain selection
  /// tick. Fires under reduced motion (action-tied haptic; haptics carry
  /// their own Settings toggle).
  ///
  /// Returns whether a purr was issued — a call inside [purrWindow] of the
  /// previous one is dropped (never restart the motor mid-envelope).
  Future<bool> bitPurr() async {
    if (!enabled) return false;
    final now = nowProvider();
    final started = _purrStartedAt;
    if (started != null && now.difference(started) < purrWindow) return false;
    _purrStartedAt = now;
    try {
      if (!await _ensureVibrator() || !await _ensureCustomVibration()) {
        // No raw vibrator, or one that can't take waveform patterns — still
        // one tactile response, still not a drone (Codex F5).
        await HapticFeedback.selectionClick();
        return true;
      }
      if (await _ensureAmplitudeControl()) {
        // Gap-free segments (pattern[i] paired with intensities[i]): a soft
        // rise to a low peak, decaying out — 280ms total.
        await Vibration.vibrate(
          pattern: const [0, 60, 60, 60, 60, 40],
          intensities: const [0, 50, 105, 80, 45, 20],
        );
      } else {
        // No amplitude control: two tiny pulses 60ms apart — reads as a soft
        // "b-brr", categorically not a drone.
        await Vibration.vibrate(pattern: const [0, 25, 60, 30]);
      }
    } catch (e) {
      debugPrint('HapticService: bitPurr failed: $e');
      // A throwing pattern path still owes ONE tactile response (Codex F5).
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {
        // best effort
      }
    }
    return true;
  }

  /// Fire the haptic for a semantic [intent]. The dispatch seam shared widgets
  /// (e.g. `PixelButton`) call so a single `HapticIntent` value drives the feel;
  /// [HapticIntent.none] is a no-op opt-out.
  Future<void> fire(HapticIntent intent) {
    switch (intent) {
      case HapticIntent.none:
        return Future<void>.value();
      case HapticIntent.selection:
        return selection();
      case HapticIntent.tap:
        return tap();
      case HapticIntent.success:
        return success();
      case HapticIntent.reward:
        return reward();
      case HapticIntent.warning:
        return warning();
    }
  }

  /// Minimum gap between two *coalesced* haptics — the broad, low-priority
  /// wrapper layer (chips, rows, card taps). A repeat inside this window is
  /// dropped so rapid tapping / scroll-tapping can't machine-gun the motor
  /// (Android's haptics principles: overuse → users disable *all* haptics).
  ///
  /// Only [fireCoalesced] honors this. The direct semantic calls
  /// (`fire`/`selection`/`success`/`reward`/`warning`) are **never** coalesced —
  /// a confirm, a reward, or a destructive buzz must always land on time.
  static Duration coalesceWindow = const Duration(milliseconds: 30);

  /// Injectable clock for the coalesce gate so tests can advance time
  /// deterministically (mirrors the app's `nowProvider` pattern).
  static DateTime Function() nowProvider = DateTime.now;

  DateTime? _lastCoalescedAt;

  /// Fire [intent], but drop it if another *coalesced* haptic fired less than
  /// [coalesceWindow] ago. The shared tap wrappers
  /// (`PhosphorTap`/`HoldDepress`/`ArcadeTap`/`ArcadeChip`) route their broad
  /// opt-in layer through here so the generous coverage stays a *tick*, never a
  /// buzz. [HapticIntent.none] is a no-op (the default = silent wrapper).
  Future<void> fireCoalesced(HapticIntent intent) {
    if (intent == HapticIntent.none) return Future<void>.value();
    final now = nowProvider();
    final last = _lastCoalescedAt;
    if (last != null && now.difference(last) < coalesceWindow) {
      return Future<void>.value();
    }
    _lastCoalescedAt = now;
    return fire(intent);
  }

  Future<void> _fire(Future<void> Function() effect) async {
    if (!enabled) return;
    try {
      await effect();
    } catch (e) {
      // Non-essential: never surface haptic failure to the caller, but log it
      // so it isn't silently invisible during development.
      debugPrint('HapticService: haptic failed: $e');
    }
  }
}
