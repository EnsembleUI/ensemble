/// Integration-test entry point for declarative Ensemble YAML suites.
library;

import 'package:ensemble_test_runner/entry/ensemble_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:integration_test/integration_test.dart';

Future<void> runEnsembleIntegrationYamlTests({
  Future<void> Function()? bootstrap,
  Map<String, Function>? externalMethods,
}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  return registerEnsembleYamlTests(
    EnsembleYamlTestOptions(
      bootstrap: bootstrap,
      externalMethods: externalMethods,
      mode: ExecutionMode.integration,
    ),
  );
}
