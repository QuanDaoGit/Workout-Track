import '../models/adventure_models.dart';
import 'bit_quest_copy.dart';

/// BIT's voice in the home room. A single text-box surface whose line is a pure
/// function of the room state — so the selection is unit-testable and can't
/// diverge across the foreground / cold-reopen / tab-switch refresh paths.
///
/// Home (BIT present, idle): a rotating life-advice line — body-neutral, never
/// a guilt-poke; just a companion saying something human. Away: a one-shot
/// "I'm back" when the hologram first appears, then the live expedition status.
/// A waiting haul always wins (the only durable pending action in the room); a
/// quest reward ready to claim nudges toward the board (tappable → Quests).

/// The rotating home-advice pool. Grouped only for authoring clarity; rotation
/// treats them as one flat pool (a fresh line on each Home re-entry).
const List<String> bitRoomAdvice = [
  // Recovery & fuel.
  'Remember to drink enough water',
  'Sleeping is the cheat code to muscle growth',
  // Mindset & momentum.
  'Perfect is the enemy of good',
  'One day or day one?',
  'The hardest distance is the front door',
  // Wildcard.
  '67',
];

/// The homecoming greeting, shown once when the away hologram first appears.
const String bitRoomGreeting = "It's me again";

/// The reward prompt while a haul waits; [bitRoomHaulEmphasis] is tinted magenta
/// (the gem colour) and the bubble is tappable → collect.
const String bitRoomHaulText = 'Check out the loots. Tap to collect';
const String bitRoomHaulEmphasis = 'loots';

/// Spam-tap easter egg: poke BIT fast enough at home and he tires of it — he
/// slumps to REST and sighs this once for ~3s before perking back to neutral
/// advice. Driven by [BitCompanion]'s own tap counter, not the voice selector.
const String bitRoomRestQuip = 'I guess bro...';

/// Which voice state BIT is in — drives the bubble content + behaviour. The
/// renderer maps each kind to the right presentation (emphasis colour, tap).
enum BitRoomVoiceKind { advice, greeting, scouting, haul, claimable }

/// The resolved line BIT shows in the room bubble. Widget-free (no theme deps)
/// so the selector stays pure; the renderer decides colours/tap by [kind].
class BitRoomLine {
  const BitRoomLine({
    required this.kind,
    required this.semanticsLabel,
    this.text,
    this.emphasis,
    this.routeName,
    this.backInHours,
    this.tappableCollect = false,
  });

  final BitRoomVoiceKind kind;

  /// The spoken-line text (advice / greeting / haul / claimable). Null for
  /// [scouting], which the renderer builds from [routeName] + [backInHours].
  final String? text;

  /// A substring of [text] to emphasise (haul: "loots" → magenta).
  final String? emphasis;

  /// Scouting status fields (the relocated SCOUTING / ROUTE / BACK IN readout).
  final String? routeName;
  final int? backInHours;

  /// True for the haul line — the bubble is a collect tap target.
  final bool tappableCollect;

  final String semanticsLabel;

  /// True when tapping the bubble routes somewhere — haul → collect, claimable
  /// → open Quests. The renderer wires the destination by [kind].
  bool get tappable => tappableCollect || kind == BitRoomVoiceKind.claimable;
}

/// Selects exactly one room voice line by **strict priority**:
/// haul > fresh greeting > away status > claimable reward > idle advice. The
/// reward (derived from the persisted [haulReady]) always wins so stale
/// advice/greeting state can never hide the only pending action; a claimable
/// quest reward nudges toward the board only when home and idle.
abstract final class BitRoomVoice {
  static BitRoomLine select({
    required AdventurePhase phase,
    required bool haulReady,
    required bool greeted,
    required int adviceIndex,
    String? routeName,
    int? backInHours,
    int claimableCount = 0,
  }) {
    if (haulReady) {
      return const BitRoomLine(
        kind: BitRoomVoiceKind.haul,
        text: bitRoomHaulText,
        emphasis: bitRoomHaulEmphasis,
        tappableCollect: true,
        semanticsLabel: 'Check out the loot. Tap to collect.',
      );
    }
    if (phase == AdventurePhase.out) {
      if (!greeted) {
        return const BitRoomLine(
          kind: BitRoomVoiceKind.greeting,
          text: bitRoomGreeting,
          semanticsLabel: "It's me again.",
        );
      }
      final route = routeName ?? 'EXPEDITION';
      return BitRoomLine(
        kind: BitRoomVoiceKind.scouting,
        routeName: route,
        backInHours: backInHours,
        semanticsLabel: backInHours == null
            ? 'Scouting $route.'
            : 'Scouting $route. Back in about $backInHours hours.',
      );
    }
    // Home + a reward waiting to be claimed — a calm nudge toward the board,
    // tappable to open Quests. Below the away/haul states, above idle advice.
    if (claimableCount > 0) {
      final text = BitQuestCopy.briefing(
        claimable: claimableCount,
        todayClaimed: 0,
        weeklyDone: 0,
        weeklyTotal: 0,
      );
      return BitRoomLine(
        kind: BitRoomVoiceKind.claimable,
        text: text,
        semanticsLabel: '$text Tap to open quests.',
      );
    }
    // Idle / home — BIT present, rotating advice.
    if (bitRoomAdvice.isEmpty) {
      return const BitRoomLine(
        kind: BitRoomVoiceKind.advice,
        text: '',
        semanticsLabel: '',
      );
    }
    final line = bitRoomAdvice[adviceIndex % bitRoomAdvice.length];
    return BitRoomLine(
      kind: BitRoomVoiceKind.advice,
      text: line,
      semanticsLabel: line,
    );
  }
}
