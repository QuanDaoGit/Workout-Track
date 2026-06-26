import 'package:shared_preferences/shared_preferences.dart';

/// Outcome of a pin attempt — drives the UI feedback (e.g. the at-capacity
/// "unpin one first" notice).
enum PinResult { pinned, unpinned, alreadyPinned, atCapacity, notPinned }

/// User-pinned "anchor lifts" for the strength roster — up to [maxPins], stored
/// as an **ordered** list of exercise ids (mirrors `FavoriteService`'s
/// StringList shape). Pinning is a shortcut, never a demotion: a pinned lift
/// still exists, it just also surfaces as a card at the top of the roster.
///
/// A 4th pin is **blocked** (`atCapacity`) rather than auto-evicting the oldest —
/// the user must unpin one first.
class PinnedLiftsService {
  const PinnedLiftsService();

  static const String _key = 'pinned_lift_ids_v1';
  static const int maxPins = 3;

  /// The pinned ids in pin order — deduped, empties dropped, clamped to
  /// [maxPins] defensively.
  Future<List<String>> getPinnedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return _clean(prefs.getStringList(_key));
  }

  List<String> _clean(List<String>? raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final id in raw ?? const <String>[]) {
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
      if (out.length >= maxPins) break;
    }
    return out;
  }

  Future<bool> isPinned(String id) async =>
      (await getPinnedIds()).contains(id);

  /// Pins [id] at the end. Returns [PinResult.alreadyPinned] if already pinned,
  /// [PinResult.atCapacity] if [maxPins] are already pinned.
  Future<PinResult> pin(String id) async {
    if (id.isEmpty) return PinResult.notPinned;
    final ids = await getPinnedIds();
    if (ids.contains(id)) return PinResult.alreadyPinned;
    if (ids.length >= maxPins) return PinResult.atCapacity;
    await _save([...ids, id]);
    return PinResult.pinned;
  }

  Future<PinResult> unpin(String id) async {
    final ids = await getPinnedIds();
    if (!ids.contains(id)) return PinResult.notPinned;
    await _save(ids.where((e) => e != id).toList());
    return PinResult.unpinned;
  }

  Future<PinResult> toggle(String id) async =>
      (await isPinned(id)) ? unpin(id) : pin(id);

  /// Drops any stored pin whose id is **not** in [existing] (a lift whose
  /// sessions were deleted, or a renamed/removed id) and persists the survivors,
  /// so a ghost pin can never silently consume a slot with no way to clear it.
  /// Returns the surviving pins (in order).
  Future<List<String>> pruneTo(Set<String> existing) async {
    final ids = await getPinnedIds();
    final kept = ids.where(existing.contains).toList();
    if (kept.length != ids.length) await _save(kept);
    return kept;
  }

  Future<void> _save(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setStringList(_key, ids);
    }
  }
}
