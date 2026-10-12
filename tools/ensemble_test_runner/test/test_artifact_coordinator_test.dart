import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_artifact_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('replaces only the selected artifact log entry', () {
    final logger = TestLogger()
      ..logs.addAll([
        'apiCalls: old.json',
        'steps: steps.json',
        'apiCallsError: retained diagnostic',
      ]);

    TestArtifactCoordinator.replaceArtifactLog(logger, 'apiCalls', 'new.json');

    expect(logger.logs, [
      'steps: steps.json',
      'apiCallsError: retained diagnostic',
      'apiCalls: new.json',
    ]);
  });

  test('does not treat malformed log lines as artifact entries', () {
    final logger = TestLogger()..logs.add('apiCalls without separator');

    TestArtifactCoordinator.replaceArtifactLog(logger, 'apiCalls', 'new.json');

    expect(logger.logs, [
      'apiCalls without separator',
      'apiCalls: new.json',
    ]);
  });

  test('shares the final artifact write across cleanup paths', () async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'dedupe', steps: []),
    );
    const coordinator = TestArtifactCoordinator();

    final first = coordinator.attachPerTestDebugArtifactsOnce(context);
    final second = coordinator.attachPerTestDebugArtifactsOnce(context);

    expect(identical(first, second), isTrue);
    await first;
  });

  test('keeps API-call publication behind the suite configuration', () async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'api-disabled', steps: []),
      config: const EnsembleTestConfig(
        logApiCalls: LogApiCallsConfig(enabled: false),
      ),
    );

    await const TestArtifactCoordinator().attachLogArtifactsOnce(context);

    expect(context.logger.logs.where((log) => log.startsWith('apiCalls:')),
        isEmpty);
  });

  test('publishes API-call evidence when logging is enabled', () async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'api-enabled', steps: []),
    );
    context.apiOverlay.calls.add(
      APICallRecord(
        name: 'getProfile',
        apiDefinition: YamlMap.wrap({'url': 'https://example.test/profile'}),
        timestamp: DateTime(2026),
        statusCode: 200,
      ),
    );

    await const TestArtifactCoordinator().attachLogArtifactsOnce(context);

    final line = context.logger.logs.singleWhere(
      (log) => log.startsWith('apiCalls:'),
    );
    final path = line.substring('apiCalls: '.length);
    final file =
        ensembleTestArtifactFile('logs', File(path).uri.pathSegments.last);
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    final payload = json.decode(file.readAsStringSync()) as Map;
    expect(payload['total'], 1);
    expect((payload['events'] as List).single['name'], 'getProfile');
  });

  test('shares API and console publication across subscriber and cleanup',
      () async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'log-once', steps: []),
    );
    const coordinator = TestArtifactCoordinator();

    final first = coordinator.attachLogArtifactsOnce(context);
    final second = coordinator.attachLogArtifactsOnce(context);

    expect(identical(first, second), isTrue);
    await first;
    expect(context.logger.logs.where((log) => log.startsWith('appLogs:')),
        hasLength(1));
  });
}
