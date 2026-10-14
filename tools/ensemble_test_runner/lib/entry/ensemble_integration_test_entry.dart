/// Integration-test entry point for declarative test suites.
library;

import 'package:ensemble_test_runner/entry/ensemble_test_entry_common.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/runtime/test_execution_binding.dart';

Future<void> runEnsembleIntegrationTests({
  Future<void> Function()? bootstrap,
  Map<String, Function>? externalMethods,
}) async {
  ensureExecutionBinding(ExecutionMode.integration);
  return registerEnsembleTestsInternal(
    EnsembleTestOptions(
      bootstrap: bootstrap,
      externalMethods: externalMethods,
      mode: ExecutionMode.integration,
    ),
    const [],
  );
}
