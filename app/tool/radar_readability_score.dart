import 'dart:convert';
import 'dart:io';

import 'package:workout_track/models/stat_radar_read.dart';

const _studyId = 'ironbit_radar_readability_v1';
const _studyMode = 'radar_only_v1';
const _fixtureVersion = 'radar_readability_cases_v1_2026-06-01';
const _expectedTrialsPerParticipant = 9;
const _expectedExposureMs = 5000;
const _minimumPerTrialExposureMs = 4900;
const _passThreshold = 0.70;
const _minimumParticipants = 5;

void main(List<String> args) {
  final options = _parseArgs(args);
  if (options == null) {
    exitCode = 64;
    return;
  }
  if (options.inputs.isEmpty) {
    stderr.writeln(
      'Usage: dart tool/radar_readability_score.dart <result.json> '
      '[more-results-or-directories] [--write-report <report.md>]',
    );
    exitCode = 64;
    return;
  }

  final files = _expandInputs(options.inputs);
  if (files.isEmpty) {
    stderr.writeln('No JSON result files found.');
    exitCode = 66;
    return;
  }

  final fixture = _loadFixture();
  final participants = <_ParticipantResult>[];
  for (final file in files) {
    try {
      participants.add(_parseParticipant(file, fixture));
    } on FormatException catch (error) {
      stderr.writeln('${file.path}: ${error.message}');
      exitCode = 65;
      return;
    }
  }
  final duplicateParticipantId = _firstDuplicateParticipantId(participants);
  if (duplicateParticipantId != null) {
    stderr.writeln('duplicate participantId "$duplicateParticipantId"');
    exitCode = 65;
    return;
  }

  final totalCorrect = participants.fold<int>(
    0,
    (sum, participant) => sum + participant.correct,
  );
  final totalTrials = participants.fold<int>(
    0,
    (sum, participant) => sum + participant.total,
  );
  final aggregateAccuracy = totalCorrect / totalTrials;
  final enoughParticipants = participants.length >= _minimumParticipants;
  final pass = aggregateAccuracy > _passThreshold && enoughParticipants;

  final lines = <String>[
    'Ironbit radar readability study',
    'Participants: ${participants.length}',
    'Trials: $totalTrials',
    'Accuracy: ${_percent(aggregateAccuracy)} '
        '($totalCorrect / $totalTrials)',
    'Mean response after radar hidden: '
        '${_milliseconds(_meanResponseMs(participants))}',
    'Pass threshold: > ${_percent(_passThreshold)}',
    'Minimum participants: $_minimumParticipants',
    'Evidence count: ${enoughParticipants ? 'OK' : 'TOO SMALL'}',
    'Status: ${pass ? 'PASS' : 'FAIL'}',
    '',
    'Participant receipts:',
  ];

  for (final participant in participants) {
    lines.add(
      '- ${participant.fileName} (${participant.participantId}): '
      '${_percent(participant.accuracy)} '
      '(${participant.correct} / ${participant.total}), '
      'mean response ${_milliseconds(participant.meanResponseMs)}',
    );
  }
  lines.add('');

  lines.add('Class accuracy:');
  for (final className in StatRadarRead.readableClassNames) {
    final classTrials = participants
        .expand((participant) => participant.responses)
        .where((response) => response.actualClass == className)
        .toList();
    final classCorrect = classTrials
        .where((response) => response.correct)
        .length;
    lines.add(
      '- ${className.toUpperCase()}: ${_percent(classCorrect / classTrials.length)} '
      '($classCorrect / ${classTrials.length})',
    );
  }
  lines.add('');

  lines.add('Misses:');
  final misses = participants
      .expand(
        (participant) => participant.responses.map((response) {
          return (participant: participant.fileName, response: response);
        }),
      )
      .where((entry) => !entry.response.correct)
      .toList();
  if (misses.isEmpty) {
    lines.add('- none');
  } else {
    for (final miss in misses) {
      lines.add(
        '- ${miss.participant} ${miss.response.caseId}: '
        '${miss.response.actualClass} guessed as ${miss.response.guess}',
      );
    }
  }

  final output = lines.join('\n');
  stdout.writeln(output);
  if (options.reportPath != null) {
    _writeMarkdownReport(
      path: options.reportPath!,
      lines: lines,
      participants: participants,
      pass: pass,
      aggregateAccuracy: aggregateAccuracy,
    );
  }

  exitCode = pass ? 0 : 1;
}

_ScoreOptions? _parseArgs(List<String> args) {
  final inputs = <String>[];
  String? reportPath;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--write-report') {
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
      inputs.add(arg);
    }
  }
  return _ScoreOptions(inputs: inputs, reportPath: reportPath);
}

