library;

import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Registers an application suite with the integration-test binding.
///
/// Use [runApplicationTests] when the same entry must support both widget and
/// integration execution modes selected by the CLI.
Future<void> runApplicationIntegrationTests({
  required ApplicationTestDriver driver,
  String? testsAssetPrefix,
}) async {
  return registerApplicationTests(
    driver: driver,
    mode: ExecutionMode.integration,
    testsAssetPrefix: testsAssetPrefix,
  );
}
