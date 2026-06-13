import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Confirm gate before entering a live training session from the center Train
/// nav button. Returns `true` to start, `false`/`null` to cancel. The deliberate
/// friction makes "go train" read as a committed mode-switch — training is the
/// app's primary verb, not an idle browse. Fires only on the nav Train tap, not
/// on already-intentful entry points (the Home mission, session repeat).
Future<bool?> showStartTrainingDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
        side: const BorderSide(color: kNeon, width: kPrimaryCardBorderWidth),
      ),
      title: const Text(
        'START TRAINING?',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: kNeon,
        ),
      ),
      content: const Text(
        'This begins a live session.',
        style: TextStyle(color: kMutedText),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(kSpace3, 0, kSpace3, kSpace3),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('NOT YET', style: TextStyle(color: kMutedText)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text("LET'S GO"),
        ),
      ],
    ),
  );
}
