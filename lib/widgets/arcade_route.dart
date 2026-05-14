import 'dart:async';

import 'package:flutter/material.dart';

/// Instant page route with a 1-frame CRT-style neon flash overlay.
/// No slide, no fade. The destination appears immediately, with a
/// brief green overlay simulating an old CRT switching channels.
Route<T> arcadeRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => _CrtFlashWrapper(child: builder(context)),
  );
}

class _CrtFlashWrapper extends StatefulWidget {
  const _CrtFlashWrapper({required this.child});

  final Widget child;

  @override
  State<_CrtFlashWrapper> createState() => _CrtFlashWrapperState();
}

class _CrtFlashWrapperState extends State<_CrtFlashWrapper> {
  bool _flash = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer(const Duration(milliseconds: 16), () {
        if (!mounted) return;
        setState(() => _flash = false);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_flash)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0xFF00FF9C)),
            ),
          ),
      ],
    );
  }
}
