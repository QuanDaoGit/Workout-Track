import 'package:flutter/material.dart';

import 'home.dart';
import 'profile_page.dart';
import 'quests_page.dart';
import 'workout_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _currentIndex = 0;

  final _homeKey = GlobalKey<HomePageState>();
  final _workoutKey = GlobalKey<WorkoutPageState>();
  final _questsKey = GlobalKey<QuestsPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();

  void _selectTab(int index) {
    if (index == 0) _homeKey.currentState?.reload();
    if (index == 1) _workoutKey.currentState?.reload();
    if (index == 2) _questsKey.currentState?.reload();
    if (index == 3) _profileKey.currentState?.reload();
    setState(() => _currentIndex = index);
  }

  void _reloadQuestAwarePages() {
    _homeKey.currentState?.reload();
    _workoutKey.currentState?.reload();
    _questsKey.currentState?.reload();
    _profileKey.currentState?.reload();
  }

  late final List<Widget> _pages = [
    HomePage(
      key: _homeKey,
      onViewQuests: () => _selectTab(2),
      onViewProfile: () => _selectTab(3),
    ),
    WorkoutPage(key: _workoutKey),
    QuestsPage(key: _questsKey, onQuestChanged: _reloadQuestAwarePages),
    ProfilePage(key: _profileKey, onProfileChanged: _reloadQuestAwarePages),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _selectTab,
        items: const [
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/icons/control/icon_map.png')),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/icons/control/icon_sword.png')),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/icons/control/icon_scroll.png')),
            label: 'Quests',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage('assets/icons/control/icon_character.png'),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
