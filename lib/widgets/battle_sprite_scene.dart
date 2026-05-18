import 'dart:async';

import 'package:flutter/material.dart';

import '../models/battle_animation_state.dart';
import '../services/battle_engine.dart';
import '../theme/tokens.dart';
import 'battle_sprite.dart';
import 'screen_shake.dart';
import 'segmented_progress_bar.dart';
import 'strobe_flash.dart';

/// Sprite dimensions and colors for each enemy archetype.
class _EnemySpriteConfig {
  const _EnemySpriteConfig(this.width, this.height, this.color);
  final double width;
  final double height;
  final Color color;
}

const _enemyConfigs = <String, _EnemySpriteConfig>{
  'shadow_rat': _EnemySpriteConfig(30, 40, Color(0xFF9B59B6)),
  'iron_golem': _EnemySpriteConfig(50, 60, Color(0xFF8A8A8A)),
  'wraith_knight': _EnemySpriteConfig(45, 60, Color(0xFFFF2D55)),
};

const _fallbackConfig = _EnemySpriteConfig(40, 50, Color(0xFF8A8A8A));

/// The 2D animated battle sprite scene. Receives events from the parent
/// via trigger-counter pattern and drives sprite animations.
class BattleSpriteScene extends StatefulWidget {
  const BattleSpriteScene({
    super.key,
    required this.result,
    required this.lastEvent,
    required this.eventTrigger,
    required this.playerHp,
    required this.playerHpMax,
    required this.enemyHp,
    required this.enemyHpMax,
    required this.finished,
  });

  final BattleResult result;
  final BattleEvent? lastEvent;
  final int eventTrigger;
  final int playerHp;
  final int playerHpMax;
  final int enemyHp;
  final int enemyHpMax;
  final bool finished;

  @override
  State<BattleSpriteScene> createState() => _BattleSpriteSceneState();
}

class _BattleSpriteSceneState extends State<BattleSpriteScene> {
  SpriteAnimState _playerState = SpriteAnimState.idle;
  SpriteAnimState _enemyState = SpriteAnimState.idle;
  String? _playerAbilityId;
  String? _enemyAbilityId;
  Color? _playerHitFlashColor;
  Color? _enemyHitFlashColor;
  Color? _abilityColor;
  int _critStrobeTrigger = 0;
  int _abilityShakeTrigger = 0;
  Timer? _resetTimer;

