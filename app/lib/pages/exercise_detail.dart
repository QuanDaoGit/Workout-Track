import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_fonts.dart';

import '../data/exercise_demos.dart';
import '../models/workout_models.dart';
import '../services/custom_exercise_service.dart';
import '../services/favorite_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_image_filter.dart';
import '../widgets/arcade_route.dart';
import '../widgets/exercise_demo_cabinet.dart';
import '../widgets/exercise_demo_player.dart';
import '../widgets/level_badge.dart';
import '../widgets/pixel_button.dart';
import 'create_exercise_page.dart';
import 'exercise_history_page.dart';

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  bool _isFavorite = false;
  bool _hasLoggedSets = false;

  /// Hero demo playback; non-null only when the exercise has a form demo.
  VideoPlayerController? _demoController;

  @override
  void initState() {
    super.initState();
    final demo = exerciseDemoFor(widget.exercise.id);
    if (demo != null) {
      _demoController = VideoPlayerController.asset(demo.video);
    }
    _loadFavorite();
    _loadHasLoggedSets();
  }

  @override
  void dispose() {
    _demoController?.dispose();
    super.dispose();
  }

  /// Hands playback to the fullscreen viewer (own controller — never two
  /// `VideoPlayer`s on one controller), then resumes on return.
  Future<void> _openDemoFullscreen(ExerciseDemo demo) async {
    final controller = _demoController!;
    final wasPlaying = controller.value.isPlaying;
    final position = controller.value.position;
    if (wasPlaying) await controller.pause();
    if (!mounted) return;
    await openExerciseDemoFullscreen(
      context,
      demo: demo,
      exerciseName: widget.exercise.name,
      startAt: position,
    );
    if (mounted && wasPlaying) await controller.play();
  }

  Future<void> _loadFavorite() async {
    final favs = await FavoriteService().getFavoriteExerciseIds();
    if (!mounted) return;
    setState(() => _isFavorite = favs.contains(widget.exercise.id));
  }

  Future<void> _loadHasLoggedSets() async {
    final sessions = await WorkoutStorageService().getSessions();
    if (!mounted) return;
    final logged = sessions.any(
      (session) =>
          !session.isPartial &&
          session.exercises.any(
            (log) =>
                log.exerciseId == widget.exercise.id && log.sets.isNotEmpty,
          ),
    );
    setState(() => _hasLoggedSets = logged);
  }

  Future<void> _toggleFavorite() async {
    final isNowFavorite = await FavoriteService().toggleFavoriteExercise(
      widget.exercise.id,
    );
    if (!mounted) return;
    setState(() => _isFavorite = isNowFavorite);
  }

  Future<void> _confirmDelete(BuildContext context, Exercise exercise) async {
    // Capture the navigator before any await so we never touch `context` across
    // an async gap (it's a parameter, so the State `mounted` check wouldn't
    // cover it); the `mounted` guards below still protect against disposal.
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text(
          'DELETE THIS EXERCISE?',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kDanger,
          ),
        ),
        content: Text(
          'PAST SESSIONS REMAIN.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: AppFonts.shareTechMono(color: kMutedText),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: kDanger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'CONFIRM',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: kBg,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await CustomExerciseService().deleteCustomExercise(exercise.id);
    if (!mounted) return;
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: CustomScrollView(
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
                    color: kNeon,
                    size: 20,
                  ),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: kBg.withValues(alpha: 0.7),
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
                    if (exercise.isCustom)
                      const ColoredBox(
                        color: kCard,
                        child: Center(
                          child: ImageIcon(
                            AssetImage('assets/icons/control/icon_hammer.png'),
                            color: kNeon,
                            size: 64,
                          ),
                        ),
                      )
                    else if (exerciseDemoFor(exercise.id) case final demo?)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: kBg),
                          ExerciseDemoPlayer(
                            demo: demo,
                            controller: _demoController,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            left: 16,
                            bottom: 12,
                            child: Row(
                              children: [
                                const FormDemoTag(),
                                const SizedBox(width: 8),
                                _ExpandDemoPill(
                                  onTap: () => _openDemoFullscreen(demo),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (exercise.imageAssetPath.isNotEmpty)
                      ArcadeImageFilter(
                        borderRadius: BorderRadius.zero,
                        child: Image.asset(
                          exercise.imageAssetPath,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stack) =>
                              const ColoredBox(color: kCard),
                        ),
                      )
                    else
                      const ColoredBox(color: kCard),
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

                  if (_hasLoggedSets) ...[
                    PixelButton(
                      label: 'HISTORY',
                      onPressed: () => Navigator.push(
                        context,
                        arcadeRoute(
                          (_) => ExerciseHistoryPage(
                            exerciseId: exercise.id,
                            exerciseName: exercise.name,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (exercise.isCustom) ...[
                    // Custom exercise info
                    if (exercise.muscleGroup != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: kCyan),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CUSTOM',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 7,
                                color: kCyan,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            exercise.muscleGroup!.toUpperCase(),
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 12,
                            ),
                          ),
                          if (exercise.exerciseType != null) ...[
                            Text(
                              ' / ',
                              style: AppFonts.shareTechMono(
                                color: kMutedText,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              exercise.exerciseType!.toUpperCase(),
                              style: AppFonts.shareTechMono(
                                color: kMutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (exercise.userNote != null &&
                        exercise.userNote!.isNotEmpty) ...[
                      Text(
                        'NOTE',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exercise.userNote!,
                        style: AppFonts.shareTechMono(
                          textStyle: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],

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
                                color: kNeon.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: kNeon,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 8,
                                  color: kNeon,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                exercise.instructions[i],
                                style: AppFonts.shareTechMono(
                                  textStyle: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (!exercise.isCustom)
                    Text(
                      'No instructions available.',
                      style: AppFonts.shareTechMono(
                        textStyle: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),

                  // Edit/Delete for custom exercises
                  if (exercise.isCustom) ...[
                    const SizedBox(height: 24),
                    PixelButton(
                      label: 'EDIT',
                      onPressed: () async {
                        // Capture before the gap; reuse for both push and pop.
                        final navigator = Navigator.of(context);
                        final edited = await navigator.push<bool>(
                          arcadeRoute(
                            (_) => CreateExercisePage(exercise: exercise),
                          ),
                        );
                        if (edited == true && mounted) {
                          navigator.pop(true);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => _confirmDelete(context, exercise),
                      style: FilledButton.styleFrom(
                        backgroundColor: kDanger,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'DELETE',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                          color: kBg,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
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
          color: widget.isFavorite ? kDanger : kMutedText,
          size: 24,
        ),
      ),
      style: IconButton.styleFrom(backgroundColor: kBg.withValues(alpha: 0.7)),
    );
  }
}

/// Small `⤢` pill beside the FORM DEMO tag — opens the fullscreen viewer.
class _ExpandDemoPill extends StatelessWidget {
  const _ExpandDemoPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kBg.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder, width: 1),
        ),
        child: const ImageIcon(
          AssetImage('assets/icons/control/icon_expand.png'),
          color: kMutedText,
          size: 13,
        ),
      ),
    );
  }
}
