import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('radar_readability_score.dart', () {
    test('rejects a single perfect receipt as insufficient evidence', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(dir, participantIndex: 1);

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(result.stdout, contains('Participants: 1'));
      expect(result.stdout, contains('Accuracy: 100.0% (9 / 9)'));
      expect(result.stdout, contains('Minimum participants: 5'));
      expect(result.stdout, contains('Evidence count: TOO SMALL'));
      expect(result.stdout, contains('Status: FAIL'));
    });

    test('passes five strict receipts above the accuracy threshold', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipts = [
        for (var i = 1; i <= 5; i++) _writeReceipt(dir, participantIndex: i),
      ];
      final report = File('${dir.path}/report.md');

      final result = await _runScorer([
        for (final receipt in receipts) receipt.path,
        '--write-report',
        report.path,
      ]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Participants: 5'));
      expect(result.stdout, contains('Trials: 45'));
      expect(result.stdout, contains('Minimum participants: 5'));
      expect(result.stdout, contains('Evidence count: OK'));
      expect(result.stdout, contains('Status: PASS'));
      expect(report.existsSync(), isTrue);
      final reportText = report.readAsStringSync();
      expect(reportText, contains('# Ironbit Radar Readability Result'));
      expect(reportText, contains('- Mode: radar_only_v1'));
      expect(reportText, contains('- Participants: 5'));
      expect(reportText, contains('- Status: PASS'));
    });

    test('rejects duplicate participant IDs', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipts = [
        for (var i = 1; i <= 5; i++)
          _writeReceipt(
            dir,
            participantIndex: i,
            participantId: i <= 2 ? 'P_DUPLICATE' : 'P$i',
          ),
      ];

      final result = await _runScorer([
        for (final receipt in receipts) receipt.path,
      ]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('duplicate participantId "P_DUPLICATE"'));
    });

    test('rejects duplicate radar case IDs inside a receipt', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(
        dir,
        participantIndex: 1,
        transformResponses: (responses) {
          return [
            responses.first,
            {...responses.first, 'trialIndex': 2},
            ...responses.skip(2),
          ];
        },
      );

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('duplicate caseId "A1"'));
    });

    test('rejects receipts missing a radar case response', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(
        dir,
        participantIndex: 1,
        transformResponses: (responses) => responses.take(8).toList(),
      );

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('expected 9 responses, found 8'));
    });

    test('rejects receipts from a non-radar-only study mode', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(
        dir,
        participantIndex: 1,
        mode: 'app_cues_v1',
      );

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('expected mode "radar_only_v1"'));
    });

    test('rejects receipts with a stale protocol hash', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(
        dir,
        participantIndex: 1,
        protocolHash: '00000000',
      );

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('expected protocolHash'));
    });

    test('rejects receipts shorter than the required exposure time', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(
        dir,
        participantIndex: 1,
        completedAt: '2026-06-02T00:00:10.000Z',
      );

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('shorter than the required 45000ms'));
    });

    test('rejects receipts with mismatched top-level totals', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(
        dir,
        participantIndex: 1,
        topLevelCorrect: 0,
      );

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('top-level correct expected 9'));
    });

    test('rejects receipts with a short per-trial radar exposure', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(
        dir,
        participantIndex: 1,
        transformResponses: (responses) {
          return [
            {...responses.first, 'radarExposureMs': 1000},
            ...responses.skip(1),
          ];
        },
      );

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(
        result.stderr,
        contains('response must include radarExposureMs >= 4900ms'),
      );
    });

    test('rejects receipts with out-of-order trial indices', () async {
      final dir = await Directory.systemTemp.createTemp('radar_score_test_');
      addTearDown(() => dir.delete(recursive: true));
      final receipt = _writeReceipt(
        dir,
        participantIndex: 1,
        transformResponses: (responses) {
          return [
            {...responses.first, 'trialIndex': 2},
            ...responses.skip(1),
          ];
        },
      );

      final result = await _runScorer([receipt.path]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('response trialIndex expected 1'));
    });
  });
}

Future<ProcessResult> _runScorer(List<String> paths) {
  return Process.run(_dartExecutable(), [
    'tool/radar_readability_score.dart',
    ...paths,
  ]);
}

String _dartExecutable() {
  final path = Platform.environment['PATH'] ?? Platform.environment['Path'];
  final candidates = Platform.isWindows
      ? ['dart.bat', 'dart.exe', 'dart']
      : ['dart'];
  if (path != null) {
    final separator = Platform.isWindows ? ';' : ':';
    for (final dir in path.split(separator)) {
      for (final candidate in candidates) {
        final file = File('${dir.trim()}${Platform.pathSeparator}$candidate');
        if (file.existsSync()) {
          return file.path;
        }
      }
    }
  }
  throw StateError('Could not find a Dart executable on PATH.');
}

File _writeReceipt(
  Directory dir, {
  required int participantIndex,
  String? participantId,
  String mode = 'radar_only_v1',
  String startedAt = '2026-06-02T00:00:00.000Z',
  String completedAt = '2026-06-02T00:01:00.000Z',
  String? protocolHash,
  int? topLevelCorrect,
  int? topLevelTotal,
  double? topLevelAccuracy,
  List<Map<String, dynamic>> Function(List<Map<String, dynamic>> responses)?
  transformResponses,
}) {
  final fixture =
      jsonDecode(File('tool/radar_readability_cases.json').readAsStringSync())
          as List<dynamic>;
  final responses = <Map<String, dynamic>>[
    for (final entry in fixture.cast<Map<String, dynamic>>().indexed)
      {
        'trialIndex': entry.$1 + 1,
        'caseId': entry.$2['id'],
        'actualClass': entry.$2['expectedClass'],
        'guess': entry.$2['expectedClass'],
        'correct': true,
        'radarExposureMs': 5000,
        'responseTimeMs': 500,
        'stats': entry.$2['stats'],
      },
  ];
  final finalResponses = transformResponses?.call(responses) ?? responses;
  final receipt = {
    'study': 'ironbit_radar_readability_v1',
    'mode': mode,
    'fixtureVersion': 'radar_readability_cases_v1_2026-06-01',
    'protocolHash': protocolHash ?? _protocolHash(fixture),
    'participantId': participantId ?? 'P$participantIndex',
    'startedAt': startedAt,
    'completedAt': completedAt,
    'exposureMs': 5000,
    'correct': topLevelCorrect ?? finalResponses.length,
    'total': topLevelTotal ?? finalResponses.length,
    'accuracy': topLevelAccuracy ?? 1.0,
    'responses': finalResponses,
  };
  final file = File('${dir.path}/participant_$participantIndex.json');
  file.writeAsStringSync(jsonEncode(receipt));
  return file;
}

String _protocolHash(List<dynamic> fixture) {
  const visibleStats = ['STR', 'AGI', 'END'];
  final caseParts = fixture
      .cast<Map<String, dynamic>>()
      .map((item) {
        final stats = item['stats'] as Map<String, dynamic>;
        final statPart = visibleStats
            .map((axis) => '$axis=${stats[axis]}')
            .join(',');
        return '${item['id']}:${item['expectedClass']}:$statPart';
      })
      .join('|');
  return _fnv1a(
    [
      'ironbit_radar_readability_v1',
      'radar_only_v1',
      'radar_readability_cases_v1_2026-06-01',
      5000,
      40,
      visibleStats.join(','),
      caseParts,
    ].join('|'),
  );
}

String _fnv1a(String text) {
  var hash = 2166136261;
  for (final codeUnit in text.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 16777619) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
