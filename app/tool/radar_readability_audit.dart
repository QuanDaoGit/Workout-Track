import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:workout_track/models/stat_radar_read.dart';

const _studyId = 'ironbit_radar_readability_v1';
const _studyMode = 'radar_only_v1';
const _fixtureVersion = 'radar_readability_cases_v1_2026-06-01';
const _fixturePath = 'tool/radar_readability_cases.json';
const _studyHtmlPath = 'tool/radar_readability_study.html';
const _expectedExposureMs = 5000;
const _expectedCaseCount = 9;

void main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    exitCode = 64;
    return;
  }

  final failures = <String>[];
  final artifactNotes = <String>[];
  final fixture = _loadFixture(failures);
  if (fixture != null) {
    _auditFixture(fixture, failures);
    _auditStudyHtml(fixture, failures, artifactNotes);
  }

  final artifactPass = failures.isEmpty;
  final lines = <String>[
    'Ironbit radar readability audit',
    'Study: $_studyId',
    'Mode: $_studyMode',
    'Fixture: $_fixtureVersion',
    'Exposure: ${_expectedExposureMs}ms',
    'Visible axes: ${StatRadarRead.visibleStats.join(', ')}',
    'Dominant lead: ${StatRadarRead.dominantLeadThreshold}',
    ...artifactNotes,
    'Artifact checks: ${artifactPass ? 'PASS' : 'FAIL'}',
  ];
  if (failures.isNotEmpty) {
    lines
      ..add('')
      ..add('Artifact failures:');
    for (final failure in failures) {
      lines.add('- $failure');
    }
  }

  if (options.artifactOnly) {
    lines.add('Human receipts: SKIPPED (--artifact-only)');
    _writeAuditOutput(options.reportPath, lines);
    stdout.writeln(lines.join('\n'));
    exitCode = artifactPass ? 0 : 1;
    return;
  }

  if (options.receiptInputs.isEmpty) {
    lines
      ..add('Human receipts: MISSING')
      ..add(
        'Provide at least five distinct participant receipts, or use '
        '--artifact-only for fixture/HTML checks.',
      );
    _writeAuditOutput(options.reportPath, lines);
    stdout.writeln(lines.join('\n'));
    exitCode = 1;
    return;
  }

  final scoreArgs = [
    'tool/radar_readability_score.dart',
    ...options.receiptInputs,
    if (options.reportPath != null) ...['--write-report', options.reportPath!],
  ];
  final score = await Process.run(Platform.resolvedExecutable, scoreArgs);
  lines
    ..add('')
    ..add('Human receipt score:')
    ..add((score.stdout as String).trimRight());
  final stderrText = (score.stderr as String).trim();
  if (stderrText.isNotEmpty) {
    lines
      ..add('')
      ..add('Scorer stderr:')
      ..add(stderrText);
  }

  final pass = artifactPass && score.exitCode == 0;
  lines.add('');
  lines.add('Overall audit: ${pass ? 'PASS' : 'FAIL'}');
  if (options.reportPath != null && score.exitCode != 0) {
    _writeAuditOutput(options.reportPath, lines);
  }
  stdout.writeln(lines.join('\n'));
  exitCode = pass ? 0 : 1;
}

_AuditOptions? _parseArgs(List<String> args) {
  var artifactOnly = false;
  String? reportPath;
  final receiptInputs = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--artifact-only') {
      artifactOnly = true;
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
  return _AuditOptions(
    artifactOnly: artifactOnly,
    reportPath: reportPath,
    receiptInputs: receiptInputs,
  );
}

List<Map<String, dynamic>>? _loadFixture(List<String> failures) {
  final file = File(_fixturePath);
  if (!file.existsSync()) {
    failures.add('Missing fixture file: $_fixturePath');
    return null;
  }
  try {
    final raw = jsonDecode(file.readAsStringSync());
    if (raw is! List) {
      failures.add('Fixture must be a JSON list.');
      return null;
    }
    return raw.cast<Map<String, dynamic>>();
  } on Object catch (error) {
    failures.add('Fixture could not be parsed: $error');
    return null;
  }
}

