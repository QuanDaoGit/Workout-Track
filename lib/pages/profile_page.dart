import 'package:flutter/material.dart';

import '../models/quest_models.dart';
import '../services/quest_service.dart';
import '../services/workout_storage_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onTitleChanged});

  final VoidCallback? onTitleChanged;

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final QuestService _questService = QuestService();
  bool _loading = true;
  QuestSummary? _summary;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final sessions = await WorkoutStorageService().getSessions();
    final summary = await _questService.getSummary(sessions);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _selectTitle(String title) async {
    await _questService.selectTitle(title);
    await reload();
    widget.onTitleChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final summary = _summary!;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ImageIcon(
                    AssetImage('assets/icons/control/icon_character.png'),
                    size: 36,
                    color: Color(0xFF00FF9C),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.selectedTitle ?? 'No active title',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: Color(0xFFE8E8FF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Titles are earned from Side Quests.',
                          style: TextStyle(
                            color: Color(0xFFAAA8C0),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('TITLES', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (summary.earnedTitles.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    ImageIcon(
                      AssetImage('assets/icons/control/icon_lock.png'),
                      size: 20,
                      color: Color(0xFF6B6B8A),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Claim Side Quest rewards to unlock titles.',
                        style: TextStyle(
                          color: Color(0xFFAAA8C0),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final title in summary.earnedTitles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: InkWell(
                    onTap: () => _selectTitle(title),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          ImageIcon(
                            AssetImage(
                              summary.selectedTitle == title
                                  ? 'assets/icons/control/icon_star.png'
                                  : 'assets/icons/control/icon_shield.png',
                            ),
                            color: summary.selectedTitle == title
                                ? const Color(0xFFFFD700)
                                : const Color(0xFF6B6B8A),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Color(0xFFE8E8FF),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Side Quest title',
                                  style: TextStyle(
                                    color: Color(0xFFAAA8C0),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (summary.selectedTitle == title)
                            const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                color: Color(0xFF00FF9C),
                                fontSize: 8,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
