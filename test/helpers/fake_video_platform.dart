import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Minimal fake video platform for widget tests: completes initialization on
/// listen (so `VideoPlayerController.initialize()` resolves) and records
/// play/pause/loop calls in [log].
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _nextId = 1;
  final List<String> log = [];

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = _nextId++;
    _events[id] = StreamController<VideoEvent>();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _events[playerId]!;
    // Emit the init event only once the VideoPlayerController is listening,
    // mirroring how the plugin's own test fake avoids dropping it.
    controller.onListen = () => controller.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 4),
        size: const Size(480, 270),
      ),
    );
    return controller.stream;
  }

  @override
  Future<void> play(int playerId) async => log.add('play');

  @override
  Future<void> pause(int playerId) async => log.add('pause');

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      log.add('loop:$looping');

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      log.add('seek:${position.inMilliseconds}');

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> dispose(int playerId) async {
    _events[playerId]?.close();
  }

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);
}
