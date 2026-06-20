import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Corruption-tolerant decoding for the JSON blobs every service stores in
/// SharedPreferences. A loader that calls `jsonDecode` directly throws on a
/// malformed or schema-drifted blob — and because these loaders run on the
/// boot/home path (e.g. `getSessions()` in `HomePageState._loadData`), an
/// unguarded throw can stop the home screen from rendering at all. These helpers
/// return a typed fallback instead, so a bad blob degrades to empty/last-good
/// rather than a crash.

/// Decodes a JSON array, returning `const []` for null/empty/malformed input or
/// a payload that isn't a list.
List<dynamic> safeDecodeList(String? raw, {String? debugLabel}) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    return const [];
  } catch (e) {
    debugPrint('safeDecodeList(${debugLabel ?? '?'}) failed: $e');
    return const [];
  }
}

/// Decodes a JSON object, returning `null` for null/empty/malformed input or a
/// payload that isn't a map.
Map<String, dynamic>? safeDecodeMap(String? raw, {String? debugLabel}) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  } catch (e) {
    debugPrint('safeDecodeMap(${debugLabel ?? '?'}) failed: $e');
    return null;
  }
}

/// Decodes a JSON array of objects and maps each element through [fromJson] in
/// its **own** guard, so a single corrupt record is skipped rather than dropping
/// the whole collection. Returns the salvageable subset.
List<T> safeMapList<T>(
  String? raw,
  T Function(Map<String, dynamic>) fromJson, {
  String? debugLabel,
}) {
  final out = <T>[];
  for (final item in safeDecodeList(raw, debugLabel: debugLabel)) {
    if (item is! Map) continue;
    try {
      out.add(fromJson(Map<String, dynamic>.from(item)));
    } catch (e) {
      debugPrint('safeMapList(${debugLabel ?? '?'}) skipped a record: $e');
    }
  }
  return out;
}
