import 'dart:async';

import 'package:ensemble_test_runner/execution/artifact_transport.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entry execution mode selects the artifact sink', () async {
    final emitter = EnsembleTestArtifactEmitter.instance;
    emitter.resetForTest();
    configureArtifactTransport(ExecutionMode.widget);
    expect(usesDeviceArtifactTransport, isFalse);
    expect(ensembleTestArtifactSink, isA<FileArtifactSink>());

    configureArtifactTransport(ExecutionMode.integration);
    expect(usesDeviceArtifactTransport, isTrue);
    expect(ensembleTestArtifactSink, isA<DeviceTransportArtifactSink>());

    final output = <String>[];
    try {
      await runZoned(
        () => writeEnsembleTestArtifactString(
          'screenshots',
          'step.webp',
          'image-bytes',
        ),
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => output.add(line),
        ),
      );
      expect(output, contains(startsWith(ensembleTestArtifactProtocolPrefix)));
      expect(output.join('\n'), contains('"event":"begin"'));
      expect(output.join('\n'), contains('"event":"start"'));
    } finally {
      configureArtifactTransport(ExecutionMode.widget);
      emitter.resetForTest();
    }
  });
}
