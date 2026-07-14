import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class ArcadeDialogButtonColumn extends StatelessWidget {
  const ArcadeDialogButtonColumn({
    super.key,
    required this.children,
    this.spacing = kSpace2,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}
