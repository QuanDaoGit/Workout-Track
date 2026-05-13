import 'package:flutter/material.dart';

import '../models/workout_models.dart';

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
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onCheckboxToggle;
  final VoidCallback? onInfoPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onInfoPressed,
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00FF9C)
                : const Color(0xFF2A2A4A),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
              child: SizedBox(
                width: 60,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      exercise.imageAssetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xFF0D0D1A),
                            child: Center(
                              child: ImageIcon(
                                AssetImage(
                                  'assets/icons/control/icon_sword.png',
                                ),
                                color: Color(0xFF2A2A4A),
                                size: 24,
                              ),
                            ),
                          ),
                    ),
                    Container(
                      color: const Color(0xFF0D0D1A).withValues(alpha: 0.4),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2A2A4A)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      exercise.levelLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFAAA8C0),
                      ),
                    ),
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
                  color: Color(0xFF6B6B8A),
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
                  color: Color(0xFF6B6B8A),
                  size: 16,
                ),
              ),
            // Favorite icon
            if (showFavorite)
              Padding(
                padding: EdgeInsets.only(right: showCheckbox ? 0 : 8),
                child: IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  icon: ImageIcon(
                    AssetImage(
                      isFavorite
                          ? 'assets/icons/control/icon_heart.png'
                          : 'assets/icons/control/icon_receptacle.png',
                    ),
                    color: isFavorite
                        ? const Color(0xFFFF2D55)
                        : const Color(0xFF6B6B8A),
                    size: 20,
                  ),
                  onPressed: onFavoriteToggle,
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
                            : const Color(0xFF2A2A4A),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_sharp,
                            size: 16,
                            color: Color(0xFF0D0D1A),
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
