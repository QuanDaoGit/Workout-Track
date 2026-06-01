import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/character_class.dart';
import '../../models/character_draft.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/motion/hold_depress.dart';
import '../../widgets/pixel_button.dart';
import 'name_screen.dart';

typedef AvatarSelectedCallback = Future<void> Function(CharacterDraft draft);

class AvatarOption {
  const AvatarOption({required this.id, required this.assetPath});

  final String id;
  final String assetPath;
}

const onboardingAvatarOptions = [
  AvatarOption(id: 'avatar_01', assetPath: 'assets/avatar/EverFace1.0.png'),
  AvatarOption(id: 'avatar_02', assetPath: 'assets/avatar/1.png'),
  AvatarOption(id: 'avatar_03', assetPath: 'assets/avatar/3.png'),
  AvatarOption(id: 'avatar_04', assetPath: 'assets/avatar/4.png'),
  AvatarOption(id: 'avatar_05', assetPath: 'assets/avatar/5.png'),
  AvatarOption(id: 'avatar_06', assetPath: 'assets/avatar/6.png'),
  AvatarOption(id: 'avatar_07', assetPath: 'assets/avatar/7.png'),
  AvatarOption(id: 'avatar_08', assetPath: 'assets/avatar/8.png'),
];

class AvatarSelectScreen extends StatefulWidget {
  const AvatarSelectScreen({
    super.key,
    required this.draft,
    required this.onAvatarSelected,
    this.initialSelectedAvatarId,
    this.onPreviewChanged,
  });

  final CharacterDraft draft;
  final String? initialSelectedAvatarId;
  final ValueChanged<String>? onPreviewChanged;
  final AvatarSelectedCallback onAvatarSelected;

  @override
  State<AvatarSelectScreen> createState() => _AvatarSelectScreenState();
}

