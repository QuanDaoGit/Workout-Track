import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/json_safe.dart';

/// Direct contract tests for the corruption-tolerant decode helpers that guard
/// every SharedPreferences loader on the boot/home path. Previously these were
/// only covered indirectly (via storage_corruption_test exercising the loaders
/// that call them); this pins the primitive itself so a regression here is caught
/// at the source rather than only where it surfaces.
void main() {
  group('safeDecodeList', () {
    test('valid JSON array decodes through', () {
      expect(safeDecodeList('[1,2,3]'), [1, 2, 3]);
    });

    test('null / empty / malformed → const []', () {
      expect(safeDecodeList(null), isEmpty);
      expect(safeDecodeList(''), isEmpty);
      expect(safeDecodeList('}{not json'), isEmpty);
    });

    test('valid JSON that is NOT a list → []', () {
      expect(safeDecodeList('{"a":1}'), isEmpty);
      expect(safeDecodeList('42'), isEmpty);
      expect(safeDecodeList('"a string"'), isEmpty);
    });
  });

  group('safeDecodeMap', () {
    test('valid JSON object decodes to a typed map', () {
      expect(safeDecodeMap('{"a":1,"b":"x"}'), {'a': 1, 'b': 'x'});
    });

    test('null / empty / malformed → null', () {
      expect(safeDecodeMap(null), isNull);
      expect(safeDecodeMap(''), isNull);
      expect(safeDecodeMap('}{'), isNull);
    });

    test('valid JSON that is NOT a map → null', () {
      expect(safeDecodeMap('[1,2,3]'), isNull);
      expect(safeDecodeMap('7'), isNull);
    });
  });

  group('safeMapList — per-record salvage', () {
    // A model that only parses maps carrying an int 'id'.
    _Item parse(Map<String, dynamic> m) => _Item(m['id'] as int);

    test('maps every well-formed record', () {
      final out = safeMapList(jsonEncode([{'id': 1}, {'id': 2}]), parse);
      expect(out.map((e) => e.id), [1, 2]);
    });

    test('skips individual corrupt records, keeps the salvageable subset', () {
      // One good map, one map missing the required field (throws in parse), one
      // non-map element — only the good record survives, no throw.
      final blob = jsonEncode([
        {'id': 1},
        {'nope': true}, // missing id → parse throws (null cast)
        {'id': 'oops'}, // id present but wrong type → parse ITSELF throws,
        //                 so this only salvages if fromJson is actually run
        //                 per-record (a naive `id is int` pre-filter would also
        //                 skip it, but the {'nope':true} + this together pin the
        //                 real per-record try/catch).
        'garbage', // not a map → skipped before parse
        {'id': 2},
      ]);
      final out = safeMapList(blob, parse);
      expect(out.map((e) => e.id), [1, 2]);
    });

    test('whole-blob corruption / null → []', () {
      expect(safeMapList('}{not json', parse), isEmpty);
      expect(safeMapList(null, parse), isEmpty);
      expect(safeMapList('{"id":1}', parse), isEmpty); // object, not a list
    });
  });
}

class _Item {
  const _Item(this.id);
  final int id;
}
