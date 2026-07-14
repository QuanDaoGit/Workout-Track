import 'dart:io';

const _automatedTests = [
  'test/stat_engine_test.dart',
  'test/stat_card_widget_test.dart',
  'test/stat_radar_read_test.dart',
  'test/radar_readability_study_script_test.dart',
];

void main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    exitCode = 64;
    return;
  }

  final flutter = _findExecutable(
    Platform.isWindows
        ? ['flutter.bat', 'flutter.exe', 'flutter']
        : ['flutter'],
  );
  if (flutter == null) {
    stderr.writeln('Could not find flutter on PATH.');
    exitCode = 69;
    return;
  }

  final dart = _findExecutable(
    Platform.isWindows ? ['dart.bat', 'dart.exe', 'dart'] : ['dart'],
  );
  if (dart == null) {
    stderr.writeln('Could not find dart on PATH.');
    exitCode = 69;
    return;
  }

  final testCommand = _Command(flutter, ['test', ..._automatedTests]);
  final auditCommand = _Command(dart, [
    'tool/radar_readability_audit.dart',
    ...options.receiptInputs,
    if (options.artifactOnly) '--artifact-only',
    if (options.reportPath != null) ...['--write-report', options.reportPath!],
  ]);

  final lines = <String>[
    'Ironbit radar readability goal gate',
    'Mode: ${options.artifactOnly ? 'artifact-only' : 'full'}',
    'Automated test files:',
    for (final test in _automatedTests) '- $test',
    'Audit inputs: '
        '${options.receiptInputs.isEmpty ? '(none)' : options.receiptInputs.join(', ')}',
    '',
  ];

  if (options.dryRun) {
    lines
      ..add('Dry run commands:')
      ..add('- ${testCommand.display}')
      ..add('- ${auditCommand.display}');
    stdout.writeln(lines.join('\n'));
    exitCode = 0;
    return;
  }

  stdout.writeln(lines.join('\n'));

  final testResult = await _runStep(
    label: 'Automated engine/UI proxy',
    command: testCommand,
  );
  final auditResult = await _runStep(
    label: options.artifactOnly
        ? 'Artifact audit'
        : 'Artifact + human receipt audit',
    command: auditCommand,
  );

  final pass = testResult && auditResult;
  stdout.writeln('');
  stdout.writeln('Goal gate: ${pass ? 'PASS' : 'FAIL'}');
  if (options.artifactOnly) {
    stdout.writeln(
      'Human receipts were skipped. This is not enough to complete the goal.',
    );
  }
  exitCode = pass ? 0 : 1;
}

Future<bool> _runStep({
  required String label,
  required _Command command,
}) async {
  stdout.writeln('== $label ==');
  stdout.writeln(command.display);
  final result = await Process.run(command.executable, command.args);
  final out = (result.stdout as String).trimRight();
  final err = (result.stderr as String).trimRight();
  if (out.isNotEmpty) stdout.writeln(out);
  if (err.isNotEmpty) stderr.writeln(err);
  final pass = result.exitCode == 0;
  stdout.writeln('$label: ${pass ? 'PASS' : 'FAIL'}');
  stdout.writeln('');
  return pass;
}

_GateOptions? _parseArgs(List<String> args) {
  var artifactOnly = false;
  var dryRun = false;
  String? reportPath;
  final receiptInputs = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--artifact-only') {
      artifactOnly = true;
    } else if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--write-report') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing path after --write-report.');
        return null;
      }
      reportPath = args[++i];
    } else if (arg.startsWith('--write-report=')) {
      reportPath = arg.substring('--write-report='.length);
      if (reportPath.isEmpty) {
        stderr.writeln('Missing path after --write-report=.');
        return null;
      }
    } else if (arg.startsWith('--')) {
      stderr.writeln('Unknown option: $arg');
      return null;
    } else {
      receiptInputs.add(arg);
    }
  }
  return _GateOptions(
    artifactOnly: artifactOnly,
    dryRun: dryRun,
    reportPath: reportPath,
    receiptInputs: receiptInputs,
  );
}

String? _findExecutable(List<String> candidates) {
  final path = Platform.environment['PATH'] ?? Platform.environment['Path'];
  if (path == null) return null;
  final separator = Platform.isWindows ? ';' : ':';
  for (final dir in path.split(separator)) {
    final trimmed = dir.trim();
    if (trimmed.isEmpty) continue;
    for (final candidate in candidates) {
      final file = File('$trimmed${Platform.pathSeparator}$candidate');
      if (file.existsSync()) return file.path;
    }
  }
  return null;
}

class _Command {
  const _Command(this.executable, this.args);

  final String executable;
  final List<String> args;

  String get display => ([executable, ...args]).join(' ');
}

class _GateOptions {
  const _GateOptions({
    required this.artifactOnly,
    required this.dryRun,
    required this.reportPath,
    required this.receiptInputs,
  });

  final bool artifactOnly;
  final bool dryRun;
  final String? reportPath;
  final List<String> receiptInputs;
}
