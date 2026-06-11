import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../motion/hold_depress.dart';

/// Shared single-select option UI for onboarding question beats (the calibration
/// quiz and the "Forge Your Resolve" beat). A wipe-in list of selectable cards;
/// vertical alignment within the available space is configurable via
/// [OptionList.mainAxisAlignment]. Kept beat-agnostic — each beat wraps it in
/// its own scaffold (progress header differs per beat).

/// One option in an [OptionList].
class OptionDef {
  const OptionDef({
    required this.title,
    this.subtext,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String title;

  /// Optional muted second line. Single-line options (e.g. a vow) omit it.
  final String? subtext;

  /// Optional decorative leading glyph (e.g. a goal-direction trend icon).
  /// Purely visual — excluded from semantics so the a11y label stays the text.
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
}

class OptionList extends StatelessWidget {
  const OptionList({
    super.key,
    required this.hasAnySelection,
    required this.options,
    this.animate = true,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  final bool hasAnySelection;
  final List<OptionDef> options;
  final bool animate;

  /// How the cards sit within the available vertical space. Defaults to
  /// centered; the calibration quiz passes [MainAxisAlignment.start] so the
  /// options anchor directly under the prompt instead of floating mid-screen.
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      final card = _OptionCard(
        title: options[i].title,
        subtext: options[i].subtext,
        icon: options[i].icon,
        isSelected: options[i].isSelected,
        hasAnySelection: hasAnySelection,
        onTap: options[i].onTap,
      );
      children.add(
        animate
            ? _WipeIn(
                delay: Duration(milliseconds: i * 80),
                child: card,
              )
            : card,
      );
      if (i != options.length - 1) children.add(const SizedBox(height: 12));
    }
    // Lay out the cards per [mainAxisAlignment] within the available space,
    // still scrolling if the list is taller than the viewport (Q3 has four).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: mainAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtext,
    required this.icon,
    required this.isSelected,
    required this.hasAnySelection,
    required this.onTap,
  });

  final String title;
  final String? subtext;
  final IconData? icon;
  final bool isSelected;
  final bool hasAnySelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final dimmed = hasAnySelection && !isSelected;
    const accent = kNeon;
    final borderColor = isSelected ? accent : kBorder;
    final titleColor = isSelected ? accent : kText;
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 120);
    final sub = subtext;

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: isSelected,
      label: sub == null ? title : '$title. $sub',
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedOpacity(
          duration: duration,
          opacity: dimmed ? 0.4 : 1.0,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: kCard,
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _content(duration, titleColor, sub),
          ),
        ),
      ),
    );
  }

  Widget _content(Duration duration, Color titleColor, String? sub) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: duration,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: titleColor,
            height: 1.2,
          ),
          child: Text(title),
        ),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(
            sub,
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
    if (icon == null) return text;
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            size: 22,
            color: isSelected ? kNeon : kMutedText,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: text),
      ],
    );
  }
}

class _WipeIn extends StatefulWidget {
  const _WipeIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_WipeIn> createState() => _WipeInState();
}

class _WipeInState extends State<_WipeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Timer? _startTimer;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.of(context).disableAnimations;
    _reducedMotion = reduced;
    if (reduced) {
      _controller.value = 1;
      return;
    }
    if (!_controller.isAnimating && _controller.value == 0) {
      _startTimer?.cancel();
      _startTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t.clamp(0.0001, 1.0),
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
