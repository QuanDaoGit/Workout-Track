import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/bit_room_copy.dart';
import 'package:workout_track/models/adventure_models.dart';

/// The room-voice selector is a pure function — its priority + index mapping are
/// the contract the home/room wiring depends on. Greeting once-only + rotation
/// live in HomePageState (lifecycle test); here we pin the selection.
void main() {
  BitRoomLine sel({
    required AdventurePhase phase,
    bool haulReady = false,
    bool greeted = false,
    int adviceIndex = 0,
    String? routeName,
    int? backInHours,
    int claimableCount = 0,
  }) => BitRoomVoice.select(
    phase: phase,
    haulReady: haulReady,
    greeted: greeted,
    adviceIndex: adviceIndex,
    routeName: routeName,
    backInHours: backInHours,
    claimableCount: claimableCount,
  );

  group('priority: haul > greeting > scouting > advice', () {
    test('a waiting haul wins over everything, even out + un-greeted', () {
      final l = sel(phase: AdventurePhase.out, haulReady: true, greeted: false);
      expect(l.kind, BitRoomVoiceKind.haul);
      expect(l.emphasis, 'loots');
      expect(l.tappableCollect, isTrue);
    });

    test('haul wins while idle too', () {
      expect(
        sel(phase: AdventurePhase.idle, haulReady: true).kind,
        BitRoomVoiceKind.haul,
      );
    });

    test('out + un-greeted → the one-shot greeting', () {
      final l = sel(phase: AdventurePhase.out, greeted: false);
      expect(l.kind, BitRoomVoiceKind.greeting);
      expect(l.text, "It's me again");
    });

    test('out + greeted → scouting status (carries route + hours)', () {
      final l = sel(
        phase: AdventurePhase.out,
        greeted: true,
        routeName: 'IRON VAULT',
        backInHours: 2,
      );
      expect(l.kind, BitRoomVoiceKind.scouting);
      expect(l.routeName, 'IRON VAULT');
      expect(l.backInHours, 2);
      expect(l.semanticsLabel, contains('2'));
    });

    test('idle → advice at the cursor; returned (no haul) also → advice', () {
      expect(sel(phase: AdventurePhase.idle).kind, BitRoomVoiceKind.advice);
      expect(sel(phase: AdventurePhase.returned).kind, BitRoomVoiceKind.advice);
    });
  });

  group('claimable reward: home nudge, below away/haul, above advice', () {
    test('home + idle + a reward ready → the claimable line (tappable)', () {
      final l = sel(phase: AdventurePhase.idle, claimableCount: 2);
      expect(l.kind, BitRoomVoiceKind.claimable);
      expect(l.text, '2 rewards ready to claim.');
      expect(l.tappable, isTrue);
      expect(l.semanticsLabel, contains('Tap to open quests'));
    });

    test('one reward → singular noun', () {
      expect(sel(phase: AdventurePhase.idle, claimableCount: 1).text,
          '1 reward ready to claim.');
    });

    test('a waiting haul still wins over a claimable reward', () {
      expect(
        sel(phase: AdventurePhase.idle, haulReady: true, claimableCount: 3).kind,
        BitRoomVoiceKind.haul,
      );
    });

    test('while away, the away status wins — the board carries the cue', () {
      expect(
        sel(phase: AdventurePhase.out, greeted: true, claimableCount: 3).kind,
        BitRoomVoiceKind.scouting,
      );
      expect(
        sel(phase: AdventurePhase.out, greeted: false, claimableCount: 3).kind,
        BitRoomVoiceKind.greeting,
      );
    });

    test('nothing claimable → plain advice (not tappable)', () {
      final l = sel(phase: AdventurePhase.idle, claimableCount: 0);
      expect(l.kind, BitRoomVoiceKind.advice);
      expect(l.tappable, isFalse);
    });
  });

  group('advice indexing', () {
    test('each index maps to its line; wraps modulo the pool', () {
      for (var i = 0; i < bitRoomAdvice.length; i++) {
        expect(sel(phase: AdventurePhase.idle, adviceIndex: i).text,
            bitRoomAdvice[i]);
      }
      expect(
        sel(phase: AdventurePhase.idle, adviceIndex: bitRoomAdvice.length + 2)
            .text,
        bitRoomAdvice[2],
      );
    });
  });

  test('the advice pool is the 6 approved lines — no empty / no food line', () {
    expect(bitRoomAdvice.length, 6);
    expect(bitRoomAdvice, isNot(contains('')));
    expect(bitRoomAdvice.any((l) => l.toLowerCase().contains('burden')), isFalse);
    expect(bitRoomAdvice, contains('67'));
    expect(bitRoomAdvice, contains('Remember to drink enough water'));
  });
}