class _AvatarSelectScreenState extends State<AvatarSelectScreen>
    with SingleTickerProviderStateMixin {
  static const _prompt = 'CHOOSE YOUR FACE';
  static const _promptStartMs = 150;
  static const _charMs = 30;
  static const _rowRevealMs = 200;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  String? _selectedAvatarId;
  String? _announcement;
  bool _committing = false;
  bool _started = false;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _selectedAvatarId =
        widget.initialSelectedAvatarId ?? widget.draft.selectedAvatarId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectAvatar(AvatarOption option, int index) {
    if (_selectedAvatarId == option.id) return;
    setState(() {
      _selectedAvatarId = option.id;
      _announcement = 'Avatar ${index + 1} selected';
    });
    widget.onPreviewChanged?.call(option.id);
  }

  Future<void> _commit() async {
    final selected = _selectedAvatarId;
    if (selected == null || _committing) return;
    setState(() => _committing = true);
    final next = widget.draft.copyWith(selectedAvatarId: selected);
    await widget.onAvatarSelected(next);
    if (!mounted) return;
    await Navigator.of(context).push(
      arcadeRoute(
        (_) => NameScreen(draft: next, onCharacterCreated: (_) async {}),
      ),
    );
    if (mounted) setState(() => _committing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final ms = (_controller.value * 1200).round();
            final prompt = _typedPrompt(ms);
            final promptDoneMs = _promptStartMs + _prompt.length * _charMs;
            final topRowProgress = _progress(ms, promptDoneMs, _rowRevealMs);
            final bottomRowProgress = _progress(
              ms,
              promptDoneMs + 100,
              _rowRevealMs,
            );
            final accentColor = widget.draft.calibration.clazz.themeColor;
            final clazz = widget.draft.calibration.clazz;
            final selectedOption = _selectedAvatarId == null
                ? null
                : onboardingAvatarOptions.firstWhere(
                    (o) => o.id == _selectedAvatarId,
                    orElse: () => onboardingAvatarOptions.first,
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AvatarTopBar(onBack: () => Navigator.of(context).pop()),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                  child: Semantics(
                    header: true,
                    child: Text(
                      prompt,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                        color: kNeon,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: kCard,
                          border: Border.all(
                            color: selectedOption != null
                                ? accentColor
                                : kBorder,
                            width: selectedOption != null ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(kCardRadius),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: selectedOption == null
                            ? null
                            : Image.asset(
                                selectedOption.assetPath,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedOption == null ? 'PICK ONE' : clazz.displayName,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                          color: selectedOption == null
                              ? kMutedText
                              : accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 356,
                    child: Column(
                      children: [
                        _AvatarRowReveal(
                          progress: topRowProgress,
                          child: _AvatarRow(
                            options: onboardingAvatarOptions.sublist(0, 4),
                            startIndex: 0,
                            selectedAvatarId: _selectedAvatarId,
                            onSelect: _selectAvatar,
                            accentColor: accentColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AvatarRowReveal(
                          progress: bottomRowProgress,
                          child: _AvatarRow(
                            options: onboardingAvatarOptions.sublist(4, 8),
                            startIndex: 4,
                            selectedAvatarId: _selectedAvatarId,
                            onSelect: _selectAvatar,
                            accentColor: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_announcement != null)
                  Semantics(
                    liveRegion: true,
                    child: SizedBox(
                      height: 1,
                      child: Text(
                        _announcement!,
                        style: const TextStyle(fontSize: 1, color: kBg),
                      ),
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                  child: Semantics(
                    button: true,
                    enabled: _selectedAvatarId != null,
                    child: PixelButton(
                      label: 'THIS IS ME',
                      minHeight: 56,
                      fontSize: 14,
                      powerOn: true,
                      disabledColor: kCard,
                      disabledBorderColor: kBorder,
                      disabledLabelColor: kDim,
                      onPressed: _selectedAvatarId == null || _committing
                          ? null
                          : _commit,
                    ),
                  ),
                ),
                const SizedBox(height: kSpace5),
              ],
            );
          },
        ),
      ),
    );
  }

  String _typedPrompt(int ms) {
    if (_reduceMotion) return _prompt;
    final count = ((ms - _promptStartMs) / _charMs).floor().clamp(
      0,
      _prompt.length,
    );
    return _prompt.substring(0, count);
  }

  double _progress(int ms, int start, int duration) {
    if (_reduceMotion) return 1;
    return ((ms - start) / duration).clamp(0.0, 1.0).toDouble();
  }
}

class _AvatarTopBar extends StatelessWidget {
  const _AvatarTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Semantics(
              button: true,
              label: 'Back',
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left_sharp,
                  color: kNeon,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({
    required this.options,
    required this.startIndex,
    required this.selectedAvatarId,
    required this.onSelect,
    required this.accentColor,
  });

  final List<AvatarOption> options;
  final int startIndex;
  final String? selectedAvatarId;
  final void Function(AvatarOption option, int index) onSelect;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          _AvatarTile(
            option: options[i],
            index: startIndex + i,
            selected: selectedAvatarId == options[i].id,
            onTap: () => onSelect(options[i], startIndex + i),
            accentColor: accentColor,
          ),
          if (i != options.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.option,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.accentColor,
  });

  final AvatarOption option;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Avatar ${index + 1} of eight',
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : kMotionFast,
          curve: kMotionCurve,
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(
              color: selected ? accentColor : kBorder,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                option.assetPath,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
              if (selected)
                Positioned(
                  right: 4,
                  top: 4,
                  child: ImageIcon(
                    const AssetImage('assets/icons/control/icon_star.png'),
                    size: 8,
                    color: accentColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarRowReveal extends StatelessWidget {
  const _AvatarRowReveal({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: t.clamp(0.0001, 1.0),
              child: child,
            ),
          ),
          if (t > 0 && t < 1)
            CustomPaint(
              painter: _AvatarScanlinePainter(progress: t),
              child: const SizedBox.expand(),
            ),
        ],
      ),
    );
  }
}

class _AvatarScanlinePainter extends CustomPainter {
  const _AvatarScanlinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final linePaint = Paint()
      ..color = kNeon.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final scanPaint = Paint()
      ..color = kText.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (double lineY = 0; lineY < y; lineY += 4) {
      canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), scanPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarScanlinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
