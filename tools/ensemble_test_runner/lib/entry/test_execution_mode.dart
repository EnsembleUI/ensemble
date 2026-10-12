import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Resolves the runtime mode, allowing the CLI's environment override to
/// apply consistently to widget and application entry points.
ExecutionMode resolveExecutionMode(ExecutionMode configured) {
  const envMode = String.fromEnvironment('ensembleTestExecutionMode');
  return envMode == ExecutionMode.integration.name
      ? ExecutionMode.integration
      : configured;
}

ExecutionMode executionModeFromEnvironment() =>
    resolveExecutionMode(ExecutionMode.widget);
