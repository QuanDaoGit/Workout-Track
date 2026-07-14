import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('radar readability study script', () {
    test('has one executable script separate from embedded fixture JSON', () {
      final html = File('tool/radar_readability_study.html').readAsStringSync();
      final scripts = _extractExecutableScripts(html);

      expect(scripts, hasLength(1));
      expect(scripts.single, contains('function beginStudy()'));
      expect(scripts.single, contains('function drawRadar(stats)'));
      expect(scripts.single, contains('function showChoices()'));
    });

    test('passes JavaScript syntax check when Node is available', () async {
      final node = _nodeExecutableOrNull();
      if (node == null) {
        markTestSkipped('Node is not available on PATH.');
        return;
      }

      final html = File('tool/radar_readability_study.html').readAsStringSync();
      final scripts = _extractExecutableScripts(html);
      final dir = await Directory.systemTemp.createTemp(
        'radar_study_script_test_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final script = File('${dir.path}/study.js')
        ..writeAsStringSync(scripts.join('\n\n'));

      final result = await Process.run(node, ['--check', script.path]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    });

    test('runs the study flow and emits a receipt in Node harness', () async {
      final node = _nodeExecutableOrNull();
      if (node == null) {
        markTestSkipped('Node is not available on PATH.');
        return;
      }

      final html = File('tool/radar_readability_study.html').readAsStringSync();
      final scripts = _extractExecutableScripts(html);
      final fixtureJson = _extractEmbeddedFixture(html);
      final dir = await Directory.systemTemp.createTemp(
        'radar_study_runtime_test_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final harness = File('${dir.path}/study_runtime.js')
        ..writeAsStringSync(_runtimeHarness(fixtureJson, scripts.single));

      final result = await Process.run(node, [harness.path]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    });
  });
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
    if (body != null && body.isNotEmpty) scripts.add(body);
  }
  return scripts;
}

String _extractEmbeddedFixture(String html) {
  final match = RegExp(
    r'<script id="study-cases" type="application/json">\s*(.*?)\s*</script>',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) {
    throw StateError('Study HTML is missing embedded fixture JSON.');
  }
  return match.group(1)!;
}

String _runtimeHarness(String fixtureJson, String studyScript) {
  return '''
function assert(condition, message) {
  if (!condition) throw new Error(message);
}

class FakeClassList {
  constructor(classes = []) {
    this.classes = new Set(classes);
  }
  add(name) {
    this.classes.add(name);
  }
  remove(name) {
    this.classes.delete(name);
  }
  toggle(name, enabled) {
    if (enabled) this.add(name);
    else this.remove(name);
  }
  contains(name) {
    return this.classes.has(name);
  }
}

class FakeElement {
  constructor(id, classes = []) {
    this.id = id;
    this.classList = new FakeClassList(classes);
    this.dataset = {};
    this.listeners = {};
    this.textContent = "";
    this.value = "";
    this.width = 290;
    this.height = 260;
  }
  addEventListener(type, listener) {
    this.listeners[type] = listener;
  }
  click() {
    this.listeners.click?.({ target: this });
  }
  closest(selector) {
    return selector === "button[data-guess]" && this.dataset.guess
      ? this
      : null;
  }
  getContext() {
    return {
      clearRect() {},
      beginPath() {},
      moveTo() {},
      lineTo() {},
      closePath() {},
      stroke() {},
      fill() {},
      fillRect() {},
      set lineWidth(value) {},
      set strokeStyle(value) {},
      set fillStyle(value) {},
    };
  }
}

const elements = {};
function element(id, classes = []) {
  elements[id] = new FakeElement(id, classes);
  return elements[id];
}

element("intro");
element("trial", ["hidden"]);
element("results", ["hidden"]);
element("start");
element("restart");
element("download");
element("progress");
element("timer");
element("participant-id").value = "P01";
element("radar");
element("prompt", ["hidden"]);
element("choices", ["hidden"]);
element("score");
element("verdict");
element("receipt");
element("canvas");
element("label-str");
element("label-agi");
element("label-end");
element("study-cases").textContent = ${_jsString(fixtureJson)};

global.document = {
  getElementById(id) {
    const found = elements[id];
    assert(found, `Missing fake element: \${id}`);
    return found;
  },
};

const timeoutQueue = [];
global.setTimeout = (callback, ms) => {
  timeoutQueue.push({ callback, ms });
  return timeoutQueue.length;
};
global.clearTimeout = () => {};
global.setInterval = () => 1;
global.clearInterval = () => {};
let fakeNow = 1000;
global.performance = { now: () => fakeNow };
global.localStorage = {
  store: {},
  setItem(key, value) {
    this.store[key] = value;
  },
  getItem(key) {
    return this.store[key] ?? null;
  },
};
global.Blob = function Blob() {};
global.URL = {
  createObjectURL() {
    return "blob://unused";
  },
  revokeObjectURL() {},
};

$studyScript

function runExposureTimer() {
  const index = timeoutQueue.findIndex((timer) => timer.ms === 5000);
  assert(index !== -1, "Expected a 5000ms exposure timer.");
  const [timer] = timeoutQueue.splice(index, 1);
  fakeNow += timer.ms;
  timer.callback();
}

function submitChoice(guess) {
  const button = new FakeElement("choice");
  button.dataset.guess = guess;
  elements.choices.listeners.click({ target: button });
}

elements.start.click();
assert(!elements.trial.classList.contains("hidden"), "Trial should be visible after start.");
assert(!elements.radar.classList.contains("hidden"), "Radar should be visible during exposure.");
assert(elements.choices.classList.contains("hidden"), "Choices should be hidden during exposure.");

for (let i = 0; i < 9; i += 1) {
  runExposureTimer();
  assert(elements.radar.classList.contains("hidden"), "Radar should hide before guessing.");
  assert(!elements.choices.classList.contains("hidden"), "Choices should be visible after exposure.");
  submitChoice("assassin");
}

const payloadText = localStorage.getItem("ironbit_radar_readability_results_v1");
assert(payloadText, "Expected study result receipt in localStorage.");
const payload = JSON.parse(payloadText);
assert(payload.study === "ironbit_radar_readability_v1", "Wrong study id.");
assert(payload.mode === "radar_only_v1", "Wrong study mode.");
assert(
  typeof payload.protocolHash === "string" && payload.protocolHash.length === 8,
  "Receipt should include an 8-character protocol hash."
);
assert(payload.participantId === "P01", "Wrong participant id.");
assert(payload.exposureMs === 5000, "Wrong exposure time.");
assert(payload.total === 9, "Wrong response count.");
assert(payload.responses.length === 9, "Wrong receipt response length.");
assert(
  payload.responses.every((response, i) => response.trialIndex === i + 1),
  "Every response should record its trial index."
);
assert(
  payload.responses.every((response) => response.radarExposureMs === 5000),
  "Every response should record a full radar exposure."
);
assert(!elements.results.classList.contains("hidden"), "Results screen should be visible.");
assert(elements.score.textContent === "COMPLETE", "Participant results should not show accuracy.");
assert(
  elements.verdict.textContent === "Receipt ready. Download the JSON and give it to the facilitator.",
  "Results verdict should be neutral facilitator handoff copy."
);
assert(!elements.verdict.textContent.includes("70%"), "Participant screen must not mention pass threshold.");
assert(elements.receipt.textContent.includes("Participant: P01"), "Receipt summary should identify the participant code.");
assert(elements.receipt.textContent.includes("Profiles logged: 9"), "Receipt summary should show completion count.");
assert(!elements.receipt.textContent.includes("actualClass"), "Visible receipt must not expose the answer key.");
assert(!elements.receipt.textContent.includes("radar_only_v1"), "Visible receipt must not expose raw JSON.");
''';
}

String _jsString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n');
  return '"$escaped"';
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
      if (file.existsSync()) return file.path;
    }
  }
  return null;
}
