import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'arcade_dialog_button_column.dart';

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
              FilledButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(ActiveSessionAction.continueOld),
                child: const Text('CONTINUE OLD'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  ctx,
                ).pop(ActiveSessionAction.endOldAndStartNew),
                style: FilledButton.styleFrom(
                  backgroundColor: kDanger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('END OLD & START NEW'),
              ),
              FilledButton(
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