void _writeMarkdownReport({
  required String path,
  required List<String> lines,
  required List<_ParticipantResult> participants,
  required bool pass,
  required double aggregateAccuracy,
}) {
  final file = File(path)..createSync(recursive: true);
  final buffer = StringBuffer()
    ..writeln('# Ironbit Radar Readability Result')
    ..writeln()
    ..writeln('- Generated: ${DateTime.now().toUtc().toIso8601String()}')
    ..writeln('- Study: $_studyId')
    ..writeln('- Mode: $_studyMode')
    ..writeln('- Fixture: $_fixtureVersion')
    ..writeln('- Exposure: ${_expectedExposureMs}ms')
    ..writeln('- Participants: ${participants.length}')
    ..writeln('- Accuracy: ${_percent(aggregateAccuracy)}')
    ..writeln('- Status: ${pass ? 'PASS' : 'FAIL'}')
    ..writeln()
    ..writeln('```text')
    ..writeln(lines.join('\n'))
    ..writeln('```');
  file.writeAsStringSync(buffer.toString());
}

Map<String, _FixtureCase> _loadFixture() {
  final uri = Platform.script.resolve('radar_readability_cases.json');
  final raw = jsonDecode(File.fromUri(uri).readAsStringSync());
  if (raw is! List) {
    throw const FormatException('fixture must be a JSON list');
  }
  return {
    for (final item in raw.cast<Map<String, dynamic>>())
      item['id'] as String: _FixtureCase(
        id: item['id'] as String,
        expectedClass: item['expectedClass'] as String,
        stats: (item['stats'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, value as int),
        ),
      ),
  };
}

List<File> _expandInputs(List<String> inputs) {
  final files = <File>[];
  for (final input in inputs) {
    final type = FileSystemEntity.typeSync(input);
    if (type == FileSystemEntityType.file) {
      files.add(File(input));
    } else if (type == FileSystemEntityType.directory) {
      files.addAll(
        Directory(input).listSync().whereType<File>().where(
          (file) => file.path.toLowerCase().endsWith('.json'),
        ),
      );
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

_ParticipantResult _parseParticipant(
  File file,
  Map<String, _FixtureCase> fixture,
) {
  final raw = jsonDecode(file.readAsStringSync());
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('result must be a JSON object');
  }
  if (raw['study'] != _studyId) {
    throw FormatException('expected study "$_studyId"');
  }
  if (raw['mode'] != _studyMode) {
    throw FormatException('expected mode "$_studyMode"');
  }
  if (raw['fixtureVersion'] != _fixtureVersion) {
    throw FormatException('expected fixtureVersion "$_fixtureVersion"');
  }
  final expectedProtocolHash = _protocolHash(fixture);
  if (raw['protocolHash'] != expectedProtocolHash) {
    throw FormatException('expected protocolHash "$expectedProtocolHash"');
  }
  final participantId = raw['participantId'];
  if (participantId is! String || participantId.trim().isEmpty) {
    throw const FormatException('missing participantId');
  }
  final startedAt = _parseRequiredUtcInstant(raw['startedAt'], 'startedAt');
  final completedAt = _parseRequiredUtcInstant(
    raw['completedAt'],
    'completedAt',
  );
  if (!completedAt.isAfter(startedAt)) {
    throw const FormatException('completedAt must be after startedAt');
  }
  final elapsedMs = completedAt.difference(startedAt).inMilliseconds;
  const minimumElapsedMs = _expectedTrialsPerParticipant * _expectedExposureMs;
  if (elapsedMs < minimumElapsedMs) {
    throw FormatException(
      'receipt elapsed time ${_milliseconds(elapsedMs.toDouble())} is shorter '
      'than the required ${_milliseconds(minimumElapsedMs.toDouble())} '
      'radar exposure time',
    );
  }
  if (raw['exposureMs'] != _expectedExposureMs) {
    throw FormatException('expected exposureMs $_expectedExposureMs');
  }
  final responsesRaw = raw['responses'];
  if (responsesRaw is! List) {
    throw const FormatException('missing responses list');
  }
  if (responsesRaw.length != _expectedTrialsPerParticipant) {
    throw FormatException(
      'expected $_expectedTrialsPerParticipant responses, '
      'found ${responsesRaw.length}',
    );
  }

  final seenCaseIds = <String>{};
  final responses = <_RadarResponse>[];
  for (var i = 0; i < responsesRaw.length; i++) {
    final item = responsesRaw[i];
    if (item is! Map<String, dynamic>) {
      throw const FormatException('response must be a JSON object');
    }
    final trialIndex = item['trialIndex'];
    final caseId = item['caseId'];
    final actualClass = item['actualClass'];
    final guess = item['guess'];
    final radarExposureMs = item['radarExposureMs'];
    final responseTimeMs = item['responseTimeMs'];
    if (caseId is! String || actualClass is! String || guess is! String) {
      throw const FormatException(
        'response must include caseId, actualClass, and guess strings',
      );
    }
    final expectedTrialIndex = i + 1;
    if (trialIndex is! int || trialIndex != expectedTrialIndex) {
      throw FormatException('response trialIndex expected $expectedTrialIndex');
    }
    if (radarExposureMs is! int ||
        radarExposureMs < _minimumPerTrialExposureMs) {
      throw FormatException(
        'response must include radarExposureMs >= '
        '${_minimumPerTrialExposureMs}ms',
      );
    }
    if (responseTimeMs is! int || responseTimeMs < 0) {
      throw const FormatException(
        'response must include non-negative responseTimeMs',
      );
    }
    if (!{...StatRadarRead.readableClassNames, 'unsure'}.contains(guess)) {
      throw FormatException('unsupported guess "$guess"');
    }
    final fixtureCase = fixture[caseId];
    if (fixtureCase == null) {
      throw FormatException('unknown caseId "$caseId"');
    }
    if (!seenCaseIds.add(caseId)) {
      throw FormatException('duplicate caseId "$caseId"');
    }
    if (actualClass != fixtureCase.expectedClass) {
      throw FormatException(
        'case $caseId expected class ${fixtureCase.expectedClass}, '
        'found $actualClass',
      );
    }
    final stats = item['stats'];
    if (stats is! Map<String, dynamic>) {
      throw const FormatException('response must include stats object');
    }
    for (final axis in ['STR', 'AGI', 'END']) {
      if (stats[axis] != fixtureCase.stats[axis]) {
        throw FormatException(
          'case $caseId $axis expected ${fixtureCase.stats[axis]}, '
          'found ${stats[axis]}',
        );
      }
    }
    responses.add(
      _RadarResponse(
        trialIndex: trialIndex,
        caseId: caseId,
        actualClass: actualClass,
        guess: guess,
        correct: guess == actualClass,
        radarExposureMs: radarExposureMs,
        responseTimeMs: responseTimeMs,
      ),
    );
  }
  final missingCaseIds = fixture.keys
      .where((caseId) => !seenCaseIds.contains(caseId))
      .toList();
  if (missingCaseIds.isNotEmpty) {
    throw FormatException('missing caseId(s): ${missingCaseIds.join(', ')}');
  }

  final correct = responses.where((response) => response.correct).length;
  if (raw['correct'] != correct) {
    throw FormatException('top-level correct expected $correct');
  }
  if (raw['total'] != responses.length) {
    throw FormatException('top-level total expected ${responses.length}');
  }
  final accuracy = raw['accuracy'];
  if (accuracy is! num ||
      (accuracy.toDouble() - correct / responses.length).abs() > 0.000001) {
    throw FormatException(
      'top-level accuracy expected ${correct / responses.length}',
    );
  }

  return _ParticipantResult(
    fileName: file.uri.pathSegments.last,
    participantId: participantId,
    responses: responses,
    correct: correct,
    total: responses.length,
  );
}

DateTime _parseRequiredUtcInstant(Object? value, String fieldName) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('missing $fieldName');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('invalid $fieldName');
  }
  return parsed.toUtc();
}

