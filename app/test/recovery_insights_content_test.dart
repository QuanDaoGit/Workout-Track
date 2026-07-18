import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/recovery_insights.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pool is big enough for months of rest days', () {
    expect(recoveryInsights.length, greaterThanOrEqualTo(30));
  });

  test('ids are unique and stable-looking', () {
    final ids = recoveryInsights.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(RegExp(r'^[a-z0-9_]+$').hasMatch(id), isTrue,
          reason: 'id "$id" must be snake_case');
    }
  });

  test('every insight has a valid category and non-empty text', () {
    for (final i in recoveryInsights) {
      expect(kRecoveryInsightCategories.contains(i.category), isTrue,
          reason: '"${i.id}" has unknown category "${i.category}"');
      expect(i.text.trim(), isNotEmpty);
      expect(i.text.length, lessThanOrEqualTo(220),
          reason: '"${i.id}" is too long for a glance surface');
    }
  });

  test('every category has an icon (and no orphan icon entries)', () {
    expect(kRecoveryInsightCategoryIcons.keys.toSet(),
        kRecoveryInsightCategories.toSet());
  });

  // Codex F8: a typo'd or undeclared asset path fails at runtime when the
  // sheet opens; loading every icon here catches it at test time instead.
  test('every category icon asset exists in the bundle', () async {
    for (final path in kRecoveryInsightCategoryIcons.values) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });

  test('guardrails: no streak/guilt/body framing anywhere in the pool', () {
    // The spec bans copy that frames rest as risk, debt, or body outcome.
    const banned = [
      'streak',
      'calorie',
      'weight',
      'burn',
      "don't skip",
      'lose momentum',
      'fall behind',
      // Codex F7: prescriptive-language markers — advice stays descriptive,
      // never a directive or a medical prescription.
      'you should',
      'you must',
    ];
    for (final i in recoveryInsights) {
      final t = i.text.toLowerCase();
      for (final word in banned) {
        expect(t.contains(word), isFalse,
            reason: '"${i.id}" contains banned word "$word"');
      }
    }
  });
}
