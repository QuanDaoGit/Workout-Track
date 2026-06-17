/// BIT's voice on the quest board — calm, low-frequency, body-neutral. He frames
/// the board from its *current state* (claimable / today-claimed / weekly arc),
/// never from the user's failures. An empty board reads as **quiet**, never a
/// guilt-poke: no streak-shaming, no "you haven't trained", only a warm forward
/// nudge (anti-guilt / body-neutral doctrine). The single returned line is shown
/// in a [BitSpeechBubble]; it is plain (no `[bracket]` emphasis) to keep the
/// header calm next to the quests the user is reading.
class BitQuestCopy {
  const BitQuestCopy._();

  /// A single state-derived briefing line for the quest board.
  ///
  /// [claimable] = rewards ready to claim now; [todayClaimed] = quests claimed
  /// today; [weeklyDone]/[weeklyTotal] = weekly-quest completion. Priority:
  /// something to claim now > a finished weekly set > a good day already banked >
  /// a quiet board.
  static String briefing({
    required int claimable,
    required int todayClaimed,
    required int weeklyDone,
    required int weeklyTotal,
  }) {
    if (claimable > 0) {
      final noun = claimable == 1 ? 'reward' : 'rewards';
      return '$claimable $noun ready to claim.';
    }
    if (weeklyTotal > 0 && weeklyDone >= weeklyTotal) {
      return 'Every weekly cleared. Outstanding.';
    }
    if (todayClaimed > 0) {
      return 'Good haul today, warrior.';
    }
    // Quiet board — forward and collaborative, never a guilt-poke.
    return 'Nothing to claim yet. Let us change that.';
  }
}
