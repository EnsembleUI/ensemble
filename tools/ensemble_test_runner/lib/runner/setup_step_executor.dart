import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';

/// Executes the small action vocabulary allowed before the application starts.
///
/// Setup intentionally has no widget access. Keeping it separate from the
/// runtime runner makes the pre-screen contract explicit and prevents setup
/// actions from growing into a second step executor.
final class SetupStepExecutor {
  const SetupStepExecutor();

  static final Map<String, Future<void> Function(TestStep)> _handlers =
      Map.unmodifiable({
    'httpRequest': (step) => HttpRequestAction.execute(step.args),
    'group': _executeGroup,
    'optional': _executeOptional,
  });

  Future<void> execute(EnsembleTestCase test) async {
    for (var i = 0; i < test.setupSteps.length; i++) {
      final step = test.setupSteps[i];
      try {
        await _executeStep(step);
      } catch (error) {
        throw EnsembleTestFailure(
          'Setup ${i + 1} ${formatStepBrief(step)} failed: $error',
        );
      }
    }
  }

  /// Runs the shared setup stage with adapter-owned work around its edges.
  ///
  /// The standalone runner restores a saved session before setup steps, while
  /// an application-owned runner applies in-place setup after them. Keeping
  /// those hooks around the same executor makes the setup ordering explicit
  /// without folding either launch policy into this mode-neutral stage.
  Future<void> executeAttemptSetup(
    EnsembleTestCase test, {
    Future<void> Function()? beforeSteps,
    Future<void> Function()? afterSteps,
  }) async {
    await beforeSteps?.call();
    await execute(test);
    await afterSteps?.call();
  }

  static Future<void> _executeStep(TestStep step) async {
    final handler = _handlers[step.type];
    if (handler == null) {
      throw EnsembleTestFailure('Unsupported setup action "${step.type}"');
    }
    await handler(step);
  }

  static Future<void> _executeGroup(TestStep step) async {
    for (final nested in step.nestedSteps) {
      await _executeStep(nested);
    }
  }

  static Future<void> _executeOptional(TestStep step) async {
    try {
      await _executeGroup(step);
    } catch (_) {
      // Optional setup is best effort.
    }
  }
}
