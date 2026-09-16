import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_cli.dart';
import 'package:ensemble_test_runner/execution/artifact_transport.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/schema/ensemble_test_schema_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suite mode defaults to widget and parses integration', () {
    expect(
      EnsembleTestParser.parseConfigString('').mode,
      ExecutionMode.widget,
    );
    expect(
      EnsembleTestParser.parseConfigString('mode: integration').mode,
      ExecutionMode.integration,
    );
    expect(
      () => EnsembleTestParser.parseConfigString('mode: device'),
      throwsA(isA<EnsembleTestFailure>()),
    );
  });

  test('config schema exposes widget and integration modes', () {
    final properties =
        EnsembleTestSchemaBuilder.buildConfig()['properties'] as Map;
    final mode = properties['mode'] as Map;
    expect(mode['default'], 'widget');
    expect(mode['enum'], ['widget', 'integration']);
  });

  test('run metadata is optional and backward-compatible', () {
    expect(
      const EnsembleTestRunResult(results: []).toJson(),
      isNot(contains('metadata')),
    );
    expect(
      const EnsembleTestRunResult(
        results: [],
        metadata: {'mode': 'integration', 'deviceId': 'ios'},
      ).toJson()['metadata'],
      {'mode': 'integration', 'deviceId': 'ios'},
    );
  });

  test('CLI mode overrides config and validates mode-only options', () {
    expect(
      resolveExecutionModeForTest(
        ['--mode=integration'],
        ExecutionMode.widget,
      ),
      ExecutionMode.integration,
    );
    expect(
      () => validateExecutionModeOptionsForTest(
        ['--device-id=emulator-5554'],
        mode: ExecutionMode.widget,
        config: const EnsembleTestConfig(),
      ),
      throwsStateError,
    );
    expect(
      () => validateExecutionModeOptionsForTest(
        ['--jobs=auto'],
        mode: ExecutionMode.integration,
        config: const EnsembleTestConfig(),
      ),
      throwsStateError,
    );
  });

  test('integration keeps matching devices and allows --device', () {
    const device = TestDeviceTarget(
      id: 'phone',
      platform: 'android',
      model: 'Samsung Galaxy S20',
    );
    expect(
      () => validateExecutionModeOptionsForTest(
        const [],
        mode: ExecutionMode.integration,
        config: const EnsembleTestConfig(devices: [device]),
      ),
      returnsNormally,
    );
    expect(
      () => validateExecutionModeOptionsForTest(
        ['--device=phone'],
        mode: ExecutionMode.integration,
        config: const EnsembleTestConfig(devices: [device]),
      ),
      returnsNormally,
    );
  });

  test('CLI source does not import Flutter discovery', () {
    final source = File('lib/cli/ensemble_test_cli.dart').readAsStringSync();
    expect(source.contains('ensemble_test_discovery.dart'), isFalse);
  });

  test('device discovery accepts android/ios physical and virtual targets', () {
    final devices = json.encode([
      {
        'id': 'emulator-5554',
        'name': 'Pixel',
        'targetPlatform': 'android-arm64',
        'emulator': true,
      },
      {
        'id': 'physical-ios',
        'name': 'Phone',
        'targetPlatform': 'ios',
        'emulator': false,
      },
      {
        'id': 'chrome',
        'name': 'Chrome',
        'targetPlatform': 'web-javascript',
        'emulator': false,
      },
    ]);
    expect(
      () => selectIntegrationDeviceIdForTest(devices),
      throwsStateError,
    );
    expect(
      selectIntegrationDeviceIdForTest(
        devices,
        requestedId: 'emulator-5554',
      ),
      'emulator-5554',
    );
    expect(
      selectIntegrationDeviceIdForTest(
        devices,
        requestedId: 'physical-ios',
      ),
      'physical-ios',
    );
    expect(
      () => selectIntegrationDeviceIdForTest(
        devices,
        requestedId: 'chrome',
      ),
      throwsStateError,
    );
  });

  test('device discovery auto-selects a single supported target', () {
    final devices = json.encode([
      {
        'id': 'emulator-5554',
        'name': 'Pixel',
        'targetPlatform': 'android-arm64',
        'emulator': true,
      },
      {
        'id': 'chrome',
        'name': 'Chrome',
        'targetPlatform': 'web-javascript',
        'emulator': false,
      },
    ]);
    expect(selectIntegrationDeviceIdForTest(devices), 'emulator-5554');
  });

  test('device discovery requires an id when multiple targets exist', () {
    final devices = json.encode([
      {
        'id': 'android',
        'name': 'Pixel',
        'targetPlatform': 'android-arm64',
        'emulator': true,
      },
      {
        'id': 'ios',
        'name': 'iPhone',
        'targetPlatform': 'ios',
        'emulator': true,
      },
    ]);
    expect(
      () => selectIntegrationDeviceIdForTest(devices),
      throwsStateError,
    );
    expect(
      selectIntegrationDeviceIdForTest(devices, requestedId: 'ios'),
      'ios',
    );
  });

  test('integration backend builds a device launch command', () {
    final args = buildIntegrationFlutterTestArgsForTest(
      deviceId: 'emulator-5554',
      deviceName: 'Pixel',
      targetPlatform: 'android-arm64',
    );
    expect(args, contains('integration_test/ensemble_tests.dart'));
    expect(args, containsAllInOrder(['-d', 'emulator-5554']));
    expect(
      args,
      contains('--dart-define=ensembleTestHostOwnsServices=true'),
    );
    expect(
      args,
      contains('--dart-define=ensembleTestExecutionMode=integration'),
    );
  });

  test('artifact protocol materializes and verifies bytes', () async {
    final appDir = Directory.systemTemp.createTempSync('artifact_transport_');
    addTearDown(() => appDir.deleteSync(recursive: true));
    final bytes = utf8.encode('hello integration');
    final digest = sha256.convert(bytes).toString();
    final id = '${bytes.length}-$digest';
    String record(Map<String, dynamic> value) =>
        '$ensembleTestArtifactProtocolPrefix${json.encode(value)}';
    final output = [
      record({'event': 'begin', 'runId': 'run-1'}),
      record({
        'event': 'start',
        'id': id,
        'path': 'logs/sample.log',
        'mime': 'text/plain',
        'size': bytes.length,
        'sha256': digest,
      }),
      record({'event': 'chunk', 'id': id, 'data': base64Encode(bytes)}),
      record({'event': 'end', 'id': id}),
      record({
        'event': 'complete',
        'runId': 'run-1',
        'artifacts': [
          {
            'id': id,
            'path': 'logs/sample.log',
            'size': bytes.length,
            'sha256': digest,
          },
        ],
      }),
    ].join('\n');

    await materializeTransportedArtifactsForTest(appDir.path, output);

    final file = File(
      '${appDir.path}/build/ensemble_test_runner/logs/sample.log',
    );
    expect(file.readAsStringSync(), 'hello integration');
  });

  test('artifact protocol rejects traversal', () async {
    final appDir = Directory.systemTemp.createTempSync('artifact_transport_');
    addTearDown(() => appDir.deleteSync(recursive: true));
    final bytes = utf8.encode('x');
    final digest = sha256.convert(bytes).toString();
    final id = '${bytes.length}-$digest';
    String record(Map<String, dynamic> value) =>
        '$ensembleTestArtifactProtocolPrefix${json.encode(value)}';
    final output = [
      record({'event': 'begin', 'runId': 'run-1'}),
      record({
        'event': 'start',
        'id': id,
        'path': '../outside',
        'size': bytes.length,
        'sha256': digest,
      }),
      record({'event': 'chunk', 'id': id, 'data': base64Encode(bytes)}),
      record({'event': 'end', 'id': id}),
      record({'event': 'complete', 'runId': 'run-1', 'artifacts': []}),
    ].join('\n');
    await expectLater(
      () => materializeTransportedArtifactsForTest(appDir.path, output),
      throwsStateError,
    );
  });

  test('artifact protocol rejects an incomplete stream', () async {
    final appDir = Directory.systemTemp.createTempSync('artifact_transport_');
    addTearDown(() => appDir.deleteSync(recursive: true));
    final output = '$ensembleTestArtifactProtocolPrefix${json.encode({
          'event': 'start',
          'id': 'missing-end',
          'path': 'logs/incomplete.log',
          'size': 1,
          'sha256': sha256.convert([1]).toString(),
        })}';
    await expectLater(
      () => materializeTransportedArtifactsForTest(appDir.path, output),
      throwsStateError,
    );
  });

  test('artifact protocol rejects empty output without complete', () async {
    final appDir = Directory.systemTemp.createTempSync('artifact_transport_');
    addTearDown(() => appDir.deleteSync(recursive: true));
    await expectLater(
      () => materializeTransportedArtifactsForTest(appDir.path, ''),
      throwsStateError,
    );
  });

  test('artifact protocol keeps valid files when complete is missing', () async {
    final appDir = Directory.systemTemp.createTempSync('artifact_transport_');
    addTearDown(() => appDir.deleteSync(recursive: true));
    final bytes = utf8.encode('kept');
    final digest = sha256.convert(bytes).toString();
    final id = 'run-1-0';
    String record(Map<String, dynamic> value) =>
        '$ensembleTestArtifactProtocolPrefix${json.encode(value)}';
    final output = [
      record({'event': 'begin', 'runId': 'run-1'}),
      record({
        'event': 'start',
        'id': id,
        'path': 'logs/kept.log',
        'size': bytes.length,
        'sha256': digest,
      }),
      record({'event': 'chunk', 'id': id, 'data': base64Encode(bytes)}),
      record({'event': 'end', 'id': id}),
    ].join('\n');

    final result = await materializeTransportedArtifacts(
      artifactRoot: '${appDir.path}/build/ensemble_test_runner',
      output: output,
    );
    expect(result.complete, isFalse);
    expect(
      File('${appDir.path}/build/ensemble_test_runner/logs/kept.log')
          .readAsStringSync(),
      'kept',
    );
  });

  test(
    'identical content under different paths gets unique ids and both write',
    () async {
      final appDir = Directory.systemTemp.createTempSync('artifact_transport_');
      addTearDown(() => appDir.deleteSync(recursive: true));
      final bytes = utf8.encode('same-bytes');
      final digest = sha256.convert(bytes).toString();
      // Distinct transfer ids even when size+sha256 match.
      const idA = 'run-dup-0';
      const idB = 'run-dup-1';
      String record(Map<String, dynamic> value) =>
          '$ensembleTestArtifactProtocolPrefix${json.encode(value)}';

      void appendArtifact(List<String> lines, String id, String path) {
        lines.addAll([
          record({
            'event': 'start',
            'id': id,
            'path': path,
            'mime': 'image/png',
            'size': bytes.length,
            'sha256': digest,
          }),
          record({'event': 'chunk', 'id': id, 'data': base64Encode(bytes)}),
          record({'event': 'end', 'id': id}),
        ]);
      }

      final lines = <String>[
        record({'event': 'begin', 'runId': 'run-dup'}),
      ];
      appendArtifact(lines, idA, 'screenshots/a.png');
      appendArtifact(lines, idB, 'screenshots/b.png');
      lines.add(
        record({
          'event': 'complete',
          'runId': 'run-dup',
          'artifacts': [
            {
              'id': idA,
              'path': 'screenshots/a.png',
              'size': bytes.length,
              'sha256': digest,
            },
            {
              'id': idB,
              'path': 'screenshots/b.png',
              'size': bytes.length,
              'sha256': digest,
            },
          ],
        }),
      );

      await materializeTransportedArtifactsForTest(appDir.path, lines.join('\n'));
      expect(
        File('${appDir.path}/build/ensemble_test_runner/screenshots/a.png')
            .readAsStringSync(),
        'same-bytes',
      );
      expect(
        File('${appDir.path}/build/ensemble_test_runner/screenshots/b.png')
            .readAsStringSync(),
        'same-bytes',
      );
    },
  );

  test('artifact chunk records fit under the Android logcat line limit', () {
    const maxLogcatPayload = 4000;
    final encoded = base64Encode(
      List<int>.filled(ensembleTestArtifactRawChunkSize, 7),
    );
    final line =
        '$ensembleTestArtifactProtocolPrefix${json.encode({
      'event': 'chunk',
      'id': '2026-09-17T00:00:00.000Z-0',
      'data': encoded,
    })}';
    expect(line.length, lessThan(maxLogcatPayload));
  });

  test('emitter assigns unique run-scoped ids for identical payloads', () {
    EnsembleTestArtifactEmitter.instance.resetForTest();
    addTearDown(EnsembleTestArtifactEmitter.instance.resetForTest);
    final bytes = utf8.encode('same-bytes');
    EnsembleTestArtifactEmitter.instance.begin(runId: 'run-emit');
    EnsembleTestArtifactEmitter.instance.emitArtifact(
      'screenshots/a.png',
      bytes,
      mimeType: 'image/png',
    );
    EnsembleTestArtifactEmitter.instance.emitArtifact(
      'screenshots/b.png',
      bytes,
      mimeType: 'image/png',
    );
    expect(
      EnsembleTestArtifactEmitter.instance.emittedIdsForTest(),
      ['run-emit-0', 'run-emit-1'],
    );
  });

  test(
    'complete fails when one of two same-content artifacts is missing',
    () async {
      final appDir = Directory.systemTemp.createTempSync('artifact_transport_');
      addTearDown(() => appDir.deleteSync(recursive: true));
      final bytes = utf8.encode('same-bytes');
      final digest = sha256.convert(bytes).toString();
      String record(Map<String, dynamic> value) =>
          '$ensembleTestArtifactProtocolPrefix${json.encode(value)}';
      // Only materialize the first id; complete lists both.
      final output = [
        record({'event': 'begin', 'runId': 'run-miss'}),
        record({
          'event': 'start',
          'id': 'run-miss-0',
          'path': 'screenshots/a.png',
          'mime': 'image/png',
          'size': bytes.length,
          'sha256': digest,
        }),
        record({
          'event': 'chunk',
          'id': 'run-miss-0',
          'data': base64Encode(bytes),
        }),
        record({'event': 'end', 'id': 'run-miss-0'}),
        record({
          'event': 'complete',
          'runId': 'run-miss',
          'artifacts': [
            {
              'id': 'run-miss-0',
              'path': 'screenshots/a.png',
              'size': bytes.length,
              'sha256': digest,
            },
            {
              'id': 'run-miss-1',
              'path': 'screenshots/b.png',
              'size': bytes.length,
              'sha256': digest,
            },
          ],
        }),
      ].join('\n');

      await expectLater(
        () => materializeTransportedArtifactsForTest(appDir.path, output),
        throwsStateError,
      );
      expect(
        File('${appDir.path}/build/ensemble_test_runner/screenshots/a.png')
            .readAsStringSync(),
        'same-bytes',
      );
    },
  );
}
