import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Initializes the Flutter binding selected for a test execution mode.
///
/// Keeping this choice in one place lets the runner entries share binding
/// setup while leaving the mode-specific runtime bootstrap in its adapters.
void ensureExecutionBinding(ExecutionMode mode) {
  if (mode == ExecutionMode.integration) {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  } else {
    LiveTestWidgetsFlutterBinding.ensureInitialized();
  }
}
