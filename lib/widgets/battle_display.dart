import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/loot_item.dart';
import '../services/battle_engine.dart';
import '../services/loot_service.dart';
import '../theme/tokens.dart';
import 'pixel_button.dart';
import 'screen_shake.dart';
import 'segmented_progress_bar.dart';
import 'strobe_flash.dart';

/// Full-screen battle playback page. Receives a [BattleResult] and plays it
/// back as a text log with arcade effects. Tap anywhere to skip to the end.
class BattleDisplay extends StatefulWidget {
  const BattleDisplay({
    super.key,
    required this.result,
    required this.onComplete,
    this.instantReplay = false,
  });

  final BattleResult result;

  /// Called when the user taps the result button (victory/defeat/draw).
  final VoidCallback onComplete;

  /// If true, skips to the end state immediately (for replays).
  final bool instantReplay;

  @override
  State<BattleDisplay> createState() => _BattleDisplayState();
}

class _BattleDisplayState extends State<BattleDisplay> {
  final List<_LogLine> _visibleLines = [];
  final ScrollController _scrollController = ScrollController();
  int _playerHp = 0;
  int _enemyHp = 0;
  bool _finished = false;
  bool _skipped = false;
  Timer? _playbackTimer;
  int _shakeTrigger = 0;
  int _strobeTrigger = 0;
  Color _playerAttackColor = kNeon;

  // Playback cursor
  int _roundIndex = 0;
  int _eventIndex = 0;

  @override
  void initState() {
    super.initState();
    _playerHp = widget.result.playerHpMax;
    _enemyHp = widget.result.enemyHpMax;
    if (widget.instantReplay) {
      _skipToEnd();
    } else {
      _scheduleNextEvent();
    }
    _loadBattleEffect();
  }

  Future<void> _loadBattleEffect() async {
    final effect = await LootService().getEquippedItem(
      LootCategory.battleEffect,
    );
    if (!mounted || effect?.colorValue == null) return;
    setState(() => _playerAttackColor = Color(effect!.colorValue!));
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleNextEvent() {
    if (_finished || _skipped) return;
    final rounds = widget.result.rounds;
    if (_roundIndex >= rounds.length) {
      _finish();
      return;
    }

    final round = rounds[_roundIndex];
    if (_eventIndex >= round.events.length) {
      // Move to next round with a pause.
      _roundIndex++;
      _eventIndex = 0;
      _playbackTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        _scheduleNextEvent();
      });
      return;
    }

    final event = round.events[_eventIndex];
    _eventIndex++;

