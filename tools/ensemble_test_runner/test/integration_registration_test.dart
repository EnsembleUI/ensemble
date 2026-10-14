import 'package:ensemble_test_runner/src/integrations/test_integration_registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('installs selected integrations once and runs post-bootstrap hooks', () {
    final calls = <String>[];
    final registry = TestIntegrationRegistry([
      TestIntegrationRegistration(
        name: 'first',
        install: () => calls.add('install:first'),
        afterBootstrap: () => calls.add('bootstrap:first'),
      ),
      TestIntegrationRegistration(
        name: 'second',
        install: () => calls.add('install:second'),
      ),
    ]);

    registry.installAll();
    registry.installAll();
    registry.afterBootstrap();

    expect(calls, [
      'install:first',
      'install:second',
      'bootstrap:first',
    ]);
  });

  test('rejects duplicate integration names', () {
    final registration = TestIntegrationRegistration(
      name: 'duplicate',
      install: () {},
    );

    expect(
      () => TestIntegrationRegistry([registration, registration]),
      throwsArgumentError,
    );
  });
}
