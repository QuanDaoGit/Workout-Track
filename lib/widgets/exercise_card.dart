import 'package:flutter/material.dart';

import '../models/workout_models.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'arcade_image_filter.dart';
import 'level_badge.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    this.showCheckbox = false,
    this.showArrow = false,
    this.showFavorite = true,
    this.showInfoIcon = false,
    this.isSelected = false,
    this.isFavorite = false,
    this.isCustom = false,
    this.onFavoriteToggle,
    this.onCheckboxToggle,
    this.onInfoPressed,
  });

  final Exercise exercise;
  final VoidCallback onTap;
  final bool showCheckbox;
  final bool showArrow;
  final bool showFavorite;
  final bool showInfoIcon;
  final bool isSelected;
  final bool isFavorite;
  final bool isCustom;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onCheckboxToggle;
  final VoidCallback? onInfoPressed;

  @override
  Widget build(BuildContext context) {
    final useSelectedBorder = isSelected && !showCheckbox;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onInfoPressed,
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(
            color: useSelectedBorder
                ? const Color(0xFF00FF9C)
                : kBorder,
            width: useSelectedBorder ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
              child: SizedBox(
                width: 60,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isCustom)
                      const ColoredBox(
                        color: kBg,
                        child: Center(
                          child: ImageIcon(
                            AssetImage('assets/icons/control/icon_hammer.png'),
                            color: Color(0xFF00FF9C),
                            size: 24,
                          ),
                        ),
                      )
                    else if (exercise.imageAssetPath.isEmpty)
                      const _NoPhotoPlaceholder()
                    else
                      ArcadeImageFilter(
                        borderRadius: BorderRadius.zero,
                        child: Image.asset(
                          exercise.imageAssetPath,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stackTrace) =>
                              const _NoPhotoPlaceholder(),
                        ),
                      ),
                    Container(
                      color: kBg.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + level badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      LevelBadge(exercise: exercise),
                      if (isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF00BFFF)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CUSTOM',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 7,
                              color: Color(0xFF00BFFF),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Info icon (picker only)
            if (showInfoIcon)
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                icon: const ImageIcon(
                  AssetImage('assets/icons/control/icon_expand.png'),
                  color: kMutedText,
                  size: 20,
                ),
                onPressed: onInfoPressed,
              ),
            // Arrow (library only)
            if (showArrow)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: ImageIcon(
                  AssetImage('assets/icons/control/icon_next.png'),
                  color: kMutedText,
                  size: 16,
                ),
              ),
            // Favorite icon
            if (showFavorite)
              Padding(
                padding: EdgeInsets.only(right: showCheckbox ? 0 : 8),
                child: _BouncingHeartIcon(
                  isFavorite: isFavorite,
                  onToggle: onFavoriteToggle,
                ),
              ),
            // Checkbox
            if (showCheckbox)
              GestureDetector(
                onTap: onCheckboxToggle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00FF9C)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00FF9C)
                            : kBorder,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_sharp,
                            size: 16,
                            color: kBg,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoPhotoPlaceholder extends StatelessWidget {
  const _NoPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'NO\nPHOTO',
          textAlign: TextAlign.center,
          style: AppFonts.shareTechMono(
            color: kMutedText,
            fontSize: 9,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BouncingHeartIcon extends StatefulWidget {
  const _BouncingHeartIcon({required this.isFavorite, this.onToggle});

  final bool isFavorite;
  final VoidCallback? onToggle;

  @override
  State<_BouncingHeartIcon> createState() => _BouncingHeartIconState();
}

class _BouncingHeartIconState extends State<_BouncingHeartIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 1),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onPressed: () {
        _controller.forward(from: 0);
        widget.onToggle?.call();
      },
      icon: ScaleTransition(
        scale: _scale,
        child: ImageIcon(
          AssetImage(
            widget.isFavorite
                ? 'assets/icons/control/icon_heart.png'
                : 'assets/icons/control/icon_receptacle.png',
          ),
          color: widget.isFavorite
              ? const Color(0xFFFF2D55)
              : kMutedText,
          size: 20,
        ),
      ),
    );
  }
}
