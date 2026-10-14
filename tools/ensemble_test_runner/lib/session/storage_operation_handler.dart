import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/actions/test_environment_operations.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';

/// Executes public storage mutations at the session boundary.
///
/// Storage is a privileged environment concern, so keeping its three
/// mutations together avoids rebuilding a legacy [TestStep] and lets hosted
/// applications provide their own storage service without changing the test
/// contract.
final class StorageOperationHandler {
  StorageOperationHandler(this.session);

  final LocalTestExecutionSession session;

  /// Executes the registered `setStorage` operation directly.
  Future<void> set(OperationInput input) async {
    session.policy.ensurePrivilegedOperationPermitted('setStorage');
    await TestStorageOperations.write(
      services: session.services,
      context: session.context,
      hasHarness: session.harness != null,
      operation: input,
    );
  }

  /// Executes the registered `removeStorage` operation directly.
  Future<void> remove(OperationInput input) async {
    session.policy.ensurePrivilegedOperationPermitted('removeStorage');
    await TestStorageOperations.remove(
      services: session.services,
      context: session.context,
      hasHarness: session.harness != null,
      operation: input,
    );
  }

  /// Executes the registered `clearStorage` operation directly.
  Future<void> clear() async {
    session.policy.ensurePrivilegedOperationPermitted('clearStorage');
    await _clear();
  }

  Future<void> _clear() async {
    await TestStorageOperations.clear(
      services: session.services,
      context: session.context,
      hasHarness: session.harness != null,
    );
  }
}
