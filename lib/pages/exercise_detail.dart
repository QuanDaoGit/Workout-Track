import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/workout_models.dart';
import '../services/favorite_service.dart';
import '../widgets/arcade_image_filter.dart';
import '../widgets/level_badge.dart';

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final favs = await FavoriteService().getFavoriteExerciseIds();
    if (!mounted) return;
    setState(() => _isFavorite = favs.contains(widget.exercise.id));
  }

  Future<void> _toggleFavorite() async {
    final isNowFavorite = await FavoriteService().toggleFavoriteExercise(
      widget.exercise.id,
    );
    if (!mounted) return;
    setState(() => _isFavorite = isNowFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero image AppBar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Transform.scale(
                scaleX: -1,
                child: const ImageIcon(
                  AssetImage('assets/icons/control/icon_next.png'),
                  color: Color(0xFF00FF9C),
                  size: 20,
                ),
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0D0D1A).withValues(alpha: 0.7),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _BouncingFavoriteIcon(
                  isFavorite: _isFavorite,
                  onToggle: _toggleFavorite,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (exercise.imageAssetPath.isNotEmpty)
                    ArcadeImageFilter(
                      borderRadius: BorderRadius.zero,
                      child: Image.asset(
                        exercise.imageAssetPath,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (context, error, stack) =>
                            const ColoredBox(color: Color(0xFF1A1A2E)),
                      ),
                    )
                  else
                    const ColoredBox(color: Color(0xFF1A1A2E)),
                ],
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                LevelBadge(exercise: exercise),
                const SizedBox(height: 16),
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),

                if (exercise.instructions.isNotEmpty) ...[
                  Text(
                    'INSTRUCTIONS',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < exercise.instructions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00FF9C,
                              ).withValues(alpha: 0.15),
                              border: Border.all(
                                color: const Color(0xFF00FF9C),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 8,
                                color: Color(0xFF00FF9C),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              exercise.instructions[i],
                              style: GoogleFonts.shareTechMono(
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else
                  Text(
                    'No instructions available.',
                    style: GoogleFonts.shareTechMono(
                      textStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingFavoriteIcon extends StatefulWidget {
  const _BouncingFavoriteIcon({
    required this.isFavorite,
    required this.onToggle,
  });

  final bool isFavorite;
  final VoidCallback onToggle;

  @override
  State<_BouncingFavoriteIcon> createState() => _BouncingFavoriteIconState();
}

class _BouncingFavoriteIconState extends State<_BouncingFavoriteIcon>
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
      onPressed: () {
        _controller.forward(from: 0);
        widget.onToggle();
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
              : const Color(0xFF6B6B8A),
          size: 24,
        ),
      ),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF0D0D1A).withValues(alpha: 0.7),
      ),
    );
  }
}
