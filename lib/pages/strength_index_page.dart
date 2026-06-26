import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../services/pinned_lifts_service.dart';
import '../services/strength_trend_service.dart';
import '../services/unit_settings_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/arcade_text_field.dart';
import '../widgets/pinned_lift_card.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/strength_roster_row.dart';
import 'exercise_history_page.dart';

/// The "all lifts" strength roster — the secondary completeness net behind the
/// body-map dossier (Concept #1). Reworked into a **visual roster**: each lift is
/// a movement-pattern icon + big estimated-max + a verdict glyph (see
/// [StrengthRosterRow]). Lifts group into completeness-preserving sections
/// (NEW BESTS / RECENTLY TRAINED / REBUILDING) so nothing is buried; filter chips
/// slice by momentum; search stays a tool. Honest by construction — same Epley
/// estimate the detail chart plots, body-neutral momentum, restraint over chrome.
enum _MomentumFilter { all, rising, newBest, rebuilding }

class StrengthIndexPage extends StatefulWidget {
  const StrengthIndexPage({super.key});

  @override
  State<StrengthIndexPage> createState() => _StrengthIndexPageState();
}

class _StrengthIndexPageState extends State<StrengthIndexPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _pins = const PinnedLiftsService();
  List<StrengthTrend> _trends = const [];
  List<String> _pinnedIds = const [];
  String _query = '';
  bool _loading = true;
  _MomentumFilter _filter = _MomentumFilter.all;

  // One-time staggered entrance — fires after the first load only (never on
  // return from the detail page); reduced motion snaps it complete.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _entranceDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sessions = await WorkoutStorageService().getSessions();
    if (!mounted) return;
    final trends = StrengthTrendService.trendsFor(sessions);
    // Drop any pin whose lift no longer has a trend so a ghost pin can't
    // silently consume a slot (Codex F1).
    final pinned = await _pins.pruneTo({for (final t in trends) t.exerciseId});
    if (!mounted) return;
    setState(() {
      _trends = trends;
      _pinnedIds = pinned;
      _loading = false;
    });
    if (_entranceDone) return;
    _entranceDone = true;
    final mq = MediaQuery.of(context);
    if (mq.disableAnimations || mq.accessibleNavigation) {
      _entrance.value = 1;
    } else {
      _entrance.forward(from: 0);
    }
  }

  List<StrengthTrend> get _searched {
    if (_query.isEmpty) return _trends;
    final q = _query.toLowerCase();
    return _trends
        .where((t) => t.exerciseName.toLowerCase().contains(q))
        .toList();
  }

  bool _isRecently(StrengthMomentum m) =>
      m == StrengthMomentum.rising ||
      m == StrengthMomentum.holding ||
      m == StrengthMomentum.fresh;

  void _open(StrengthTrend trend) {
    Navigator.push(
      context,
      arcadeRoute(
        (_) => ExerciseHistoryPage(
          exerciseId: trend.exerciseId,
          exerciseName: trend.exerciseName,
        ),
      ),
    ).then((_) => _load());
  }

  bool _isPinned(String id) => _pinnedIds.contains(id);

  Future<void> _togglePin(StrengthTrend t) async {
    final result = await _pins.toggle(t.exerciseId);
    if (!mounted) return;
    if (result == PinResult.atCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${PinnedLiftsService.maxPins} pins max — unpin one first',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    HapticService.instance.selection();
    final pinned = await _pins.getPinnedIds();
    if (!mounted) return;
    setState(() => _pinnedIds = pinned);
  }

  Future<void> _unpin(StrengthTrend t) async {
    await _pins.unpin(t.exerciseId);
    HapticService.instance.selection();
    final pinned = await _pins.getPinnedIds();
    if (!mounted) return;
    setState(() => _pinnedIds = pinned);
  }

  /// Pinned lifts that match the current search, in pin order.
  List<StrengthTrend> _pinnedTrends(List<StrengthTrend> searched) {
    final byId = {for (final t in searched) t.exerciseId: t};
    return [
      for (final id in _pinnedIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STRENGTH')),
      body: _loading
          ? const Center(child: PixelLoader())
          : _trends.isEmpty
          ? const _EmptyNote(
              text: 'Log a weighted set on any exercise to\n'
                  'start tracking your strength.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kSpace2),
                _FilterChips(
                  active: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kSpace4,
                    kSpace3,
                    kSpace4,
                    kSpace2,
                  ),
                  child: ArcadeTextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: AppFonts.shareTechMono(color: kText, fontSize: 14),
                    hintText: 'Search exercises',
                    hintStyle: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_sharp, color: kMutedText),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_sharp,
                                color: kMutedText),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace1),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'EST. MAX · ${Units.weight.label.toUpperCase()}',
                      style: AppFonts.shareTechMono(color: kDim, fontSize: 9),
                    ),
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
    );
  }

  Widget _body() {
    final searched = _searched;
    if (searched.isEmpty) {
      return _EmptyNote(text: 'No exercises match "$_query".');
    }
    return _filter == _MomentumFilter.all
        ? _sectioned(searched)
        : _flat(searched);
  }

  String _pinLabel(StrengthTrend t) => _isPinned(t.exerciseId)
      ? 'Unpin ${t.exerciseName}'
      : 'Pin ${t.exerciseName} to top';

  StrengthRosterRow _row(StrengthTrend t) => StrengthRosterRow(
    trend: t,
    onTap: () => _open(t),
    onLongPress: () => _togglePin(t),
    longPressLabel: _pinLabel(t),
  );

  /// The default ALL view — pinned anchor cards on top, then
  /// completeness-preserving sections (pinned lifts pulled out, every other lift
  /// in exactly one). Empty sections are dropped.
  Widget _sectioned(List<StrengthTrend> searched) {
    final pinnedSet = _pinnedIds.toSet();
    final pinned = _pinnedTrends(searched);
    final rest = searched
        .where((t) => !pinnedSet.contains(t.exerciseId))
        .toList();

    final newBests =
        rest.where((t) => t.momentum == StrengthMomentum.newBest).toList();
    final recently = rest.where((t) => _isRecently(t.momentum)).toList();
    final rebuilding = rest
        .where((t) => t.momentum == StrengthMomentum.rebuilding)
        .toList();

    final children = <Widget>[_PinnedStatus(count: _pinnedIds.length)];
    var i = 0;
    for (final t in pinned) {
      children.add(
        _Entrance(
          listenable: _entrance,
          index: i++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: kSpace2),
            child: PinnedLiftCard(
              trend: t,
              onTap: () => _open(t),
              onUnpin: () => _unpin(t),
            ),
          ),
        ),
      );
    }
    void section(String title, Color color, List<StrengthTrend> items) {
      if (items.isEmpty) return;
      children.add(_SectionHeader(title: title, color: color, count: items.length));
      for (final t in items) {
        children.add(
          _Entrance(
            listenable: _entrance,
            index: i++,
            child: Padding(
              padding: const EdgeInsets.only(bottom: kSpace2),
              child: _row(t),
            ),
          ),
        );
      }
    }

    section('NEW BESTS', kAmber, newBests);
    section('RECENTLY TRAINED', kMutedText, recently);
    section('REBUILDING · A LOOK', kMutedText, rebuilding);

    return ListView(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace1, kSpace4, kSpace5),
      children: children,
    );
  }

  /// A single-momentum chip view — a flat slice (no pinned cards, no headers);
  /// a pinned lift appears here as a normal row so the slice stays truthful.
  Widget _flat(List<StrengthTrend> searched) {
    final wanted = switch (_filter) {
      _MomentumFilter.rising => StrengthMomentum.rising,
      _MomentumFilter.newBest => StrengthMomentum.newBest,
      _MomentumFilter.rebuilding => StrengthMomentum.rebuilding,
      _MomentumFilter.all => null,
    };
    final items = searched.where((t) => t.momentum == wanted).toList();
    if (items.isEmpty) {
      return _EmptyNote(text: switch (_filter) {
        _MomentumFilter.rising => 'No lifts on the rise right now.\n'
            'Beat a recent set to light one up.',
        _MomentumFilter.newBest => 'No new bests yet.\n'
            'Your next PR will land here.',
        _MomentumFilter.rebuilding => 'Nothing rebuilding — nice.\n'
            'Down steps show up here, kindly.',
        _MomentumFilter.all => '',
      });
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace1, kSpace4, kSpace5),
      itemCount: items.length,
      itemBuilder: (_, i) => _Entrance(
        listenable: _entrance,
        index: i,
        child: Padding(
          padding: const EdgeInsets.only(bottom: kSpace2),
          child: _row(items[i]),
        ),
      ),
    );
  }
}

