import 'package:shared_preferences/shared_preferences.dart';

/// Owns the one persisted fact behind BIT's idle-advice rotation: the last day a
/// **wildcard** line was shown. The wildcard pool is capped to at most one
/// appearance per calendar day (see [bitRoomWildcardAdvice] /
/// [pickRoomAdvice] in `data/bit_room_copy.dart`); this survives across app
/// restarts so the cap holds for the whole day, not just one session.
///
/// Everything else about advice (which regular line, the 5% weighting roll) is
/// ephemeral UI state owned by the home page — only the daily cap needs to last.
class BitAdviceService {
  BitAdviceService({DateTime Function()? nowProvider})
      : _now = nowProvider ?? DateTime.now;

  final DateTime Function() _now;

  /// Last calendar day (local) a wildcard advice line was shown.
  static const String _wildcardDayKey = 'bit_room_wildcard_day_v1';

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// True when a wildcard has already been shown today — i.e. the day's single
  /// wildcard slot is spent and further draws must fall back to the regular pool.
  Future<bool> wasWildcardShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_wildcardDayKey);
    return stored != null && stored == _dayKey(_now());
  }

  /// Records that a wildcard line was shown today, spending the daily slot.
  Future<void> markWildcardShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wildcardDayKey, _dayKey(_now()));
  }
}