void _auditFixture(List<Map<String, dynamic>> fixture, List<String> failures) {
  if (fixture.length != _expectedCaseCount) {
    failures.add(
      'Expected $_expectedCaseCount fixture cases, found ${fixture.length}.',
    );
  }

  final ids = <String>{};
  final classCounts = {
    for (final className in StatRadarRead.readableClassNames) className: 0,
  };
  for (final item in fixture) {
    final id = item['id'];
    if (id is! String || id.isEmpty) {
      failures.add('Fixture case has missing id: $item');
      continue;
    }
    if (!ids.add(id)) {
      failures.add('Duplicate fixture case id: $id');
    }

    final expectedClass = item['expectedClass'];
    if (!classCounts.containsKey(expectedClass)) {
      failures.add('$id has unsupported expectedClass: $expectedClass');
      continue;
    }
    classCounts[expectedClass as String] = classCounts[expectedClass]! + 1;

    final stats = item['stats'];
    if (stats is! Map<String, dynamic>) {
      failures.add('$id has missing stats object.');
      continue;
    }
    final statKeys = stats.keys.toSet();
    if (statKeys.length != StatRadarRead.axisToClass.length ||
        !StatRadarRead.axisToClass.keys.every(statKeys.contains)) {
      failures.add('$id stats must contain only STR, AGI, and END.');
      continue;
    }
    if (stats.values.any((value) => value is! int)) {
      failures.add('$id stats must be integer values.');
      continue;
    }

    final statValues = stats.cast<String, int>();
    final sortedAxes = StatRadarRead.axisToClass.keys.toList()
      ..sort((a, b) => statValues[b]!.compareTo(statValues[a]!));
    final topAxis = sortedAxes.first;
    final lead = statValues[topAxis]! - statValues[sortedAxes[1]]!;
    final radarGuess = StatRadarRead.classForAxis(topAxis);
    if (lead < StatRadarRead.dominantLeadThreshold) {
      failures.add(
        '$id dominant lead is $lead, below '
        '${StatRadarRead.dominantLeadThreshold}.',
      );
    }
    if (radarGuess != expectedClass) {
      failures.add(
        '$id top axis $topAxis maps to $radarGuess, not $expectedClass.',
      );
    }

    final gradeGap =
        statValues.values.map(_gradeIndex).reduce(max) -
        statValues.values.map(_gradeIndex).reduce(min);
    if (gradeGap > 2) {
      failures.add('$id visible grade gap is $gradeGap, above 2.');
    }
  }

  for (final entry in classCounts.entries) {
    if (entry.value != 3) {
      failures.add(
        'Expected 3 ${entry.key} fixture cases, found ${entry.value}.',
      );
    }
  }
}

void _auditStudyHtml(
  List<Map<String, dynamic>> fixture,
  List<String> failures,
  List<String> artifactNotes,
) {
  final file = File(_studyHtmlPath);
  if (!file.existsSync()) {
    failures.add('Missing study HTML file: $_studyHtmlPath');
    return;
  }
  final html = file.readAsStringSync();
  final match = RegExp(
    r'<script id="study-cases" type="application/json">\s*(.*?)\s*</script>',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) {
    failures.add('Study HTML is missing embedded study-cases JSON.');
  } else {
    try {
      final embedded = jsonDecode(match.group(1)!);
      if (jsonEncode(embedded) != jsonEncode(fixture)) {
        failures.add('Study HTML embedded cases do not match fixture JSON.');
      }
    } on Object catch (error) {
      failures.add('Study HTML embedded cases could not be parsed: $error');
    }
  }

  final requiredSnippets = {
    'width: 390px;': '390px study frame width',
    'height: 844px;': '844px study frame height',
    '<canvas id="canvas" width="290" height="260"></canvas>':
        'radar canvas dimensions',
    'const visibleAxes = ["STR", "AGI", "END"];': 'visible axis contract',
    'const dominantLeadThreshold = 400;': 'dominant lead contract',
    'const studyMode = "$_studyMode";': 'study mode',
    'const fixtureVersion = "$_fixtureVersion";': 'fixture version',
    'const exposureMs = $_expectedExposureMs;': 'five-second exposure',
    'function protocolFingerprint()': 'protocol fingerprint helper',
    'protocolHash: protocolFingerprint()': 'protocol hash receipt field',
    'id="participant-id"': 'participant id field',
    'participantId': 'participant id receipt field',
    '<b>ASSASSIN</b>': 'Assassin class key label',
    '<span>AGI-led profile</span>': 'Assassin class key mapping',
    '<b>BRUISER</b>': 'Bruiser class key label',
    '<span>STR-led profile</span>': 'Bruiser class key mapping',
    '<b>TANK</b>': 'Tank class key label',
    '<span>END-led profile</span>': 'Tank class key mapping',
    '<button data-guess="assassin">ASSASSIN</button>': 'Assassin guess button',
    '<button data-guess="bruiser">BRUISER</button>': 'Bruiser guess button',
    '<button data-guess="tank">TANK</button>': 'Tank guess button',
    '<button data-guess="unsure">NOT SURE</button>': 'Not sure guess button',
    'setTimeout(showChoices, exposureMs)': 'timed radar exposure',
    'radar.classList.add("hidden");': 'radar hidden before guessing',
    'prompt.classList.remove("hidden");': 'guess prompt reveal',
    'choices.classList.remove("hidden");': 'guess choices reveal',
    'stats: current.stats': 'receipt stat payload',
    'actualClass: current.className': 'receipt expected-class payload',
    'trialIndex: index + 1': 'receipt trial order payload',
    'radarExposureMs': 'per-trial radar exposure payload',
  };
  for (final entry in requiredSnippets.entries) {
    if (!html.contains(entry.key)) {
      failures.add('Study HTML is missing ${entry.value}.');
    }
  }

  const forbiddenSnippets = [
    'Pass target:',
    'id="legend"',
    'id="build-read"',
    'BUILD:',
    'STR</b> POWER',
    'AGI</b> CONTROL',
    'END</b> STAMINA',
    'above 70%',
    'below 70%',
    'Score 5+ receipts',
    'Radar shape needs more separation',
    'receipt.textContent = JSON.stringify(payload',
    r'score.textContent = `${Math.round(accuracy * 100)}%`',
  ];
  for (final snippet in forbiddenSnippets) {
    if (html.contains(snippet)) {
      failures.add('Study HTML leaks non-radar cue: $snippet');
    }
  }

  _auditExecutableScriptSyntax(html, failures, artifactNotes);
}

