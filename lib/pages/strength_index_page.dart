import 'package:flutter/material.dart';

import '../services/strength_trend_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/motion/arcade_text_field.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/strength_momentum_row.dart';
import 'exercise_history_page.dart';

/// The "all lifts" strength roster — the secondary completeness net behind the
/// body-map strength dossier (Concept #1): every lift you've trained with
/// weights, most-recently-trained first, each a [StrengthMomentumRow] → the full
/// [ExerciseHistoryPage] trend. Reached from the body map's "ALL LIFTS" route
/// (not a primary destination); search is a tool here, not the entry. Honest by
/// construction — same Epley estimate the detail chart plots, plain-language
/// verdict (no "e1RM"), body-neutral momentum.
class StrengthIndexPage extends StatefulWidget {
  const StrengthIndexPage({super.key});

  @override
  State<StrengthIndexPage> createState() => _StrengthIndexPageState();
}

class _StrengthIndexPageState extends State<StrengthIndexPage> {
  final _searchController = TextEditingController();
  List<StrengthTrend> _trends = const [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sessions = await WorkoutStorageService().getSessions();
    if (!mounted) return;
    setState(() {
      _trends = StrengthTrendService.trendsFor(sessions);
      _loading = false;
    });
  }

  List<StrengthTrend> get _filtered {
    if (_query.isEmpty) return _trends;
    final q = _query.toLowerCase();
    return _trends
        .where((t) => t.exerciseName.toLowerCase().contains(q))
        .toList();
  }

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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('STRENGTH')),
      body: _loading
          ? const Center(child: PixelLoader())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kSpace4,
                    kSpace3,
                    kSpace4,
                    kSpace2,
                  ),
                  child: Text(
                    'EVERY LIFT · MOST RECENT FIRST',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (_trends.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace2),
                    child: ArcadeTextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      style: AppFonts.shareTechMono(color: kText, fontSize: 14),
                      hintText: 'Search exercises',
                      hintStyle:
                          AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
                      prefixIcon:
                          const Icon(Icons.search_sharp, color: kMutedText),
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
                Expanded(child: _body(filtered)),
              ],
            ),
    );
  }

  Widget _body(List<StrengthTrend> filtered) {
    if (_trends.isEmpty) {
      return const _EmptyNote(
        text: 'Log a weighted set on any exercise to\n'
            'start tracking your strength.',
      );
    }
    if (filtered.isEmpty) {
      return _EmptyNote(text: 'No exercises match "$_query".');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace1, kSpace4, kSpace5),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: kSpace2),
      itemBuilder: (_, i) => StrengthMomentumRow(
        trend: filtered[i],
        onTap: () => _open(filtered[i]),
      ),
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
