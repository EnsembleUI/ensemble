import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/core/operation.dart'
    show OperationKind, TestOperation;
import 'package:ensemble_test_runner/src/core/operation_registry.dart'
    show OperationDescriptor;
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;

/// Direct runtime entry for lifecycle operations.
///
/// The operation already contains the canonical name and decoded arguments, so
/// sending it to the shared executor avoids rebuilding a test step and running
/// a second route classification pass.
final class LifecycleOperationHandler {
  LifecycleOperationHandler(this.session);

  final LocalTestExecutionSession session;

  /// Executes the lifecycle operation selected by its registry handler key.
  Future<void> execute(TestOperation operation) async {
    final descriptor = _descriptorsByHandlerKey[operation.handlerKey];
    if (descriptor == null) {
      throw ArgumentError.value(
        operation.handlerKey,
        'operation.handlerKey',
        'Unsupported lifecycle operation',
      );
    }
    if (descriptor.name != operation.name ||
        descriptor.handlerKey != operation.handlerKey) {
      throw ArgumentError.value(
        operation,
        'operation',
        'Lifecycle operation does not match its selected descriptor.',
      );
    }
    session.policy.ensureLifecycleOperationPermitted(descriptor.name);
    await session.executor.executeRegisteredLifecycleInput(
      descriptor,
      operation,
    );
  }

  static final Map<String, OperationDescriptor> _descriptorsByHandlerKey =
      Map.unmodifiable({
    for (final descriptor in operationRegistry.descriptors)
      if (descriptor.kind == OperationKind.lifecycle)
        descriptor.handlerKey: descriptor,
  });
}