  @override
  void didUpdateWidget(BattleSpriteScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventTrigger != oldWidget.eventTrigger &&
        widget.lastEvent != null) {
      _handleEvent(widget.lastEvent!);
    }
    if (widget.finished && !oldWidget.finished) {
      _applyTerminalState();
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleEvent(BattleEvent event) {
    _resetTimer?.cancel();
    _playerAbilityId = null;
    _enemyAbilityId = null;
    _playerHitFlashColor = null;
    _enemyHitFlashColor = null;

    switch (event.type) {
      case BattleEventType.playerAttack:
        setState(() {
          _playerState = SpriteAnimState.attacking;
          _enemyState = SpriteAnimState.hurt;
        });
        _scheduleReset(700);

      case BattleEventType.playerCrit:
        setState(() {
          _playerState = SpriteAnimState.attacking;
          _enemyState = SpriteAnimState.hurt;
          _critStrobeTrigger++;
        });
        _scheduleReset(700);

      case BattleEventType.playerDodge:
        setState(() {
          _playerState = SpriteAnimState.dodging;
          _enemyState = SpriteAnimState.idle;
        });
        _scheduleReset(400);

      case BattleEventType.enemyAttack:
        setState(() {
          _playerState = SpriteAnimState.hurt;
          _enemyState = SpriteAnimState.attacking;
        });
        _scheduleReset(700);

      case BattleEventType.enemyDodge:
        setState(() {
          _playerState = SpriteAnimState.idle;
          _enemyState = SpriteAnimState.dodging;
        });
        _scheduleReset(400);

      case BattleEventType.abilityTrigger:
        _handleAbility(event.message);

      case BattleEventType.playerHpChange:
      case BattleEventType.enemyHpChange:
        // HP changes are reflected via parent's playerHp/enemyHp props.
        break;
    }
  }

  void _handleAbility(String message) {
    String? id;
    Color? color;

    if (message.contains('SHADOW STRIKE')) {
      id = 'SS';
      color = const Color(0xFF4DE5FF);
    } else if (message.contains('PHANTOM EDGE')) {
      id = 'PE';
      color = const Color(0xFF4DE5FF);
    } else if (message.contains('OVERPOWER')) {
      id = 'OP';
      color = const Color(0xFFFFD700);
    } else if (message.contains('IRON TIDE')) {
      id = 'IT';
      color = const Color(0xFFFFD700);
    } else if (message.contains('IRON WILL')) {
      id = 'IW';
      color = const Color(0xFFFF2D55);
    } else if (message.contains('LAST STAND')) {
      id = 'LS';
      color = const Color(0xFFFF2D55);
    }

    if (id == null) return;

    setState(() {
      _abilityShakeTrigger++;
      _abilityColor = color;
      _playerAbilityId = id;
      _playerHitFlashColor = color;
    });
  }

  void _scheduleReset(int ms) {
    _resetTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      if (!widget.finished) {
        setState(() {
          _playerState = SpriteAnimState.idle;
          _enemyState = SpriteAnimState.idle;
        });
      }
    });
  }

  void _applyTerminalState() {
    _resetTimer?.cancel();
    setState(() {
      if (widget.result.playerWon) {
        _playerState = SpriteAnimState.victory;
        _enemyState = SpriteAnimState.defeat;
      } else if (widget.result.isDraw) {
        _playerState = SpriteAnimState.idle;
        _enemyState = SpriteAnimState.idle;
      } else {
        _playerState = SpriteAnimState.defeat;
        _enemyState = SpriteAnimState.victory;
      }
    });
  }

  int _litCells(int hp, int maxHp) {
    if (maxHp <= 0) return 0;
    return ((hp / maxHp) * 8).ceil().clamp(0, 8);
  }

  @override
  Widget build(BuildContext context) {
    // Determine enemy config from archetype id.
    final baseId = _baseEnemyId(widget.result.enemy.id);
    final config = _enemyConfigs[baseId] ?? _fallbackConfig;
    final isBoss = widget.result.enemy.name.startsWith('BOSS:');
    final enemyColor = config.color;

    return ScreenShake(
      trigger: _abilityShakeTrigger,
      magnitude: 3,
      frames: 5,
      child: StrobeFlash(
        trigger: _critStrobeTrigger,
        color: kAmber,
        opacity: 0.25,
        child: Container(
          height: double.infinity,
          color: kBg,
          child: Row(
            children: [
              // Player side
              Expanded(
                child: _buildSpriteColumn(
                  state: _playerState,
                  isPlayer: true,
                  width: 40,
                  height: 60,
                  color: kNeon,
                  isBoss: false,
                  abilityId: _playerAbilityId,
                  abilityColor: _abilityColor,
                  hitFlashColor: _playerHitFlashColor,
                  hp: widget.playerHp,
                  hpMax: widget.playerHpMax,
                  hpColor: kNeon,
                ),
              ),
              // Enemy side
              Expanded(
                child: _buildSpriteColumn(
                  state: _enemyState,
                  isPlayer: false,
                  width: config.width,
                  height: config.height,
                  color: enemyColor,
                  isBoss: isBoss,
                  abilityId: _enemyAbilityId,
                  abilityColor: _abilityColor,
                  hitFlashColor: _enemyHitFlashColor,
                  hp: widget.enemyHp,
                  hpMax: widget.enemyHpMax,
                  hpColor: enemyColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpriteColumn({
    required SpriteAnimState state,
    required bool isPlayer,
    required double width,
    required double height,
    required Color color,
    required bool isBoss,
    required String? abilityId,
    required Color? abilityColor,
    required Color? hitFlashColor,
    required int hp,
    required int hpMax,
    required Color hpColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BattleSprite(
          width: width,
          height: height,
          color: color,
          state: state,
          isPlayer: isPlayer,
          isBoss: isBoss,
          abilityId: abilityId,
          abilityColor: abilityColor,
          hitFlashColor: hitFlashColor,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: SegmentedProgressBar(
            totalCells: 8,
            litCells: _litCells(hp, hpMax),
            height: 4,
            gap: 1,
            litColor: hpColor,
            litBorderColor: hpColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Strips floor-specific naming to get the base archetype id.
  String _baseEnemyId(String id) {
    // Enemy ids are one of: shadow_rat, iron_golem, wraith_knight
    if (id.contains('shadow_rat')) return 'shadow_rat';
    if (id.contains('iron_golem')) return 'iron_golem';
    if (id.contains('wraith_knight')) return 'wraith_knight';
    return id;
  }
}
