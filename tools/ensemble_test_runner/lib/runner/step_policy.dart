import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;

/// Stateless classification rules shared by execution and screenshot paths.
///
/// Keeping these rules outside the runner makes the orchestration class focus
/// on lifecycle coordination while preserving one canonical definition for
/// action, assertion, and optional-step semantics.
bool isUserActionStep(TestStep step) =>
    operationRegistry.lookup(step.type)?.userAction ?? false;

bool isTextMutationStep(TestStep step) =>
    step.type == 'enterText' ||
    step.type == 'clearText' ||
    step.type == 'replaceText';

bool isTextVerificationStep(TestStep step) =>
    step.type == 'expectText' ||
    step.type == 'expectTextContains' ||
    step.type == 'waitForText' ||
    step.type == 'expectNoText';

bool shouldHighlightStep(TestStep step, {bool forFailure = false}) {
  // On success there is nothing to point at for expectNoText; on failure the
  // unexpectedly visible text is exactly what the screenshot should mark.
  if (step.type == 'expectNoText' &&
      !forFailure &&
      (step.args['id']?.toString().isEmpty ?? true) &&
      step.args['target'] is! Map) {
    return false;
  }
  if (step.type == 'waitForText' ||
      step.type == 'expectText' ||
      step.type == 'expectNoText' ||
      step.type == 'waitFor' ||
      step.type == 'expectTextContains' ||
      step.type == 'scrollUntilVisible' ||
      step.type == 'expectVisible' ||
      step.type == 'expectValue' ||
      step.type == 'expectSemanticsLabel') {
    final text = step.args['text']?.toString();
    final anyOf = step.args['anyOf'];
    final id = step.args['id']?.toString();
    final hasAnyOf = anyOf is List && anyOf.isNotEmpty;
    final hasTarget = step.args['target'] is Map;
    return (text != null && text.isNotEmpty) ||
        hasAnyOf ||
        (id != null && id.isNotEmpty) ||
        hasTarget;
  }
  return isUserActionStep(step);
}
