library;

import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:integration_test/integration_test.dart';

/// Explicit integration entry kept for backward compatibility.
///
/// Prefer [runApplicationYamlTests] — it selects widget vs integration from
/// `--dart-define=ensembleTestExecutionMode=` (set by the CLI).
Future<void> runApplicationIntegrationYamlTests({
  required ApplicationTestDriver driver,
  String? testsAssetPrefix,
}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  return registerApplicationYamlTests(
    driver: driver,
    mode: ExecutionMode.integration,
    testsAssetPrefix: testsAssetPrefix,
  );
}
