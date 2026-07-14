import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('radar_readability_audit.dart', () {
    test('artifact-only audit passes fixture and HTML checks', () async {
      final result = await _runAudit(['--artifact-only']);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Executable script syntax:'));
      expect(result.stdout, contains('Artifact checks: PASS'));
      expect(result.stdout, contains('Human receipts: SKIPPED'));
    });

    test('full audit fails without human receipts', () async {
      final result = await _runAudit([]);

      expect(result.exitCode, isNot(0));
      expect(result.stdout, contains('Artifact checks: PASS'));
      expect(result.stdout, contains('Executable script syntax:'));
      expect(result.stdout, contains('Human receipts: MISSING'));
    });

    test('full audit passes with five strict participant receipts', () async {
      final dir = await Directory.systemTemp.createTemp('radar_audit_test_');
      addTearDown(() => dir.delete(recursive: true));
      for (var i = 1; i <= 5; i++) {
        _writeReceipt(dir, participantIndex: i);
      }
      final report = File('${dir.path}/audit.md');

      final result = await _runAudit([dir.path, '--write-report', report.path]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Artifact checks: PASS'));
      expect(result.stdout, contains('Executable script syntax:'));
      expect(result.stdout, contains('Status: PASS'));
      expect(result.stdout, contains('Overall audit: PASS'));
      expect(report.existsSync(), isTrue);
    });
  });
}

Future<ProcessResult> _runAudit(List<String> args) {
  return Process.run(_dartExecutable(), [
    'tool/radar_readability_audit.dart',
    ...args,
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

File _writeReceipt(Directory dir, {required int participantIndex}) {
  final fixture =
      jsonDecode(File('tool/radar_readability_cases.json').readAsStringSync())
          as List<dynamic>;
  final responses = [
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
  final receipt = {
    'study': 'ironbit_radar_readability_v1',
    'mode': 'radar_only_v1',
    'fixtureVersion': 'radar_readability_cases_v1_2026-06-01',
    'protocolHash': _protocolHash(fixture),
    'participantId': 'P$participantIndex',
    'startedAt': '2026-06-02T00:00:00.000Z',
    'completedAt': '2026-06-02T00:01:00.000Z',
    'exposureMs': 5000,
    'correct': responses.length,
    'total': responses.length,
    'accuracy': 1.0,
    'responses': responses,
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
