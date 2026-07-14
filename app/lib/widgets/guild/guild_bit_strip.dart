import 'package:flutter/material.dart';

import '../companion/bit_mood_core.dart';
import '../companion/bit_speech_bubble.dart';

/// BIT hosting the guild hall — a faced companion + a state-derived voice line
/// (the anti-guilt "rest is fine" framing). **Voice-only**: in solo v1 there is
/// no other member to react to, so there is no reaction/Strike button (research:
/// a recipient-less reaction is a placebo). A real Strike returns in Phase 2 when
/// there are members to send it to. Reduced motion freezes BIT to a still frame.
class GuildBitStrip extends StatelessWidget {
  const GuildBitStrip({
    super.key,
    required this.line,
    this.pose = BitPose.neutral,
  });

  final String line;
  final BitPose pose;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('guild_bit_strip'),
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Center(child: BitMoodCore(pose: pose, reveal: 1, size: 44)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BitSpeechBubble(
            text: line,
            fontSize: 12,
            tailDirection: BitTailDirection.left,
          ),
        ),
      ],
    );
  }
}
