import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('API artifacts preserve credential and response values', () async {
    final displayPath = await writeApiCallsLogFile(
      logger: TestLogger(),
      filePrefix: 'diagnostic-visible-values',
      calls: [
        APICallRecord(
          name: 'login',
          apiDefinition: YamlMap.wrap({
            'url': 'https://example.test/login',
            'headers': {
              'Authorization': 'Bearer request-secret',
              'X-API-Key': 'request-api-key-secret',
            },
          }),
          timestamp: DateTime(2026),
          resolvedBody: {'password': 'body-secret', 'name': 'Ada'},
          responseBody: {'accessToken': 'response-secret'},
        ),
      ],
    );
    addTearDown(() {
      final file = ensembleTestArtifactFile('logs', _basename(displayPath));
      if (file.existsSync()) file.deleteSync();
    });

    final payload = json.decode(
      ensembleTestArtifactFile('logs', _basename(displayPath))
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final event = (payload['events'] as List).single as Map<String, dynamic>;
    final serialized = json.encode(event);
    expect(serialized, contains('request-secret'));
    expect(serialized, contains('request-api-key-secret'));
    expect(serialized, contains('body-secret'));
    expect(serialized, contains('response-secret'));
    expect((event['request'] as Map)['body']['name'], 'Ada');
  });

  test('completed API calls preserve an explicit null response', () async {
    final call = APICallRecord(
      name: 'emptyResponse',
      apiDefinition: YamlMap.wrap({}),
      timestamp: DateTime(2026),
      statusCode: 204,
    )..completed = true;
    final displayPath = await writeApiCallsLogFile(
      logger: TestLogger(),
      filePrefix: 'diagnostic-null-response',
      calls: [call],
    );
    addTearDown(() {
      final file = ensembleTestArtifactFile('logs', _basename(displayPath));
      if (file.existsSync()) file.deleteSync();
    });

    final payload = json.decode(
      ensembleTestArtifactFile('logs', _basename(displayPath))
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final event = (payload['events'] as List).single as Map<String, dynamic>;
    expect(event.containsKey('responseBody'), isTrue);
    expect(event['responseBody'], isNull);
    expect(event['completed'], isTrue);
  });

  test('pending API calls are explicitly marked incomplete', () async {
    final displayPath = await writeApiCallsLogFile(
      logger: TestLogger(),
      filePrefix: 'diagnostic-pending-call',
      calls: [
        APICallRecord(
          name: 'slowRequest',
          apiDefinition: YamlMap.wrap({}),
          timestamp: DateTime(2026),
        ),
      ],
    );
    addTearDown(() {
      final file = ensembleTestArtifactFile('logs', _basename(displayPath));
      if (file.existsSync()) file.deleteSync();
    });

    final payload = json.decode(
      ensembleTestArtifactFile('logs', _basename(displayPath))
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final event = (payload['events'] as List).single as Map<String, dynamic>;
    expect(event['completed'], isFalse);
    expect(event.containsKey('responseBody'), isFalse);
  });

  test('API artifact publication handles cyclic response payloads', () async {
    final response = <String, Object?>{'ok': true};
    response['self'] = response;
    final displayPath = await writeApiCallsLogFile(
      logger: TestLogger(),
      filePrefix: 'diagnostic-cyclic-response',
      calls: [
        APICallRecord(
          name: 'getDocument',
          apiDefinition: YamlMap.wrap({}),
          timestamp: DateTime(2026),
          responseBody: response,
        ),
      ],
    );
    addTearDown(() {
      final file = ensembleTestArtifactFile('logs', _basename(displayPath));
      if (file.existsSync()) file.deleteSync();
    });

    final payload = json.decode(
      ensembleTestArtifactFile('logs', _basename(displayPath))
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final event = (payload['events'] as List).single as Map<String, dynamic>;
    expect(event['responseBody'], {
      'ok': true,
      'self': '<circular reference>',
    });
  });
}

String _basename(String path) => File(path).uri.pathSegments.last;
