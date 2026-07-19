import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../theme/tokens.dart';
import 'arcade_dialog_button_column.dart';
import 'arcade_filled.dart';

enum ActiveSessionAction { continueOld, endOldAndStartNew }

Future<ActiveSessionAction?> showActiveSessionFoundDialog(
  BuildContext context,
) {
  return showDialog<ActiveSessionAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ACTIVE SESSION FOUND'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Finish your current run or end it before starting new.'),
          const SizedBox(height: 16),
          ArcadeDialogButtonColumn(
            children: [
              ArcadeFilled(
                onPressed: () =>
                    Navigator.of(ctx).pop(ActiveSessionAction.continueOld),
                child: const Text('CONTINUE OLD'),
              ),
              ArcadeFilled(
                haptic: HapticIntent.warning,
                onPressed: () => Navigator.of(
                  ctx,
                ).pop(ActiveSessionAction.endOldAndStartNew),
                style: FilledButton.styleFrom(
                  backgroundColor: kDanger,
                  foregroundColor: kWhite,
                ),
                child: const Text('END OLD & START NEW'),
              ),
              ArcadeFilled(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: kBorderVariant,
                  foregroundColor: kText,
                  side: const BorderSide(color: kBorder),
                ),
                child: const Text('CANCEL'),
              ),
            ],
          ),
        ],
      ),
      actions: const [],
    ),
  );
}
