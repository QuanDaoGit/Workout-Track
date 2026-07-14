import 'package:flutter/material.dart';

import '../../services/haptic_service.dart';
import '../../theme/tokens.dart';

class HoldDepress extends StatefulWidget {
  const HoldDepress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(kCardRadius)),
    this.behavior = HitTestBehavior.opaque,
    this.haptic = HapticIntent.none,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final BorderRadius borderRadius;
  final HitTestBehavior behavior;

  /// Opt-in tactile tick on a committed tap, via the rate-limited
  /// [HapticService.fireCoalesced]. Defaults to silent ([HapticIntent.none]).
  final HapticIntent haptic;

  @override
  State<HoldDepress> createState() => _HoldDepressState();
}

class _HoldDepressState extends State<HoldDepress> {
  bool _pressed = false;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  void _release() {
    if (!_pressed) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final translate = !_reduceMotion && _pressed ? 2.0 : 0.0;
    final opacity = _pressed ? 0.92 : 1.0;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => _release() : null,
      onTapCancel: widget.enabled ? _release : null,
      onTap: widget.enabled && widget.onTap != null
          ? () {
              HapticService.instance.fireCoalesced(widget.haptic);
              widget.onTap!();
            }
          : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: Duration.zero,
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Transform.translate(
            offset: Offset(0, translate),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