/// The pinned-anchor status + persistent pin hint (so the long-press affordance
/// never goes fully hidden — it shows the count and how to add/swap). ALL view.
class _PinnedStatus extends StatelessWidget {
  const _PinnedStatus({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const max = PinnedLiftsService.maxPins;
    final text = count == 0
        ? 'Hold a lift to pin it to the top'
        : count < max
        ? 'PINNED $count/$max · hold a lift to add'
        : 'PINNED $count/$max · unpin one to swap';
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace1, kSpace1, kSpace1, kSpace3),
      child: Row(
        children: [
          const Icon(Icons.push_pin_sharp, size: 13, color: kCyan),
          const SizedBox(width: kSpace2),
          Expanded(
            child: Text(
              text,
              style: AppFonts.shareTechMono(color: kDim, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Momentum filter chips. Each chip's colour pre-echoes its section accent;
/// selected = filled, unselected = outline. Body-neutral (no danger red).
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.active, required this.onChanged});

  final _MomentumFilter active;
  final ValueChanged<_MomentumFilter> onChanged;

  static const _defs = [
    (_MomentumFilter.all, 'ALL', kNeon),
    (_MomentumFilter.rising, 'RISING', kNeon),
    (_MomentumFilter.newBest, 'NEW', kAmber),
    (_MomentumFilter.rebuilding, 'REBUILDING', kMutedText),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kSpace4),
        children: [
          for (final (filter, label, color) in _defs) ...[
            _Chip(
              label: label,
              color: color,
              selected: active == filter,
              onTap: () => onChanged(filter),
            ),
            const SizedBox(width: kSpace2),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: kSpace3),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            border: Border.all(color: selected ? color : kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              color: selected ? kBg : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.color,
    required this.count,
  });

  final String title;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace1, kSpace3, kSpace1, kSpace2),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              letterSpacing: 1,
              color: color,
            ),
          ),
          const SizedBox(width: kSpace2),
          Text(
            '$count',
            style: AppFonts.shareTechMono(color: kDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// One-time fade+slide entrance, staggered by [index]. Compositor-only
/// (opacity + translate); reduced motion returns the child unanimated.
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.listenable,
    required this.index,
    required this.child,
  });

  final Animation<double> listenable;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final start = (index * 0.05).clamp(0.0, 0.6).toDouble();
    final curve = CurvedAnimation(
      parent: listenable,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: kMotionCurve),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, c) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * 8),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpace5),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
        ),
      ),
    );
  }
}
