import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('radar_readability_report.dart summarizes automated evidence', () async {
    final dir = await Directory.systemTemp.createTemp('radar_report_test_');
    addTearDown(() => dir.delete(recursive: true));
    final report = File('${dir.path}/report.md');

    final result = await Process.run(_dartExecutable(), [
      'tool/radar_readability_report.dart',
      report.path,
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(report.existsSync(), isTrue);
    final text = report.readAsStringSync();
    expect(text, contains('# Ironbit Radar Readability Evidence'));
    expect(text, contains('- Visible axes: STR, AGI, END'));
    expect(text, contains('- Proxy classifier accuracy: 100.0% (9 / 9)'));
    expect(text, contains('- Distinct class tops: PASS'));
    expect(text, contains('- No visible dead stat: PASS'));
    expect(text, contains('| A1 | ASSASSIN | AGI | ASSASSIN |'));
    expect(text, contains('| B1 | BRUISER | STR | BRUISER |'));
    expect(text, contains('| T1 | TANK | END | TANK |'));
  });
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