void _auditExecutableScriptSyntax(
  String html,
  List<String> failures,
  List<String> artifactNotes,
) {
  final scripts = _extractExecutableScripts(html);
  if (scripts.isEmpty) {
    failures.add('Study HTML has no executable script block to run.');
    artifactNotes.add('Executable script syntax: FAIL');
    return;
  }

  final node = _nodeExecutableOrNull();
  if (node == null) {
    artifactNotes.add('Executable script syntax: SKIPPED (node not found)');
    return;
  }

  final tempDir = Directory.systemTemp.createTempSync(
    'ironbit_radar_script_check_',
  );
  try {
    final scriptFile = File('${tempDir.path}/study.js')
      ..writeAsStringSync(scripts.join('\n\n'));
    final result = Process.runSync(node, ['--check', scriptFile.path]);
    if (result.exitCode == 0) {
      artifactNotes.add('Executable script syntax: PASS');
      return;
    }
    final output = [
      (result.stdout as String).trim(),
      (result.stderr as String).trim(),
    ].where((part) => part.isNotEmpty).join('\n');
    failures.add(
      'Study HTML executable script failed node --check: '
      '${output.isEmpty ? 'exit ${result.exitCode}' : output}',
    );
    artifactNotes.add('Executable script syntax: FAIL');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

List<String> _extractExecutableScripts(String html) {
  final scripts = <String>[];
  final pattern = RegExp(
    r'<script(?<attrs>[^>]*)>(?<body>.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  );
  for (final match in pattern.allMatches(html)) {
    final attrs = match.namedGroup('attrs')?.toLowerCase() ?? '';
    if (attrs.contains('type="application/json"') ||
        attrs.contains("type='application/json'")) {
      continue;
    }
    final body = match.namedGroup('body')?.trim();
    if (body != null && body.isNotEmpty) {
      scripts.add(body);
    }
  }
  return scripts;
}

String? _nodeExecutableOrNull() {
  final path = Platform.environment['PATH'] ?? Platform.environment['Path'];
  if (path == null) return null;
  final separator = Platform.isWindows ? ';' : ':';
  final candidates = Platform.isWindows
      ? ['node.exe', 'node.cmd', 'node.bat', 'node']
      : ['node'];
  for (final dir in path.split(separator)) {
    final trimmed = dir.trim();
    if (trimmed.isEmpty) continue;
    for (final candidate in candidates) {
      final file = File('$trimmed${Platform.pathSeparator}$candidate');
      if (file.existsSync()) {
        return file.path;
      }
    }
  }
  return null;
}

int _gradeIndex(int value) {
  if (value >= 900) return 4;
  if (value >= 600) return 3;
  if (value >= 300) return 2;
  if (value >= 100) return 1;
  return 0;
}

void _writeAuditOutput(String? path, List<String> lines) {
  if (path == null) return;
  final file = File(path)..createSync(recursive: true);
  file.writeAsStringSync(
    [
      '# Ironbit Radar Readability Audit',
      '',
      '- Generated: ${DateTime.now().toUtc().toIso8601String()}',
      '',
      '```text',
      ...lines,
      '```',
      '',
    ].join('\n'),
  );
}

class _AuditOptions {
  const _AuditOptions({
    required this.artifactOnly,
    required this.reportPath,
    required this.receiptInputs,
  });

  final bool artifactOnly;
  final String? reportPath;
  final List<String> receiptInputs;
}
