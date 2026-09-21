import 'package:ensemble_test_runner/ensemble_test_runner.dart';

import 'host_app_test_driver.dart';

Future<void> main() {
  const integration =
      String.fromEnvironment('ensembleTestExecutionMode') == 'integration';
  if (integration) {
    return runApplicationIntegrationYamlTests(driver: HostAppTestDriver());
  }
  return runApplicationYamlTests(driver: HostAppTestDriver());
}
