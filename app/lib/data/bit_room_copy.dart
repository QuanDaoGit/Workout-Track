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

/// The everyday idle pool — the lines BIT rotates through at home (a fresh one
/// on each Home re-entry). Together these share the non-wildcard 95% of every
/// draw (1 - [kBitRoomWildcardChance]), split evenly across the pool, so
/// adding/removing a line just re-divides the regular share — no per-line tuning.
const List<String> bitRoomRegularAdvice = [
  // Recovery & fuel.
  'Remember to drink enough water',
  'Sleeping is the cheat code to muscle growth',
  'Your muscles grow while you sleep',
  'Rest days are training days',
  // Mindset & momentum.
  'Perfect is the enemy of good',
  'One day or day one?',
  'The hardest distance is the front door',
  'Progress is neither fast nor slow, only yours',
  'Consistency is the secret nobody sells',
  'The only thing that can stop you is yourself',
];

/// The rare "wildcard" pool — flavour lines that should surprise, not saturate.
/// The whole pool shares only [kBitRoomWildcardChance] of every draw (split
/// evenly across it) AND is capped to at most one appearance per day. One line
/// today holds the full 5%; the weighting scales to any pool size unchanged.
const List<String> bitRoomWildcardAdvice = [
  '67',
];

/// Wildcard share of an idle-advice draw; the regular pool takes the remaining
/// 95%. A single knob — pool sizes don't affect the split between the two pools.
const double kBitRoomWildcardChance = 0.05;

/// Every advice line (regular + wildcard) — the combined view used by invariants
/// and any surface that just wants "the things BIT can say at idle".
const List<String> bitRoomAdvice = [
  ...bitRoomRegularAdvice,
  ...bitRoomWildcardAdvice,
];

/// One resolved idle-advice draw: the chosen [line] and whether it came from the
/// wildcard pool (so the caller can record the once-per-day cap on a hit).
class BitAdvicePick {
  const BitAdvicePick({required this.line, required this.isWildcard});
  final String line;
  final bool isWildcard;
}

/// Draws one idle-advice line under the weighted, daily-capped scheme.
///
/// [roll] is a uniform random in [0, 1): a draw below [kBitRoomWildcardChance]
/// targets the wildcard pool, the rest the regular pool. A wildcard draw falls
/// back to the regular pool when [wildcardAllowedToday] is false (the day's cap
/// is spent) or the wildcard pool is empty — so the cap never blanks the bubble.
/// Each pool is read at its own rotating [regularIndex] / [wildcardIndex] so the
/// caller controls no-immediate-repeat per pool. Pure + deterministic in [roll].
BitAdvicePick pickRoomAdvice({
  required double roll,
  required bool wildcardAllowedToday,
  required int regularIndex,
  required int wildcardIndex,
}) {
  final wantWildcard = roll < kBitRoomWildcardChance &&
      wildcardAllowedToday &&
      bitRoomWildcardAdvice.isNotEmpty;
  if (wantWildcard) {
    final line =
        bitRoomWildcardAdvice[wildcardIndex % bitRoomWildcardAdvice.length];
    return BitAdvicePick(line: line, isWildcard: true);
  }
  if (bitRoomRegularAdvice.isEmpty) {
    return const BitAdvicePick(line: '', isWildcard: false);
  }
  final line =
      bitRoomRegularAdvice[regularIndex % bitRoomRegularAdvice.length];
  return BitAdvicePick(line: line, isWildcard: false);
}

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
    String adviceLine = '',
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
    // Idle / home — BIT present, showing the already-resolved advice line. The
    // weighted, daily-capped draw (regular vs wildcard pool) happens in
    // [pickRoomAdvice]; the caller passes the winner so this selector stays a
    // pure router with no randomness or persistence of its own.
    return BitRoomLine(
      kind: BitRoomVoiceKind.advice,
      text: adviceLine,
      semanticsLabel: adviceLine,
    );
  }
}
