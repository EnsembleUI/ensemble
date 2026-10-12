import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/actions/test_mock_operations.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';

/// Applies the compiled `mocks` operation at the session boundary.
///
/// The compiler carries resolved responses in a private wire field so the
/// operation remains serializable. Decoding here keeps runtime execution from
/// reconstructing a legacy [TestStep] solely to apply API mocks.
final class MockOperationHandler {
  const MockOperationHandler(this.session);

  final LocalTestExecutionSession session;

  /// Applies the operation selected by the registry's `api.mocks` key.
  Future<void> apply(OperationInput input) async {
    session.policy.ensurePrivilegedOperationPermitted('mocks');
    _apply(TestMockOperations.decode(input));
  }

  void _apply(TestMocks mocks) {
    final service = session.services.api;
    if (service is ApiMockingTestService) {
      service.applyMocks(mocks);
      return;
    }
    if (service != null) {
      throw const UnsupportedApplicationCapability('apiMocking');
    }
    if (session.harness == null) {
      throw const UnsupportedApplicationCapability('apiMocking');
    }
    for (final entry in mocks.apis.entries) {
      session.context.apiOverlay.setMock(entry.key, entry.value);
    }
  }
}
