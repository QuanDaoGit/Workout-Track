import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:workout_track/models/stat_radar_read.dart';

const _fixturePath = 'tool/radar_readability_cases.json';
const _fixtureVersion = 'radar_readability_cases_v1_2026-06-01';
const _passThreshold = 0.70;

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart tool/radar_readability_report.dart [output.md]',
    );
    exitCode = 64;
    return;
  }

  final cases = _loadCases();
  final report = _buildReport(cases);
  if (args.isEmpty) {
    stdout.write(report);
  } else {
    final file = File(args.single)..createSync(recursive: true);
    file.writeAsStringSync(report);
    stdout.writeln('Radar readability report written:');
    stdout.writeln(file.absolute.path);
  }
}

List<_RadarCase> _loadCases() {
  final raw =
      jsonDecode(File(_fixturePath).readAsStringSync()) as List<dynamic>;
  return [
    for (final item in raw.cast<Map<String, dynamic>>())
      _RadarCase(
        id: item['id'] as String,
        expectedClass: item['expectedClass'] as String,
        stats: (item['stats'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, value as int),
        ),
      ),
  ];
}

String _buildReport(List<_RadarCase> cases) {
  final rows = [_ReportRow.header()];
  var correct = 0;
  final topByClass = <String, Set<String>>{
    for (final className in StatRadarRead.readableClassNames)
      className: <String>{},
  };

  for (final c in cases) {
    final sortedAxes = StatRadarRead.axisToClass.keys.toList()
      ..sort((a, b) => c.stats[b]!.compareTo(c.stats[a]!));
    final topAxis = sortedAxes.first;
    final lead = c.stats[topAxis]! - c.stats[sortedAxes[1]]!;
    final guessedClass = lead >= StatRadarRead.dominantLeadThreshold
        ? StatRadarRead.classForAxis(topAxis)
        : null;
    final gradeGap =
        c.stats.values.map(_gradeIndex).reduce(max) -
        c.stats.values.map(_gradeIndex).reduce(min);
    final isCorrect = guessedClass == c.expectedClass;
    if (isCorrect) correct += 1;
    topByClass[c.expectedClass]?.add(topAxis);
    rows.add(
      _ReportRow([
        c.id,
        c.expectedClass.toUpperCase(),
        topAxis,
        guessedClass?.toUpperCase() ?? 'BALANCED',
        lead.toString(),
        gradeGap.toString(),
        c.stats['STR'].toString(),
        c.stats['AGI'].toString(),
        c.stats['END'].toString(),
        isCorrect ? 'yes' : 'no',
      ]),
    );
  }

  final accuracy = correct / cases.length;
  final noDeadStats = cases.every((c) {
    final gradeGap =
        c.stats.values.map(_gradeIndex).reduce(max) -
        c.stats.values.map(_gradeIndex).reduce(min);
    return gradeGap <= 2;
  });
  final distinctClassTops = StatRadarRead.readableClassNames.every((className) {
    final axis = StatRadarRead.axisForClass(className);
    return axis != null && topByClass[className]!.contains(axis);
  });

  final buffer = StringBuffer()
    ..writeln('# Ironbit Radar Readability Evidence')
    ..writeln()
    ..writeln('- Generated: ${DateTime.now().toUtc().toIso8601String()}')
    ..writeln('- Fixture: $_fixtureVersion')
    ..writeln('- Visible axes: ${StatRadarRead.visibleStats.join(', ')}')
    ..writeln(
      '- Dominant lead threshold: '
      '${StatRadarRead.dominantLeadThreshold} points',
    )
    ..writeln(
      '- Proxy classifier accuracy: ${_percent(accuracy)} '
      '($correct / ${cases.length})',
    )
    ..writeln('- Proxy pass threshold: > ${_percent(_passThreshold)}')
    ..writeln('- Distinct class tops: ${distinctClassTops ? 'PASS' : 'FAIL'}')
    ..writeln('- No visible dead stat: ${noDeadStats ? 'PASS' : 'FAIL'}')
    ..writeln()
    ..writeln(
      'These fixture stats are the 20-session class-typical radar cases used '
      'by `test/stat_engine_test.dart`; that test verifies the fixture values '
      'against the current `StatEngine`.',
    )
    ..writeln()
    ..writeln('| ${rows.first.cells.join(' | ')} |')
    ..writeln('| ${rows.first.cells.map((_) => '---').join(' | ')} |');

  for (final row in rows.skip(1)) {
    buffer.writeln('| ${row.cells.join(' | ')} |');
  }
  return buffer.toString();
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

int _gradeIndex(int value) {
  if (value >= 900) return 4;
  if (value >= 600) return 3;
  if (value >= 300) return 2;
  if (value >= 100) return 1;
  return 0;
}

class _RadarCase {
  const _RadarCase({
    required this.id,
    required this.expectedClass,
    required this.stats,
  });

  final String id;
  final String expectedClass;
  final Map<String, int> stats;
}

class _ReportRow {
  const _ReportRow(this.cells);

  factory _ReportRow.header() => const _ReportRow([
    'Case',
    'Expected',
    'Top Axis',
    'Radar Guess',
    'Lead',
    'Grade Gap',
    'STR',
    'AGI',
    'END',
    'Correct',
  ]);

  final List<String> cells;
}
