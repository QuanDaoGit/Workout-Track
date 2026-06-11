import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('radar readability bundle creates portable study files', () async {
    final dir = await Directory.systemTemp.createTemp('radar_bundle_test_');
    addTearDown(() => dir.delete(recursive: true));

    final result = await Process.run(_dartExecutable(), [
      'tool/radar_readability_bundle.dart',
      dir.path,
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final html = File('${dir.path}/radar_readability_study.html');
    final pressStart = File(
      '${dir.path}/fonts/pressstart2p/PressStart2P-Regular.ttf',
    );
    final shareTech = File(
      '${dir.path}/fonts/sharetechmono/ShareTechMono-Regular.ttf',
    );
    final readme = File('${dir.path}/README.txt');
    final participantInstructions = File(
      '${dir.path}/PARTICIPANT_INSTRUCTIONS.txt',
    );
    final facilitatorChecklist = File('${dir.path}/FACILITATOR_CHECKLIST.txt');
    final receiptsReadme = File('${dir.path}/receipts/README.txt');

    expect(html.existsSync(), isTrue);
    expect(pressStart.existsSync(), isTrue);
    expect(shareTech.existsSync(), isTrue);
    expect(readme.existsSync(), isTrue);
    expect(participantInstructions.existsSync(), isTrue);
    expect(facilitatorChecklist.existsSync(), isTrue);
    expect(receiptsReadme.existsSync(), isTrue);

    final htmlText = html.readAsStringSync();
    expect(htmlText, contains('url("fonts/pressstart2p/'));
    expect(htmlText, contains('url("fonts/sharetechmono/'));
    expect(htmlText, isNot(contains('url("../fonts/')));
    expect(htmlText, contains('participantId'));
    expect(readme.readAsStringSync(), contains('five distinct'));
    expect(participantInstructions.readAsStringSync(), isNot(contains('70%')));
    expect(
      participantInstructions.readAsStringSync(),
      contains('using only the radar shape and axis labels'),
    );
    expect(
      facilitatorChecklist.readAsStringSync(),
      contains('radar_readability_goal_gate.dart --artifact-only'),
    );
    expect(
      receiptsReadme.readAsStringSync(),
      contains('Do not store real names'),
    );
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
