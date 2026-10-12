import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/actions/test_environment_operations.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';

/// Executes the environment mutation that has a direct session context API.
///
/// Runtime environment operations use the context and runtime state directly.
/// This avoids rebuilding a legacy [TestStep] for operations whose mutation
/// boundary is already owned by the session context.
final class EnvironmentOperationHandler {
  EnvironmentOperationHandler(this.session);

  final LocalTestExecutionSession session;

  /// Executes the registered `setEnv` operation directly.
  ///
  /// The compiled runtime selects this method from the operation registry's
  /// handler key. That keeps the operation name out of the runtime boundary.
  Future<void> set(OperationInput input) async {
    session.policy.ensurePrivilegedOperationPermitted('setEnv');
    applyTestEnvironmentOverride(context: session.context, input: input);
  }

  /// Executes the registered `resetApiCalls` operation directly.
  Future<void> resetApiCalls([Map<String, dynamic> input = const {}]) async {
    session.policy.ensurePrivilegedOperationPermitted('resetApiCalls');
    _resetApiCalls();
  }

  Future<void> setPermission(OperationInput input) async {
    session.policy.ensurePrivilegedOperationPermitted('setPermission');
    applyTestPermission(context: session.context, input: input);
  }

  Future<void> setLocale(OperationInput input) async {
    session.policy.ensurePrivilegedOperationPermitted('setLocale');
    applyTestLocale(session.context, input);
  }

  Future<void> setDevice(OperationInput input) async {
    session.policy.ensurePrivilegedOperationPermitted('setDevice');
    await applyTestDeviceSize(
      tester: session.tester,
      context: session.context,
      harness: session.harness,
      input: input,
      settle: session.executor.settle,
    );
  }

  Future<void> setTheme(OperationInput input) async {
    session.policy.ensurePrivilegedOperationPermitted('setTheme');
    final raw = input.arguments['mode']?.toString() ??
        input.arguments['theme']?.toString();
    await applyTestTheme(
      context: session.context,
      theme: raw,
      pump: session.tester.pump,
    );
  }

  void _resetApiCalls() {
    resetTestApiCalls(
      services: session.services,
      context: session.context,
      hasHarness: session.harness != null,
    );
  }
}
