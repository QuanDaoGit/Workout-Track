/// ISO-8601 week key (e.g. "2026-W22") for a given date — the canonical weekly
/// bucket used across Ironbit (the Adventure weekly cap, Home weekly rollups).
///
/// Relocated out of the (removed) guild feature so weekly logic stays available
/// independently of any social code. Pure, UTC-normalized, deterministic.
String isoWeekKey(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final firstThursdayYear = thursday.year;
  final firstJan = DateTime.utc(firstThursdayYear, 1, 1);
  final week = 1 + (thursday.difference(firstJan).inDays ~/ 7);
  return '$firstThursdayYear-W${week.toString().padLeft(2, '0')}';
}
