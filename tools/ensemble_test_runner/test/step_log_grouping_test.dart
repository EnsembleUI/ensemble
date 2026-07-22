import 'dart:convert';

import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/step_log_grouping.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

void main() {
  group('parseConsoleLogLine', () {
    test('parses timestamp and step tag', () {
      final parsed = parseConsoleLogLine(
        '[2026-07-22T12:00:00.000][step=2] hello',
      );
      expect(parsed.timestamp, DateTime.parse('2026-07-22T12:00:00.000'));
      expect(parsed.stepIndex, 2);
      expect(parsed.message, 'hello');
    });

    test('parses timestamp without step tag', () {
      final parsed = parseConsoleLogLine('[2026-07-22T12:00:00.000] hello');
      expect(parsed.timestamp, DateTime.parse('2026-07-22T12:00:00.000'));
      expect(parsed.stepIndex, isNull);
      expect(parsed.message, 'hello');
    });
  });

  group('TestRuntimeState.formatConsoleLine', () {
    test('includes step tag when currentStepIndex is set', () {
      final runtime = TestRuntimeState()..currentStepIndex = 1;
      final line = runtime.formatConsoleLine('x');
      expect(line, contains('[step=1]'));
      expect(line, endsWith(' x'));
    });

    test('omits step tag when no active step', () {
      final runtime = TestRuntimeState();
      final line = runtime.formatConsoleLine('x');
      expect(line, isNot(contains('[step=')));
      expect(line, endsWith(' x'));
    });
  });

  group('groupLogsByStep', () {
    test('prefers stepIndex over timestamps', () {
      final grouped = groupLogsByStep(
        stepsOutline: ['tap(a)', 'waitForNavigation(Home)'],
        stepDurationsMs: [100, 100],
        // Intentionally mismatched times — stepIndex should win.
        stepStartTimes: [
          '2026-07-22T12:00:00.000',
          '2026-07-22T12:00:01.000',
        ],
        apiEvents: [
          {
            'name': 'login',
            'timestamp': '2026-07-22T12:00:00.050',
            'stepIndex': 1,
          },
        ],
        rawConsoleLines: [
          '[2026-07-22T12:00:00.050][step=1] during home wait',
        ],
      );

      expect(grouped, hasLength(2));
      expect(grouped[0]['apiCalls'], isEmpty);
      expect(grouped[0]['appLogs'], isEmpty);
      expect((grouped[1]['apiCalls'] as List).single['name'], 'login');
      expect(
        (grouped[1]['appLogs'] as List).single,
        contains('during home wait'),
      );
    });

    test('maps nested outline lines to parent top-level step', () {
      final grouped = groupLogsByStep(
        stepsOutline: [
          'group(setup)',
          '  tap(a)',
          'waitForNavigation(Home)',
        ],
        stepDurationsMs: [50, 80],
        stepStartTimes: [
          '2026-07-22T12:00:00.000',
          '2026-07-22T12:00:01.000',
        ],
        apiEvents: [
          {
            'name': 'getModemInfo',
            'timestamp': '2026-07-22T12:00:01.010',
            'stepIndex': 1,
          },
        ],
        rawConsoleLines: const [],
      );

      expect(grouped, hasLength(3));
      expect(grouped[0]['apiCalls'], isEmpty);
      expect(grouped[1]['apiCalls'], isEmpty);
      expect((grouped[2]['apiCalls'] as List).single['name'], 'getModemInfo');
    });

    test('falls back to timestamp windows when stepIndex missing', () {
      final grouped = groupLogsByStep(
        stepsOutline: ['tap(a)', 'tap(b)'],
        stepDurationsMs: [1000, 1000],
        stepStartTimes: [
          '2026-07-22T12:00:00.000',
          '2026-07-22T12:00:02.000',
        ],
        apiEvents: [
          {
            'name': 'early',
            'timestamp': '2026-07-22T12:00:00.100',
          },
          {
            'name': 'late',
            'timestamp': '2026-07-22T12:00:02.100',
          },
        ],
        rawConsoleLines: [
          '[2026-07-22T12:00:00.100] first',
          '[2026-07-22T12:00:02.100] second',
        ],
      );

      expect((grouped[0]['apiCalls'] as List).single['name'], 'early');
      expect((grouped[1]['apiCalls'] as List).single['name'], 'late');
      expect((grouped[0]['appLogs'] as List).single, contains('first'));
      expect((grouped[1]['appLogs'] as List).single, contains('second'));
    });

    test('places storage changes under matching stepIndex', () {
      final grouped = groupLogsByStep(
        stepsOutline: ['tap(a)', 'setStorage(token)'],
        stepDurationsMs: [50, 50],
        stepStartTimes: [
          '2026-07-22T12:00:00.000',
          '2026-07-22T12:00:01.000',
        ],
        apiEvents: const [],
        rawConsoleLines: const [],
        storageSteps: [
          {
            'stepIndex': 1,
            'timestamp': '2026-07-22T12:00:01.010',
            'changes': [
              {'key': 'token', 'change': 'added', 'after': 'abc'},
              {
                'key': 'count',
                'change': 'modified',
                'before': 1,
                'after': 2,
              },
            ],
          },
        ],
      );

      expect(grouped[0]['storageChanges'], isEmpty);
      final changes = grouped[1]['storageChanges'] as List;
      expect(changes, hasLength(2));
      expect(changes[0]['key'], 'token');
      expect(changes[0]['change'], 'added');
      expect(changes[1]['change'], 'modified');
    });

    test('places screenshot frames under matching stepIndex', () {
      final grouped = groupLogsByStep(
        stepsOutline: ['tap(a)', 'waitForNavigation(Home)'],
        stepDurationsMs: [50, 50],
        stepStartTimes: [
          '2026-07-22T12:00:00.000',
          '2026-07-22T12:00:01.000',
        ],
        apiEvents: const [],
        rawConsoleLines: const [],
        screenshotFrames: [
          {
            'stepIndex': 1,
            'label': '2. waitForNavigation(Home)',
            'file': 't_step1_0.png',
            'href': '../screenshots/t_step1_0.png',
          },
        ],
      );

      expect(grouped[0]['screenshots'], isEmpty);
      final shots = grouped[1]['screenshots'] as List;
      expect(shots, hasLength(1));
      expect(shots.single['href'], '../screenshots/t_step1_0.png');
    });
  });

  group('writeStorageLogFile', () {
    test('includes keys snapshot and step diffs', () async {
      final logger = TestLogger();
      final displayPath = await writeStorageLogFile(
        logger: logger,
        filePrefix: 'sample',
        keys: const {'existing': true},
        stepDiffs: [
          StorageStepDiff(
            stepIndex: 2,
            timestamp: DateTime.parse('2026-07-22T12:00:00.000'),
            changes: const [
              StorageKeyChange(
                key: 'auth',
                change: 'added',
                after: 'token',
              ),
            ],
          ),
        ],
      );
      expect(displayPath, contains('storage'));

      final file = ensembleTestArtifactFile('logs', p.basename(displayPath));
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded.containsKey('keys'), isTrue);
      final steps = decoded['steps'] as List<dynamic>;
      expect(steps, hasLength(1));
      expect(steps.single['stepIndex'], 2);
      expect((steps.single['changes'] as List).single['change'], 'added');
    });
  });

  group('writeApiCallsLogFile', () {
    test('includes stepIndex on events', () async {
      final logger = TestLogger();
      final displayPath = await writeApiCallsLogFile(
        logger: logger,
        filePrefix: 'sample',
        calls: [
          APICallRecord(
            name: 'login',
            apiDefinition: YamlMap.wrap({}),
            timestamp: DateTime.parse('2026-07-22T12:00:00.000'),
            stepIndex: 3,
            mocked: true,
            statusCode: 200,
          ),
        ],
      );
      expect(displayPath, contains('api_calls'));

      final fileName = p.basename(displayPath);
      final file = ensembleTestArtifactFile('logs', fileName);
      expect(file.existsSync(), isTrue);

      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final events = decoded['events'] as List<dynamic>;
      expect(events, hasLength(1));
      expect(events.single['stepIndex'], 3);
      expect(events.single['name'], 'login');
    });

    test('stringifies non-JSON response / request values', () async {
      final logger = TestLogger();
      final displayPath = await writeApiCallsLogFile(
        logger: logger,
        filePrefix: 'field_value',
        calls: [
          APICallRecord(
            name: 'writeDoc',
            apiDefinition: YamlMap.wrap({}),
            timestamp: DateTime.parse('2026-07-22T12:00:00.000'),
            stepIndex: 1,
            resolvedBody: {
              'updatedAt': _FakeEnsembleFieldValue('serverTimestamp'),
            },
            responseBody: {
              'status': {
                'ts': _FakeEnsembleFieldValue('serverTimestamp'),
                'ok': true,
              },
            },
          ),
        ],
      );

      final file = ensembleTestArtifactFile('logs', p.basename(displayPath));
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final event = (decoded['events'] as List).single as Map<String, dynamic>;
      expect(
        event['responseBody']['status']['ts'],
        contains('serverTimestamp'),
      );
      expect(event['responseBody']['status']['ok'], isTrue);
      expect(
        event['request']['body']['updatedAt'],
        contains('serverTimestamp'),
      );
    });
  });

  group('EnsembleTestReportDetails.fromJson', () {
    test('round-trips stepStartTimes for CLI report restore', () {
      const original = EnsembleTestReportDetails(
        startScreen: 'Login',
        endScreen: 'Home',
        stepsOutline: ['tap(a)', 'waitForNavigation(Home)'],
        stepDurationsMs: [120, 3400],
        stepStartTimes: [
          '2026-07-22T12:00:00.000',
          '2026-07-22T12:00:01.200',
        ],
      );

      final restored = EnsembleTestReportDetails.fromJson(original.toJson());
      expect(restored.stepStartTimes, original.stepStartTimes);
      expect(restored.stepDurationsMs, original.stepDurationsMs);
      expect(restored.stepsOutline, original.stepsOutline);
    });
  });
}

class _FakeEnsembleFieldValue {
  final String label;
  _FakeEnsembleFieldValue(this.label);

  @override
  String toString() => 'EnsembleFieldValue($label)';
}