String _protocolHash(Map<String, _FixtureCase> fixture) {
  final caseParts = fixture.values
      .map((item) {
        final statPart = StatRadarRead.visibleStats
            .map((axis) => '$axis=${item.stats[axis]}')
            .join(',');
        return '${item.id}:${item.expectedClass}:$statPart';
      })
      .join('|');
  return _fnv1a(
    [
      _studyId,
      _studyMode,
      _fixtureVersion,
      _expectedExposureMs,
      StatRadarRead.dominantLeadThreshold,
      StatRadarRead.visibleStats.join(','),
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

String? _firstDuplicateParticipantId(List<_ParticipantResult> participants) {
  final seen = <String>{};
  for (final participant in participants) {
    final id = participant.participantId.toLowerCase();
    if (!seen.add(id)) {
      return participant.participantId;
    }
  }
  return null;
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _milliseconds(double value) => '${value.round()}ms';

double _meanResponseMs(List<_ParticipantResult> participants) {
  final responses = participants.expand((participant) => participant.responses);
  final times = [for (final response in responses) response.responseTimeMs];
  return times.reduce((a, b) => a + b) / times.length;
}

class _FixtureCase {
  const _FixtureCase({
    required this.id,
    required this.expectedClass,
    required this.stats,
  });

  final String id;
  final String expectedClass;
  final Map<String, int> stats;
}

class _ScoreOptions {
  const _ScoreOptions({required this.inputs, required this.reportPath});

  final List<String> inputs;
  final String? reportPath;
}

class _ParticipantResult {
  const _ParticipantResult({
    required this.fileName,
    required this.participantId,
    required this.responses,
    required this.correct,
    required this.total,
  });

  final String fileName;
  final String participantId;
  final List<_RadarResponse> responses;
  final int correct;
  final int total;

  double get accuracy => correct / total;

  double get meanResponseMs {
    final times = [for (final response in responses) response.responseTimeMs];
    return times.reduce((a, b) => a + b) / times.length;
  }
}

class _RadarResponse {
  const _RadarResponse({
    required this.trialIndex,
    required this.caseId,
    required this.actualClass,
    required this.guess,
    required this.correct,
    required this.radarExposureMs,
    required this.responseTimeMs,
  });

  final int trialIndex;
  final String caseId;
  final String actualClass;
  final String guess;
  final bool correct;
  final int radarExposureMs;
  final int responseTimeMs;
}
