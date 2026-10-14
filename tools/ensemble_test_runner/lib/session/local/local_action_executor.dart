import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/session/local/flutter_target_resolver.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:flutter_test/flutter_test.dart';

/// Runs a registry-selected interaction in the local Flutter session.
final class LocalActionExecutor {
  LocalActionExecutor(
      {required this.executor, FlutterTargetResolver? resolver}) {
    if (resolver != null) {
      executor.resolveTargetFinder = (
        target, {
        bool requireInteractive = true,
        bool allowEmpty = false,
        bool allowOffscreen = false,
      }) =>
          resolver.resolveFinder(
            target,
            requireInteractive: requireInteractive,
            allowEmpty: allowEmpty,
            allowOffscreen: allowOffscreen,
          );
    }
  }

  final TestStepExecutor executor;

  Future<void> execute(TestOperation operation) async {
    final descriptor = operationRegistry.requireDescriptor(
      operation,
      expectedKind: OperationKind.interaction,
    );
    final handled = await executor.executeRegisteredInteraction(
      operation,
      descriptor: descriptor,
    );
    if (!handled) {
      throw StateError(
        'No local action is registered for "${descriptor.handlerKey}".',
      );
    }
  }
}
