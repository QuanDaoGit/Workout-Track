import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battle_animation_state.dart';

/// A single battle sprite rendered as a colored rectangle with pixel border.
/// Manages all animation states internally via Timer.periodic + setState.
class BattleSprite extends StatefulWidget {
  const BattleSprite({
    super.key,
    required this.width,
    required this.height,
    required this.color,
    required this.state,
    required this.isPlayer,
    this.isBoss = false,
    this.abilityId,
    this.abilityColor,
    this.hitFlashColor,
  });

  final double width;
  final double height;
  final Color color;
  final SpriteAnimState state;
  final bool isPlayer;
  final bool isBoss;
  final String? abilityId;
  final Color? abilityColor;
  final Color? hitFlashColor;

  @override
  State<BattleSprite> createState() => _BattleSpriteState();
}

class _BattleSpriteState extends State<BattleSprite> {
  Timer? _animTimer;
  Timer? _bobTimer;
  Timer? _abilityTimer;

  // Animation state
  double _bobOffset = 0;
  double _lungeOffset = 0;
  double _wobbleOffset = 0;
  bool _flashWhite = false;
  double _opacity = 1.0;
  double _rotation = 0;
  bool _bobUp = true;
  bool _showAbility = false;

  @override
  void initState() {
    super.initState();
    _startIdleBob();
    _applyState(widget.state);
  }

  @override
  void didUpdateWidget(BattleSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _animTimer?.cancel();
      _applyState(widget.state);
    }
    if (widget.abilityId != oldWidget.abilityId && widget.abilityId != null) {
      _showAbilityIcon();
    }
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _bobTimer?.cancel();
    _abilityTimer?.cancel();
    super.dispose();
  }

  void _startIdleBob() {
    _bobTimer?.cancel();
    _bobTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      setState(() {
        _bobUp = !_bobUp;
        _bobOffset = _bobUp ? -4 : 4;
      });
    });
  }

  void _applyState(SpriteAnimState state) {
    switch (state) {
      case SpriteAnimState.idle:
        _resetTransforms();

      case SpriteAnimState.attacking:
        _runAttack();

      case SpriteAnimState.hurt:
        _runHurt();

      case SpriteAnimState.dodging:
        _runDodge();

      case SpriteAnimState.victory:
        _runVictory();

      case SpriteAnimState.defeat:
        _runDefeat();
    }
  }

  void _resetTransforms() {
    setState(() {
      _lungeOffset = 0;
      _wobbleOffset = 0;
      _flashWhite = false;
      _opacity = 1.0;
      _rotation = 0;
    });
  }

  void _runAttack() {
    // Snap toward opponent for 400ms, then snap back.
    final direction = widget.isPlayer ? 1.0 : -1.0;
    setState(() => _lungeOffset = 30 * direction);

    _animTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _lungeOffset = 0);
    });
  }

  void _runHurt() {
    // Flash white 2× (150ms on/off each = 4 toggles total).
    var ticks = 0;
    setState(() => _flashWhite = true);
    _animTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      ticks++;
      if (!mounted) {
        t.cancel();
        return;
      }
      if (ticks >= 4) {
        t.cancel();
        setState(() => _flashWhite = false);
        return;
      }
      setState(() => _flashWhite = !_flashWhite);
    });
  }

  void _runDodge() {
    // Wobble X ±6px 2× at 100ms intervals.
    const offsets = [6.0, -6.0, 6.0, -6.0, 0.0];
    var index = 0;
    setState(() => _wobbleOffset = offsets[0]);
    _animTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      index++;
      if (!mounted) {
        t.cancel();
        return;
      }
      if (index >= offsets.length) {
        t.cancel();
        setState(() => _wobbleOffset = 0);
        return;
      }
      setState(() => _wobbleOffset = offsets[index]);
    });
  }

  void _runVictory() {
    if (widget.isPlayer) {
      // Move right in 3 steps.
      var step = 0;
      _animTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        step++;
        if (!mounted) {
          t.cancel();
          return;
        }
        if (step > 3) {
          t.cancel();
          return;
        }
        setState(() => _lungeOffset = step * 15.0);
      });
    } else {
      // Enemy victory: just hold idle.
      _resetTransforms();
    }
  }

  void _runDefeat() {
    if (widget.isPlayer) {
      // Fall flat (rotate 90°).
      _bobTimer?.cancel();
      setState(() {
        _bobOffset = 0;
        _rotation = math.pi / 2;
      });
    } else {
      // Fade out.
      _bobTimer?.cancel();
      var step = 0;
      _animTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        step++;
        if (!mounted) {
          t.cancel();
          return;
        }
        if (step > 3) {
          t.cancel();
          return;
        }
        setState(() => _opacity = 1.0 - (step * 0.33).clamp(0.0, 1.0));
      });
    }
  }

  void _showAbilityIcon() {
    setState(() => _showAbility = true);
    _abilityTimer?.cancel();
    _abilityTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _showAbility = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.isBoss ? 1.3 : 1.0;
    final w = widget.width * scale;
    final h = widget.height * scale;
    final borderWidth = widget.isBoss ? 2.0 : 1.0;

    final flashColor = widget.hitFlashColor ?? Colors.white;
    final fillColor =
        _flashWhite ? Colors.white : widget.color.withValues(alpha: 0.3);
    final borderColor = _flashWhite ? flashColor : widget.color;

    return SizedBox(
      width: w + 60, // extra space for lunge movement
      height: h + 44, // extra space for ability icon above
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ability icon above sprite
          if (_showAbility && widget.abilityId != null)
            Positioned(
              top: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (widget.abilityColor ?? widget.color)
                      .withValues(alpha: 0.3),
                  border: Border.all(
                    color: widget.abilityColor ?? widget.color,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.abilityId!,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: widget.abilityColor ?? widget.color,
                  ),
                ),
              ),
            ),
          // Sprite body
          Positioned(
            top: 40,
            child: Transform.translate(
              offset: Offset(_lungeOffset + _wobbleOffset, _bobOffset),
              child: Transform.rotate(
                angle: _rotation,
                child: Opacity(
                  opacity: _opacity,
                  child: Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      color: fillColor,
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
