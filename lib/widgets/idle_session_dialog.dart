import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../theme/tokens.dart';
import 'arcade_dialog_button_column.dart';

/// What the user chose on the idle-session reveal.
enum IdleSessionChoice { save, resume, discard }

/// Calm reveal shown when a workout has gone idle past the auto-save window.
/// Reassures (the work is kept), then offers — when sets were logged — to save &
/// finish, keep going, or discard. With no logged sets there is nothing to save,
/// so only resume/discard are offered.
///
/// [resumeLabel] differs by surface: "RESUME WORKOUT" from the cold reopen,
/// "KEEP TRAINING" from the active page's own timer. [idleMinutes] is the
/// rounded gap since the last logged set, shown so the notice is concrete.
Future<IdleSessionChoice?> showIdleSessionDialog(
  BuildContext context, {
  required bool hasSets,
  required String resumeLabel,
  required int idleMinutes,
}) {
  final body = hasSets
      ? 'No sets for about $idleMinutes minutes. Your logged sets are safe — '
            'save and finish here, or keep training. Time is counted up to your '
            'last set.'
      : 'No sets for about $idleMinutes minutes. Nothing has been logged yet — '
            'keep training or discard this session.';

  return showDialog<IdleSessionChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kSurface3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      title: const Text('STILL TRAINING?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(body),
          const SizedBox(height: 16),
          ArcadeDialogButtonColumn(
            children: [
              if (hasSets)
                FilledButton(
                  onPressed: () {
                    HapticService.instance.success();
                    Navigator.of(ctx).pop(IdleSessionChoice.save);
                  },
                  child: const Text('SAVE & FINISH'),
                ),
              FilledButton(
                onPressed: () {
                  HapticService.instance.selection();
                  Navigator.of(ctx).pop(IdleSessionChoice.resume);
                },
                style: hasSets
                    ? FilledButton.styleFrom(
                        backgroundColor: kBorderVariant,
                        foregroundColor: kText,
                        side: const BorderSide(color: kBorder),
                      )
                    : null,
                child: Text(resumeLabel),
              ),
              FilledButton(
                onPressed: () {
                  HapticService.instance.warning();
                  Navigator.of(ctx).pop(IdleSessionChoice.discard);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: kDanger,
                  shadowColor: Colors.transparent,
                  overlayColor: kDanger.withValues(alpha: 0.12),
                ),
                child: const Text('DISCARD'),
              ),
            ],
          ),
        ],
      ),
      actions: const [],
    ),
  );
}
