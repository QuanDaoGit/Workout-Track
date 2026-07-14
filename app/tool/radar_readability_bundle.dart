import 'dart:io';

const _defaultOutputDir = 'build/radar_readability_study';
const _studyHtml = 'tool/radar_readability_study.html';
const _pressStartFont = 'fonts/pressstart2p/PressStart2P-Regular.ttf';
const _shareTechFont = 'fonts/sharetechmono/ShareTechMono-Regular.ttf';

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart tool/radar_readability_bundle.dart [output-directory]',
    );
    exitCode = 64;
    return;
  }
  final outputDir = Directory(args.isEmpty ? _defaultOutputDir : args.single);
  if (!_sourceFilesExist()) {
    return;
  }
  outputDir.createSync(recursive: true);

  final html = File(
    _studyHtml,
  ).readAsStringSync().replaceAll('../fonts/', 'fonts/');
  File('${outputDir.path}/radar_readability_study.html')
    ..createSync(recursive: true)
    ..writeAsStringSync(html);

  _copyFile(_pressStartFont, '${outputDir.path}/fonts/pressstart2p');
  _copyFile(_shareTechFont, '${outputDir.path}/fonts/sharetechmono');
  File('${outputDir.path}/README.txt').writeAsStringSync(_readme());
  File(
    '${outputDir.path}/PARTICIPANT_INSTRUCTIONS.txt',
  ).writeAsStringSync(_participantInstructions());
  File(
    '${outputDir.path}/FACILITATOR_CHECKLIST.txt',
  ).writeAsStringSync(_facilitatorChecklist());
  final receiptsDir = Directory('${outputDir.path}/receipts')
    ..createSync(recursive: true);
  File('${receiptsDir.path}/README.txt').writeAsStringSync(_receiptsReadme());

  stdout.writeln('Radar readability study bundle created:');
  stdout.writeln(outputDir.absolute.path);
  stdout.writeln('');
  stdout.writeln('Open radar_readability_study.html in a browser.');
}

bool _sourceFilesExist() {
  for (final path in [_studyHtml, _pressStartFont, _shareTechFont]) {
    if (!File(path).existsSync()) {
      stderr.writeln('Missing required file: $path');
      exitCode = 66;
      return false;
    }
  }
  return true;
}

void _copyFile(String sourcePath, String targetDirPath) {
  final source = File(sourcePath);
  final targetDir = Directory(targetDirPath)..createSync(recursive: true);
  source.copySync('${targetDir.path}/${source.uri.pathSegments.last}');
}

String _readme() {
  return '''
Ironbit Radar Readability Study

Purpose:
Validate whether a person can read the hidden class from the radar shape in 5 seconds.

Files:
- radar_readability_study.html: the study screen
- PARTICIPANT_INSTRUCTIONS.txt: participant-safe script
- FACILITATOR_CHECKLIST.txt: setup, collection, and scoring checklist
- receipts/: save downloaded participant JSON receipts here
- fonts/: local study fonts

Run:
1. Open radar_readability_study.html in a browser.
2. Enter a non-identifying participant code, such as P01.
3. Do not explain the hidden class for any profile.
4. Tell the participant:
   "Learn the class key on the first screen. Then you will see each Ironbit stat radar for five seconds. Guess the hidden class using only the radar shape and axis labels."
5. Download the JSON receipt at the end.
6. Collect at least five distinct participant receipts.

Score from the app repo:
dart tool/radar_readability_score.dart <receipt-folder>

Full audit from the app repo:
dart tool/radar_readability_audit.dart <receipt-folder>

Artifact-only check before collecting receipts:
dart tool/radar_readability_audit.dart --artifact-only

Pass:
The scorer exits PASS only with at least five distinct radar_only_v1 receipts and aggregate accuracy greater than 70%.
''';
}

String _participantInstructions() {
  return '''
Ironbit Radar Readability Study

You will see a short class key once.

Then you will see each Ironbit stat radar for five seconds.

After the radar disappears, guess the hidden class using only the radar shape and axis labels.

Choices:
- ASSASSIN
- BRUISER
- TANK
- NOT SURE

Use a participant code, not your real name.

At the end, download the JSON receipt and give it to the facilitator.
''';
}

String _facilitatorChecklist() {
  return '''
Ironbit Radar Readability Facilitator Checklist

Before running:
1. Run from the app repo:
   dart tool/radar_readability_goal_gate.dart --artifact-only
2. Confirm the gate passes and says human receipts were skipped.
3. Open radar_readability_study.html in a browser.
4. Give the participant only PARTICIPANT_INSTRUCTIONS.txt or read it aloud.
5. Do not mention the pass threshold or expected answers.
6. Do not explain the hidden class for any profile beyond the class key shown by the study screen.

During collection:
1. Use participant codes like P01, P02, P03.
2. Do not use real names.
3. Save each downloaded JSON receipt into the receipts folder.
4. Collect at least five distinct participant receipts.

After collection:
1. Copy the receipts folder back to the app repo if needed.
2. Run:
   dart tool/radar_readability_goal_gate.dart <receipt-folder> --write-report docs/radar-readability-results.md
3. The active goal is complete only if the full goal gate passes with human receipts.
''';
}

String _receiptsReadme() {
  return '''
Save downloaded radar-readability JSON receipts in this folder.

Use non-identifying filenames such as:
- P01.json
- P02.json
- P03.json

Do not store real names.
Do not edit receipt contents by hand.
''';
}
