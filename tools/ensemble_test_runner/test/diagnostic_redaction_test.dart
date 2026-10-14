import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/diagnostic_redaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('redacts credential fields recursively while preserving shape', () {
    final value = redactDiagnosticValue({
      'headers': {
        'Authorization': 'Bearer live-token',
        'X-API-Key': 'service-key',
        'Proxy-Authorization': 'proxy-secret',
        'x-request-id': 'request-1',
      },
      'body': {
        'password': 'secret-password',
        'profile': {'refreshToken': 'refresh-secret'},
        'visible': 'safe',
      },
      'items': [
        {'api_key': 'key-secret'},
      ],
    }) as Map<String, dynamic>;

    expect((value['headers'] as Map)['Authorization'], diagnosticRedactedValue);
    expect((value['headers'] as Map)['X-API-Key'], diagnosticRedactedValue);
    expect(
      (value['headers'] as Map)['Proxy-Authorization'],
      diagnosticRedactedValue,
    );
    expect((value['headers'] as Map)['x-request-id'], 'request-1');
    expect((value['body'] as Map)['password'], diagnosticRedactedValue);
    expect(
      ((value['body'] as Map)['profile'] as Map)['refreshToken'],
      diagnosticRedactedValue,
    );
    expect((value['body'] as Map)['visible'], 'safe');
    expect(
      ((value['items'] as List).single as Map)['api_key'],
      diagnosticRedactedValue,
    );
  });

  test('redacts credentials embedded in text and URLs', () {
    expect(
      redactDiagnosticText(
        'GET https://example.test?token=url-secret Authorization: Bearer abc',
      ),
      'GET https://example.test?token=<redacted> '
      'Authorization: Bearer <redacted>',
    );
    expect(redactDiagnosticText('password = p@ss, id=42'),
        'password = <redacted>, id=42');
  });

  test('API artifact publication redacts request and response payloads',
      () async {
    const prefix = 'diagnostic-redaction-boundary';
    final displayPath = await writeApiCallsLogFile(
      logger: TestLogger(),
      filePrefix: prefix,
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
    expect(json.encode(event), contains(diagnosticRedactedValue));
    expect(json.encode(event), isNot(contains('request-secret')));
    expect(json.encode(event), isNot(contains('request-api-key-secret')));
    expect(json.encode(event), isNot(contains('body-secret')));
    expect(json.encode(event), isNot(contains('response-secret')));
    expect((event['request'] as Map)['body']['name'], 'Ada');
  });
}

String _basename(String path) => File(path).uri.pathSegments.last;
