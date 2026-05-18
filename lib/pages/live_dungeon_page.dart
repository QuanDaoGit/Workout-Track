import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/idle_battle_models.dart';
import '../services/battle_engine.dart';
import '../services/idle_battle_service.dart';
import '../theme/tokens.dart';
import '../widgets/battle_sprite_scene.dart';

enum _DungeonPhase { waiting, battling, resultPause }

/// Full-screen live dungeon page with auto-advancing animated battles.
class LiveDungeonPage extends StatefulWidget {
  const LiveDungeonPage({super.key});

  @override
  State<LiveDungeonPage> createState() => _LiveDungeonPageState();
}

class _LiveDungeonPageState extends State<LiveDungeonPage> {
  final _service = IdleBattleService();
  StreamSubscription<IdleBattleUpdate>? _subscription;

  _DungeonPhase _phase = _DungeonPhase.waiting;
  int _currentFloor = 1;
  BattleResult? _currentResult;

  // Playback state — mirrors BattleDisplay pattern.
  int _playerHp = 0;
  int _enemyHp = 0;
  int _playerHpMax = 0;
  int _enemyHpMax = 0;
  bool _playbackFinished = false;
  BattleEvent? _lastEvent;
  int _eventTrigger = 0;
  int _roundIndex = 0;
  int _eventIndex = 0;
  Timer? _playbackTimer;
  Timer? _pauseTimer;

  // Result display during pause.
  String? _resultText;
  Color _resultColor = kText;

  // Enemy fade-in.
  double _enemyOpacity = 0.0;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    _loadFloor();
    _subscription = _service.updates.listen(_onUpdate);
    _service.triggerImmediateBattle();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _playbackTimer?.cancel();
    _pauseTimer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFloor() async {
    final floor = await _service.getCurrentFloor();
    if (mounted) setState(() => _currentFloor = floor);
  }

  void _onUpdate(IdleBattleUpdate update) {
    if (!mounted) return;

    switch (update.type) {
      case IdleBattleUpdateType.battleStarting:
        setState(() {
          _currentFloor = update.currentFloor;
          _phase = _DungeonPhase.waiting;
          _resultText = null;
        });
        _startEnemyFadeIn();

      case IdleBattleUpdateType.battleComplete:
        final result = update.battleResult;
        if (result == null) return;
        setState(() {
          _currentFloor = update.currentFloor;
          _currentResult = result;
          _phase = _DungeonPhase.battling;
          _playerHp = result.playerHpMax;
          _enemyHp = result.enemyHpMax;
          _playerHpMax = result.playerHpMax;
          _enemyHpMax = result.enemyHpMax;
          _playbackFinished = false;
          _roundIndex = 0;
          _eventIndex = 0;
          _enemyOpacity = 1.0;
        });
        _scheduleNextEvent();
    }
  }

  // ── Enemy fade-in ──────────────────────────────────────────────────────────

  void _startEnemyFadeIn() {
    _fadeTimer?.cancel();
    _enemyOpacity = 0.0;
    var step = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      step++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _enemyOpacity = (step / 5).clamp(0.0, 1.0));
      if (step >= 5) timer.cancel();
    });
  }

  // ── Playback (adapted from BattleDisplay) ──────────────────────────────────

  void _scheduleNextEvent() {
    if (_playbackFinished || _currentResult == null) return;
    final rounds = _currentResult!.rounds;
    if (_roundIndex >= rounds.length) {
      _finishPlayback();
      return;
    }

    final round = rounds[_roundIndex];
    if (_eventIndex >= round.events.length) {
      _roundIndex++;
      _eventIndex = 0;
      _playbackTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) _scheduleNextEvent();
      });
      return;
    }

    final event = round.events[_eventIndex];
    _eventIndex++;

    _playbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _applyEvent(event);
      _scheduleNextEvent();
    });
  }

  void _applyEvent(BattleEvent event) {
    setState(() {
      switch (event.type) {
        case BattleEventType.enemyHpChange:
          _enemyHp = event.value;
        case BattleEventType.playerHpChange:
          _playerHp = event.value;
        default:
          break;
      }
      _lastEvent = event;
      _eventTrigger++;
    });
  }

  void _finishPlayback() {
    _playbackTimer?.cancel();
    final result = _currentResult!;
    final won = result.playerWon;
    final draw = result.isDraw;

    setState(() {
      _playbackFinished = true;
      _phase = _DungeonPhase.resultPause;
      _resultText = won
          ? 'VICTORY'
          : draw
              ? 'STALEMATE'
              : 'DEFEATED';
      _resultColor = won
          ? kNeon
          : draw
              ? kAmber
              : kDanger;
    });

    // 5-second pause, then trigger next battle.
    _pauseTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _service.triggerImmediateBattle();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          'DUNGEON',
          style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
        ),
        backgroundColor: kBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_sharp),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: kSpace3),
            // Floor counter
            Text(
              'FLOOR $_currentFloor',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: kMutedText,
              ),
            ),
            const SizedBox(height: kSpace3),
            // Battle scene
            SizedBox(
              height: 140,
              child: _currentResult != null
                  ? Opacity(
                      opacity: _enemyOpacity.clamp(0.0, 1.0),
                      child: BattleSpriteScene(
                        result: _currentResult!,
                        lastEvent: _lastEvent,
                        eventTrigger: _eventTrigger,
                        playerHp: _playerHp,
                        playerHpMax: _playerHpMax,
                        enemyHp: _enemyHp,
                        enemyHpMax: _enemyHpMax,
                        finished: _playbackFinished,
                      ),
                    )
                  : const Center(
                      child: Text(
                        'ENTERING DUNGEON...',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 8,
                          color: kMutedText,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: kSpace3),
            // Result text during pause
            if (_resultText != null)
              Text(
                _resultText!,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: _resultColor,
                ),
              ),
            if (_phase == _DungeonPhase.resultPause)
              Padding(
                padding: const EdgeInsets.only(top: kSpace2),
                child: Text(
                  'NEXT BATTLE SOON...',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    color: kMutedText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
