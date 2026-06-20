import 'dart:async';

import 'package:flutter/material.dart';

import '../models/avatar_spec.dart';
import '../theme/tokens.dart';
import 'avatar/ironbit_avatar.dart';

/// The standard square identity tile: the pixel-face avatar seated in a frame's
/// transparent aperture, with the equipped loot frame drawn over it.
///
/// The frame PNG is the **only** border — there is no separate bordered box
/// (an inner box used to bleed through the frame's transparent center). Frames
/// are authored to a 26-cell grid: a central 20×20 transparent aperture (the
/// avatar fills exactly [_apertureRatio] of the tile so its pixel cell matches
/// the frame's) plus a 3-cell border ring. Render at integer scale only
/// (`FilterQuality.none`) — a non-integer stretch shatters the pixel grid.
///
/// Animated frames (`frameCount > 1`, e.g. the epic inferno/void) cycle their
/// `<id>_<i>.png` frames when [animate] is set; reduced motion freezes them on
/// the poster (frame 0), reconciled live in [didChangeDependencies].
class LootAvatarFrame extends StatefulWidget {
  final AvatarSpec avatarSpec;

  /// The equipped frame's poster path (`…/<id>.png` or `…/<id>_0.png`).
  /// Null/empty renders no overlay (just the avatar on its backdrop).
  final String? framePath;

  /// Animation frame count (1 = static). Frame i lives at the poster path with
  /// its trailing `_0.png` swapped to `_<i>.png`.
  final int frameCount;

  /// Whether to animate a multi-frame frame on this surface (still honors
  /// reduced motion). Grids/thumbnails pass false to stay on the poster.
  final bool animate;

  final double size;
  final Color? glowColor;
  final double glowOpacity;

  /// Optical-centring nudge: the 20×20 sprite carries more empty rows below the
  /// chin than above the hair, so a box-centred avatar reads slightly high.
  /// Shift it down by this many logical px (default 0 = unchanged).
  final double avatarDropPx;

  const LootAvatarFrame({
    super.key,
    required this.avatarSpec,
    this.framePath,
    this.frameCount = 1,
    this.animate = false,
    required this.size,
    this.glowColor,
    this.glowOpacity = 0.22,
    this.avatarDropPx = 0,
  });

  /// The avatar fills the central 20 of the 26-cell frame grid, so one avatar
  /// pixel equals one frame pixel.
  static const double _apertureRatio = 20 / 26;

  @override
  State<LootAvatarFrame> createState() => _LootAvatarFrameState();
}

class _LootAvatarFrameState extends State<LootAvatarFrame> {
  int _frame = 0;
  Timer? _timer;
  bool _reduceMotion = false;

  bool get _hasFrame => widget.framePath != null && widget.framePath!.isNotEmpty;
  bool get _isAnimated => widget.animate && widget.frameCount > 1 && _hasFrame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reduceMotion = media.disableAnimations || media.accessibleNavigation;
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant LootAvatarFrame old) {
    super.didUpdateWidget(old);
    if (old.framePath != widget.framePath ||
        old.frameCount != widget.frameCount ||
        old.animate != widget.animate) {
      _frame = 0;
      _syncTimer();
    }
  }

  void _syncTimer() {
    final shouldRun = _isAnimated && !_reduceMotion;
    if (shouldRun && _timer == null) {
      // ~12 fps: a 10-frame loop reads as a calm shimmer, not a strobe.
      _timer = Timer.periodic(const Duration(milliseconds: 83), (_) {
        if (!mounted) return;
        setState(() => _frame = (_frame + 1) % widget.frameCount);
      });
    } else if (!shouldRun && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _frame = 0; // freeze on the poster; a build always follows these callers
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _framePathForIndex(int i) {
    final path = widget.framePath!;
    if (widget.frameCount <= 1 || i == 0) return path;
    return path.replaceFirst(RegExp(r'_0\.png$'), '_$i.png');
  }

  @override
  Widget build(BuildContext context) {
    final tile = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dark backing behind the aperture; the frame ring paints over its
          // edges opaquely, so only the avatar window shows it.
          const ColoredBox(color: kBg),
          Center(
            child: Transform.translate(
              offset: Offset(0, widget.avatarDropPx),
              child: IronbitAvatar(
                spec: widget.avatarSpec,
                size: widget.size * LootAvatarFrame._apertureRatio,
              ),
            ),
          ),
          if (_hasFrame)
            Image.asset(
              _framePathForIndex(_frame),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              isAntiAlias: false,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
        ],
      ),
    );

    if (widget.glowColor == null) return tile;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: neonGlow(
          color: widget.glowColor!,
          opacity: widget.glowOpacity,
          blur: 22,
        ),
      ),
      child: tile,
    );
  }
}
