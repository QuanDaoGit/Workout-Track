class EnemyData {
  const EnemyData({
    required this.id,
    required this.name,
    required this.tier,
    required this.baseSTR,
    required this.baseDEF,
    required this.baseVIT,
    required this.baseAGI,
  });

  final String id;
  final String name;
  final int tier;
  final int baseSTR;
  final int baseDEF;
  final int baseVIT;
  final int baseAGI;

  /// Returns a scaled copy of this enemy for the given floor.
  /// If [isBoss] is true, base stats are multiplied by 1.5 before scaling.
  EnemyData scaledForFloor(int floor, {bool isBoss = false}) {
    final multiplier = isBoss ? 1.5 : 1.0;
    return EnemyData(
      id: id,
      name: isBoss ? 'BOSS: $name' : name,
      tier: tier,
      baseSTR: (baseSTR * multiplier).floor() + floor * 15,
      baseDEF: (baseDEF * multiplier).floor() + floor * 15,
      baseVIT: (baseVIT * multiplier).floor() + floor * 15,
      baseAGI: (baseAGI * multiplier).floor() + floor * 15,
    );
  }

  int get hp => baseVIT * 3;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tier': tier,
    'baseSTR': baseSTR,
    'baseDEF': baseDEF,
    'baseVIT': baseVIT,
    'baseAGI': baseAGI,
  };

  factory EnemyData.fromJson(Map<String, dynamic> json) => EnemyData(
    id: json['id'] as String,
    name: json['name'] as String,
    tier: json['tier'] as int,
    baseSTR: json['baseSTR'] as int,
    baseDEF: json['baseDEF'] as int,
    baseVIT: json['baseVIT'] as int,
    baseAGI: json['baseAGI'] as int,
  );
}