    // Pause between events.
    _playbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _skipped) return;
      _applyEvent(event);
      _scheduleNextEvent();
    });
  }

  void _applyEvent(BattleEvent event) {
    setState(() {
      _visibleLines.add(_LogLine(event: event));

      switch (event.type) {
        case BattleEventType.enemyHpChange:
          _enemyHp = event.value;
        case BattleEventType.playerHpChange:
          _playerHp = event.value;
        case BattleEventType.enemyAttack:
          _shakeTrigger++;
        case BattleEventType.playerCrit:
          _strobeTrigger++;
        default:
          break;
      }
    });
    _scrollToBottom();
  }

  void _skipToEnd() {
    _playbackTimer?.cancel();
    setState(() {
      _skipped = true;
      _visibleLines.clear();
      for (final round in widget.result.rounds) {
        for (final event in round.events) {
          _visibleLines.add(_LogLine(event: event, instant: true));
        }
      }
      _playerHp = widget.result.playerHpRemaining;
      _enemyHp = widget.result.enemyHpRemaining;
      _finished = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _finish() {
    setState(() => _finished = true);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  // ── HP bar cells ────────────────────────────────────────────────────────────

  static const _hpBarCells = 20;

  int _litCells(int hp, int maxHp) {
    if (maxHp <= 0) return 0;
    return ((hp / maxHp) * _hpBarCells).ceil().clamp(0, _hpBarCells);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (!_finished && !_skipped) ? _skipToEnd : null,
      child: Scaffold(
        body: SafeArea(
          child: ScreenShake(
            trigger: _shakeTrigger,
            magnitude: result.playerWon ? 2 : 4,
            frames: result.playerWon ? 4 : 6,
            child: Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: kSpace4),
                  _buildCombatants(),
                  const SizedBox(height: kSpace4),
                  const Divider(color: kBorder, height: 1),
                  const SizedBox(height: kSpace3),
                  Expanded(child: _buildLog()),
                  const SizedBox(height: kSpace3),
                  const Divider(color: kBorder, height: 1),
                  const SizedBox(height: kSpace3),
                  if (_finished) _buildResultButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const ImageIcon(
          AssetImage('assets/icons/control/icon_sword.png'),
          size: 16,
          color: kAmber,
        ),
        const SizedBox(width: kSpace2),
        Text(
          'FLOOR ${widget.result.floor} — BATTLE',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kAmber,
          ),
        ),
      ],
    );
  }

  Widget _buildCombatants() {
    final result = widget.result;

    return Column(
      children: [
        // Enemy
        _buildCombatantRow(
          name: result.enemy.name,
          level: result.floor,
          hp: _enemyHp,
          hpMax: result.enemyHpMax,
          color: kDanger,
          isEnemy: true,
        ),
        const SizedBox(height: kSpace3),
        StrobeFlash(
          trigger: _strobeTrigger,
          color: kAmber,
          opacity: 0.3,
          child: Text(
            '⚔ VS ⚔',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kAmber.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: kSpace3),
        // Player
        _buildCombatantRow(
          name: 'YOU',
          level: null,
          hp: _playerHp,
          hpMax: result.playerHpMax,
          color: kNeon,
          isEnemy: false,
        ),
      ],
    );
  }

  Widget _buildCombatantRow({
    required String name,
    required int? level,
    required int hp,
    required int hpMax,
    required Color color,
    required bool isEnemy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: color,
                ),
              ),
            ),
            if (level != null)
              Text(
                'Lv.$level',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        const SizedBox(height: kSpace1),
        Row(
          children: [
            Text(
              'HP',
              style: GoogleFonts.shareTechMono(
                fontSize: 11,
                color: color.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: kSpace2),
            Expanded(
              child: SegmentedProgressBar(
                totalCells: _hpBarCells,
                litCells: _litCells(hp, hpMax),
                litColor: color,
                litBorderColor: color.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: kSpace2),
            Text(
              '$hp/$hpMax',
              style: GoogleFonts.shareTechMono(fontSize: 11, color: color),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLog() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _visibleLines.length,
      itemBuilder: (context, index) {
        final line = _visibleLines[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildLogLine(line),
        );
      },
    );
  }

  Widget _buildLogLine(_LogLine line) {
    final event = line.event;
    final color = _colorForEvent(event.type);
    final text = '▶ ${event.message}';

    // Skip typewriter for HP change lines and instant replay.
    if (line.instant ||
        event.type == BattleEventType.enemyHpChange ||
        event.type == BattleEventType.playerHpChange) {
      return Text(
        text,
        style: GoogleFonts.shareTechMono(fontSize: 14, color: color),
      );
    }

    // Wrap crit lines in strobe.
    if (event.type == BattleEventType.playerCrit) {
      return StrobeFlash(
        trigger: line,
        fireOnMount: true,
        color: kAmber,
        opacity: 0.2,
        child: Text(
          text,
          style: GoogleFonts.shareTechMono(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (event.type == BattleEventType.playerAttack) {
      return StrobeFlash(
        trigger: line,
        fireOnMount: true,
        color: _playerAttackColor,
        opacity: 0.12,
        child: Text(
          text,
          style: GoogleFonts.shareTechMono(fontSize: 14, color: color),
        ),
      );
    }

    return Text(
      text,
      style: GoogleFonts.shareTechMono(fontSize: 14, color: color),
    );
  }

  Color _colorForEvent(BattleEventType type) {
    return switch (type) {
      BattleEventType.playerAttack => _playerAttackColor,
      BattleEventType.playerCrit => kAmber,
      BattleEventType.playerDodge => kCyan,
      BattleEventType.enemyAttack => kDanger,
      BattleEventType.enemyDodge => kMutedText,
      BattleEventType.playerHpChange => kMutedText,
      BattleEventType.enemyHpChange => kMutedText,
      BattleEventType.abilityTrigger => kAmber,
    };
  }

  Widget _buildResultButton() {
    final result = widget.result;
    if (widget.instantReplay) {
      return PixelButton(
        label: 'BACK',
        color: kNeon,
        onPressed: widget.onComplete,
      );
    }

    if (result.playerWon) {
      return PixelButton(
        label: 'CLAIM VICTORY',
        color: kNeon,
        onPressed: widget.onComplete,
      );
    }
    if (result.isDraw) {
      return PixelButton(
        label: 'STALEMATE',
        color: kMutedText,
        onPressed: widget.onComplete,
      );
    }
    // Loss
    return PixelButton(
      label: 'TRAIN HARDER',
      color: kDanger,
      onPressed: widget.onComplete,
    );
  }
}

class _LogLine {
  _LogLine({required this.event, this.instant = false});

  final BattleEvent event;
  final bool instant;
}
