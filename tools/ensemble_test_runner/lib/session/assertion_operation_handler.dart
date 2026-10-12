import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';

/// Adapts the session's structured assertion result to runtime failures.
final class AssertionOperationHandler {
  const AssertionOperationHandler(this.session);

  final LocalTestExecutionSession session;

  Future<void> execute(TestOperation operation) async {
    final result = await session.assertCondition(operation);
    if (result.passed) return;
    final error = result.error;
    if (error != null) throw error;
    throw EnsembleTestFailure(
      result.message ?? 'Assertion ${operation.name} failed',
    );
  }
}
