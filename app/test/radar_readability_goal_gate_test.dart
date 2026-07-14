import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('radar_readability_goal_gate.dart', () {
    test('dry run prints automated tests and audit command', () async {
      final result = await Process.run(_dartExecutable(), [
        'tool/radar_readability_goal_gate.dart',
        '--dry-run',
        '--artifact-only',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Mode: artifact-only'));
      expect(result.stdout, contains('test/stat_engine_test.dart'));
      expect(result.stdout, contains('test/stat_card_widget_test.dart'));
      expect(result.stdout, contains('test/stat_radar_read_test.dart'));
      expect(
        result.stdout,
        contains('test/radar_readability_study_script_test.dart'),
      );
      expect(
        result.stdout,
        contains('tool/radar_readability_audit.dart --artifact-only'),
      );
    });
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
