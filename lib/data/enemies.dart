import '../models/enemy_data.dart';

const enemyRoster = [
  EnemyData(
    id: 'shadow_rat',
    name: 'Shadow Rat',
    tier: 1,
    baseSTR: 80,
    baseDEF: 40,
    baseVIT: 60,
    baseAGI: 30,
  ),
  EnemyData(
    id: 'iron_golem',
    name: 'Iron Golem',
    tier: 2,
    baseSTR: 120,
    baseDEF: 100,
    baseVIT: 150,
    baseAGI: 10,
  ),
  EnemyData(
    id: 'wraith_knight',
    name: 'Wraith Knight',
    tier: 3,
    baseSTR: 150,
    baseDEF: 80,
    baseVIT: 120,
    baseAGI: 60,
  ),
];

/// Returns the base enemy archetype for the given floor.
EnemyData enemyForFloor(int floor) {
  final index = ((floor - 1) ~/ 10) % enemyRoster.length;
  return enemyRoster[index];
}

/// Returns the fully scaled enemy for the given floor, including boss check.
EnemyData scaledEnemyForFloor(int floor) {
  final base = enemyForFloor(floor);
  final isBoss = floor % 10 == 0;
  return base.scaledForFloor(floor, isBoss: isBoss);
}
