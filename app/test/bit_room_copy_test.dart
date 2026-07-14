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
    String adviceLine = '',
    String? routeName,
    int? backInHours,
    int claimableCount = 0,
  }) => BitRoomVoice.select(
    phase: phase,
    haulReady: haulReady,
    greeted: greeted,
    adviceLine: adviceLine,
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

  group('advice routing', () {
    test('idle → the resolved advice line verbatim (selector is a pure router)',
        () {
      expect(
        sel(phase: AdventurePhase.idle, adviceLine: 'Rest days are training days')
            .text,
        'Rest days are training days',
      );
      expect(
        sel(phase: AdventurePhase.returned, adviceLine: '67').text,
        '67',
      );
    });

    test('empty line → an empty advice bubble (never throws)', () {
      final l = sel(phase: AdventurePhase.idle, adviceLine: '');
      expect(l.kind, BitRoomVoiceKind.advice);
      expect(l.text, '');
    });
  });

  group('weighted, daily-capped advice draw (pickRoomAdvice)', () {
    test('a low roll under the chance draws the wildcard pool', () {
      final p = pickRoomAdvice(
        roll: 0.0,
        wildcardAllowedToday: true,
        regularIndex: 0,
        wildcardIndex: 0,
      );
      expect(p.isWildcard, isTrue);
      expect(p.line, bitRoomWildcardAdvice[0]);
    });

    test('a roll at/above the chance draws the regular pool', () {
      final p = pickRoomAdvice(
        roll: kBitRoomWildcardChance, // exclusive bound → regular
        wildcardAllowedToday: true,
        regularIndex: 2,
        wildcardIndex: 0,
      );
      expect(p.isWildcard, isFalse);
      expect(p.line, bitRoomRegularAdvice[2]);
    });

    test('the daily cap forces a wildcard-winning roll back to regular', () {
      final p = pickRoomAdvice(
        roll: 0.0, // would hit the wildcard pool…
        wildcardAllowedToday: false, // …but today's slot is spent
        regularIndex: 1,
        wildcardIndex: 0,
      );
      expect(p.isWildcard, isFalse);
      expect(p.line, bitRoomRegularAdvice[1]);
    });

    test('indices wrap modulo each pool', () {
      expect(
        pickRoomAdvice(
          roll: 1.0,
          wildcardAllowedToday: true,
          regularIndex: bitRoomRegularAdvice.length + 1,
          wildcardIndex: 0,
        ).line,
        bitRoomRegularAdvice[1],
      );
    });
  });

  test('the advice pools hold the approved lines — no empty / no food line', () {
    // The user-approved additions are present in the regular pool.
    expect(bitRoomRegularAdvice, contains('Remember to drink enough water'));
    expect(bitRoomRegularAdvice, contains('Your muscles grow while you sleep'));
    expect(bitRoomRegularAdvice,
        contains('Progress is neither fast nor slow, only yours'));
    expect(bitRoomRegularAdvice, contains('Rest days are training days'));
    expect(bitRoomRegularAdvice, contains('Consistency is the secret nobody sells'));
    expect(bitRoomRegularAdvice,
        contains('The only thing that can stop you is yourself'));
    // "67" is the lone wildcard, not in the everyday pool.
    expect(bitRoomWildcardAdvice, contains('67'));
    expect(bitRoomRegularAdvice, isNot(contains('67')));
    // No blanks, no retired food line, in either pool.
    expect(bitRoomAdvice, isNot(contains('')));
    expect(bitRoomAdvice.any((l) => l.toLowerCase().contains('burden')), isFalse);
    // The combined view is the two pools concatenated.
    expect(bitRoomAdvice.length,
        bitRoomRegularAdvice.length + bitRoomWildcardAdvice.length);
  });
}
