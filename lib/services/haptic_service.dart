import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
