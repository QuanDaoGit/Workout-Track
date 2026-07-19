import 'dart:math';

import 'package:flutter/material.dart';

import '../models/avatar_spec.dart';
import '../services/haptic_service.dart';
import '../services/profile_service.dart';
import '../services/ui_sound.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_filled.dart';
import '../widgets/avatar/ironbit_avatar.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/phosphor_tap.dart';
import '../widgets/pixel_button.dart';

/// "EDIT AVATAR" — composes the pixel face from the five option groups.
/// Chip taps apply to the live preview instantly; SAVE persists to the
/// profile store and pops `true` so the caller reloads.
class AvatarCustomizerPage extends StatefulWidget {
  const AvatarCustomizerPage({super.key});

  @override
  State<AvatarCustomizerPage> createState() => _AvatarCustomizerPageState();
}

class _AvatarCustomizerPageState extends State<AvatarCustomizerPage> {
  AvatarSpec _initial = AvatarSpec.fallback;
  AvatarSpec _spec = AvatarSpec.fallback;
  bool _loading = true;
  bool _saving = false;

  bool get _edited => _spec != _initial;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileService().loadProfile();
    if (!mounted) return;
    setState(() {
      _initial = profile.avatarSpec;
      _spec = profile.avatarSpec;
      _loading = false;
    });
  }

  void _apply(AvatarSpec next) {
    if (next == _spec) return;
    setState(() => _spec = next);
  }

  void _randomize() {
    final rng = Random();
    T pick<T>(List<T> values) => values[rng.nextInt(values.length)];
    _apply(
      AvatarSpec(
        skin: pick(AvatarSkin.values),
        eyes: pick(AvatarEyes.values),
        hair: pick(AvatarHair.values),
        hairColor: pick(AvatarHairColor.values),
        expression: pick(AvatarExpression.values),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ProfileService().saveAvatarSpec(_spec);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _handleBack() async {
    if (!_edited) {
      Navigator.of(context).pop(false);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DISCARD CHANGES?'),
        content: Text(
          'Your new look has not been saved.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
        ),
        actions: [
          ArcadeTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('KEEP EDITING'),
          ),
          ArcadeTextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            haptic: HapticIntent.warning,
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  String get _comboLine => [
    _skinLabel(_spec.skin),
    _spec.eyes.name.toUpperCase(),
    _spec.hair.name.toUpperCase(),
    _spec.hairColor.name.toUpperCase(),
    _spec.expression.name.toUpperCase(),
  ].join(' | ');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_edited,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          title: const Text('EDIT AVATAR'),
          leading: ArcadeIconButton(
            key: const ValueKey('avatar_customizer_back'),
            icon: const Icon(Icons.chevron_left_sharp, size: 28),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          kSpace4,
                          kSpace4,
                          kSpace4,
                          kSpace3,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildPreview(),
                            const SizedBox(height: kSpace5),
                            _OptionGroup<AvatarSkin>(
                              label: 'SKIN',
                              meta: '${AvatarSkin.values.length} tones',
                              values: AvatarSkin.values,
                              selected: _spec.skin,
                              labelFor: _skinLabel,
                              swatchFor: avatarSkinSwatch,
                              onSelect: (v) => _apply(_spec.copyWith(skin: v)),
                            ),
                            _OptionGroup<AvatarEyes>(
                              label: 'EYES',
                              meta: '${AvatarEyes.values.length} colors',
                              values: AvatarEyes.values,
                              selected: _spec.eyes,
                              swatchFor: avatarEyeSwatch,
                              onSelect: (v) => _apply(_spec.copyWith(eyes: v)),
                            ),
                            _OptionGroup<AvatarHair>(
                              label: 'HAIR STYLE',
                              meta: '${AvatarHair.values.length} styles',
                              values: AvatarHair.values,
                              selected: _spec.hair,
                              onSelect: (v) => _apply(_spec.copyWith(hair: v)),
                            ),
                            _OptionGroup<AvatarHairColor>(
                              label: 'HAIR COLOR',
                              meta: '${AvatarHairColor.values.length} colors',
                              values: AvatarHairColor.values,
                              selected: _spec.hairColor,
                              swatchFor: avatarHairColorSwatch,
                              onSelect: (v) =>
                                  _apply(_spec.copyWith(hairColor: v)),
                            ),
                            _OptionGroup<AvatarExpression>(
                              label: 'EXPRESSION',
                              meta: '${AvatarExpression.values.length} moods',
                              values: AvatarExpression.values,
                              selected: _spec.expression,
                              onSelect: (v) =>
                                  _apply(_spec.copyWith(expression: v)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        kSpace4,
                        kSpace2,
                        kSpace4,
                        kSpace4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: PixelButton(
                              label: 'RANDOMIZE',
                              secondary: true,
                              onPressed: _randomize,
                            ),
                          ),
                          const SizedBox(width: kSpace3),
                          Expanded(
                            child: PixelButton(
                              label: 'SAVE',
                              onPressed: _saving ? null : _save,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Container(
          width: 184,
          height: 184,
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(kCardRadius),
            border: Border.all(
              color: kAmber,
              width: kPrimaryCardBorderWidth,
            ),
            boxShadow: neonGlow(color: kAmber, opacity: 0.22, blur: 16),
          ),
          alignment: Alignment.center,
          child: IronbitAvatar(spec: _spec, size: 160),
        ),
        const SizedBox(height: kSpace3),
        Text(
          _comboLine,
          key: const ValueKey('avatar_combo_line'),
          textAlign: TextAlign.center,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
        ),
      ],
    );
  }
}

String _skinLabel(AvatarSkin skin) =>
    'TONE 0${AvatarSkin.values.indexOf(skin) + 1}';

class _OptionGroup<T extends Enum> extends StatelessWidget {
  const _OptionGroup({
    required this.label,
    required this.meta,
    required this.values,
    required this.selected,
    required this.onSelect,
    this.labelFor,
    this.swatchFor,
  });

  final String label;
  final String meta;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelect;
  final String Function(T)? labelFor;
  final Color Function(T)? swatchFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: kMutedText,
                ),
              ),
              Text(
                meta,
                style: AppFonts.shareTechMono(color: kDim, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace2,
            runSpacing: kSpace2,
            children: [
              for (final value in values)
                _OptionChip(
                  label: (labelFor ?? (v) => v.name.toUpperCase())(value),
                  swatch: swatchFor?.call(value),
                  selected: value == selected,
                  onTap: () => onSelect(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatch,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;
    return Semantics(
      button: true,
      selected: selected,
      child: PhosphorTap(
        child: HoldDepress(
          onTap: onTap,
          haptic: HapticIntent.selection,
          sound: UiSound.select,
          borderRadius: BorderRadius.circular(kCardRadius),
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : kMotionFast,
            curve: kMotionCurve,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? kNeon : Colors.transparent,
              border: Border.all(color: selected ? kNeon : kBorder),
              borderRadius: BorderRadius.circular(kCardRadius),
              boxShadow: selected
                  ? neonGlow(color: kNeon, opacity: 0.22, blur: 16)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (swatch != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: swatch,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: kBlack.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    height: 1.4,
                    color: selected ? kBg : kMutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
