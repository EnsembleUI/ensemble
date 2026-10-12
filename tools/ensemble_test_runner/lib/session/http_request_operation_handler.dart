import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';

/// Executes the support-service request operation at the runtime boundary.
///
/// `httpRequest` is an environment operation that does not depend on a
/// session-owned widget or application service. Keeping it here lets compiled
/// plans dispatch it directly and keeps the legacy step executor out of the
/// operation path.
final class HttpRequestOperationHandler {
  const HttpRequestOperationHandler();

  Future<void> execute(OperationInput input) => HttpRequestAction.execute(
        Map<String, dynamic>.from(input.arguments),
      );
}
