import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../services/sfx_service.dart';
import '../services/ui_sound.dart';

/// Fire the shared button feedback (haptic + intent-mapped kit sound) for a
/// committed press. The one seam `ArcadeFilled`/`ArcadeTextButton`/
/// `ArcadeIconButton` and any bespoke button share, mirroring `PixelButton`'s
/// map: every committing press ticks (SFX v2 — a silent press reads as a dead
/// key), warning buzzes, `none` = the handler owns the beat.
void fireButtonFeedback(HapticIntent haptic, {bool sound = true}) {
  HapticService.instance.fire(haptic);
  if (!sound) return;
  switch (haptic) {
    case HapticIntent.tap:
    case HapticIntent.selection:
    case HapticIntent.success:
    case HapticIntent.reward:
      SfxService.instance.playUi(UiSound.tick);
    case HapticIntent.warning:
      SfxService.instance.playUi(UiSound.warn);
    case HapticIntent.none:
      break;
  }
}

/// Drop-in [FilledButton] with the app's button feedback wired at commit time
/// (SFX v2 — the raw Material buttons were the silent-bypass class that made
/// the soundscape feel "a little here a little there"). Same constructor
/// surface as the in-repo FilledButton usage; visuals untouched (the theme
/// styles it). `test/tap_haptic_coverage_test.dart` bans bare FilledButtons
/// outside this wrapper.
class ArcadeFilled extends StatelessWidget {
  const ArcadeFilled({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.haptic = HapticIntent.tap,
    this.sound = true,
    this.icon,
  });

  /// `FilledButton.icon` form.
  const ArcadeFilled.icon({
    super.key,
    required this.onPressed,
    required Widget label,
    required Widget this.icon,
    this.style,
    this.haptic = HapticIntent.tap,
    this.sound = true,
  }) : child = label;

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  /// Semantic press intent: `tap` (default), `warning` for destructive
  /// commits, `none` when the handler owns its own beat.
  final HapticIntent haptic;

  /// false → haptic only (a handler-owned audio moment; avoids stacking).
  final bool sound;

  final Widget? icon;

  VoidCallback? get _wrapped => onPressed == null
      ? null
      : () {
          fireButtonFeedback(haptic, sound: sound);
          onPressed!();
        };

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      // button-ok: this IS the sanctioned wrapper
      return FilledButton.icon(
        onPressed: _wrapped,
        style: style,
        icon: icon!,
        label: child,
      );
    }
    // button-ok: this IS the sanctioned wrapper
    return FilledButton(onPressed: _wrapped, style: style, child: child);
  }
}

/// Drop-in [TextButton] with the same commit-time feedback.
class ArcadeTextButton extends StatelessWidget {
  const ArcadeTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.haptic = HapticIntent.tap,
    this.sound = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final HapticIntent haptic;
  final bool sound;

  @override
  Widget build(BuildContext context) {
    // button-ok: this IS the sanctioned wrapper
    return TextButton(
      onPressed: onPressed == null
          ? null
          : () {
              fireButtonFeedback(haptic, sound: sound);
              onPressed!();
            },
      style: style,
      child: child,
    );
  }
}

/// Drop-in [IconButton] with the same commit-time feedback.
class ArcadeIconButton extends StatelessWidget {
  const ArcadeIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.padding,
    this.constraints,
    this.style,
    this.haptic = HapticIntent.tap,
    this.sound = true,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final ButtonStyle? style;
  final HapticIntent haptic;
  final bool sound;

  @override
  Widget build(BuildContext context) {
    // button-ok: this IS the sanctioned wrapper
    return IconButton(
      onPressed: onPressed == null
          ? null
          : () {
              fireButtonFeedback(haptic, sound: sound);
              onPressed!();
            },
      tooltip: tooltip,
      padding: padding,
      constraints: constraints,
      style: style,
      icon: icon,
    );
  }
}
