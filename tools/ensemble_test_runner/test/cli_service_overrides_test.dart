import 'package:ensemble_test_runner/cli/cli_service_overrides.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rewrites configured and readiness endpoints for a device host', () {
    final service = TestServiceConfig(
      name: 'api',
      command: 'server',
      url: 'http://127.0.0.1:8080/api',
      readyUrl: 'http://localhost:8080/ready',
    );

    final result = rewriteServiceOverridesForHost(
      {
        'api': {
          'url': 'http://127.0.0.1:8080/api',
          'environment': {'PORT': '8080'},
        },
      },
      [service],
      '10.0.2.2',
    );

    final api = result['api']! as Map<String, dynamic>;
    expect(api['url'], 'http://10.0.2.2:8080/api');
    expect(api['readyUrl'], 'http://10.0.2.2:8080/ready');
    expect(api['environment'], {'PORT': '8080'});
  });

  test('adds a missing service override from its configured endpoint', () {
    final result = rewriteServiceOverridesForHost(
      const {},
      [
        TestServiceConfig(
          name: 'api',
          command: 'server',
          url: 'http://127.0.0.1:8080',
        ),
      ],
      '10.0.2.2',
    );

    expect((result['api']! as Map<String, dynamic>)['url'],
        'http://10.0.2.2:8080');
  });
}
