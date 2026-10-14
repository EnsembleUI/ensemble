import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';

/// Adapts the session's structured action result to runtime failures.
final class ActionOperationHandler {
  const ActionOperationHandler(this.session);

  final LocalTestExecutionSession session;

  Future<void> execute(TestOperation operation) async {
    final result = await session.act(operation);
    if (result.succeeded) return;
    final error = result.error;
    if (error != null) throw error;
    throw EnsembleTestFailure('Action ${operation.name} failed');
  }
}
