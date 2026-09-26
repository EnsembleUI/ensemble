import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_action_executor.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finder used to draw the report screenshot highlight for [step].
///
/// Supports YAML `id:`, structured `target:` (label/role/text/id), and
/// text/`anyOf` and element-value/semantics assertion steps. Returns null when
/// nothing can be resolved.
Finder? stepHighlightFinder({
  required WidgetTester tester,
  required AssertionEngine assertions,
  required TestStep step,
}) {
  final id = step.args['id']?.toString();
  if (id != null && id.isNotEmpty) {
    return assertions.finderForId(id);
  }

  final targetRaw = step.args['target'];
  if (targetRaw is Map) {
    final locator = ElementLocator.fromJson(
      Map<String, dynamic>.from(targetRaw),
    );
    if (!locator.isEmpty) {
      try {
        return FlutterTargetResolver(
          tester: tester,
          assertions: assertions,
          registry: ObservationRegistry(),
        ).resolveFinder(
          ElementTarget(locator: locator),
          requireInteractive: false,
          allowEmpty: true,
        );
      } on TestExecutionError {
        return null;
      }
    }
  }

  final texts = <String>[
    if (step.args['text']?.toString().trim().isNotEmpty == true)
      step.args['text'].toString(),
    if (step.args['anyOf'] is List)
      for (final item in step.args['anyOf'] as List)
        if (item != null && item.toString().trim().isNotEmpty) item.toString(),
  ];
  for (final text in texts) {
    if (step.type == 'expectTextContains') {
      final containing = find.textContaining(text);
      if (_hasHighlightRect(assertions, containing)) {
        return containing;
      }
    } else {
      final exact = find.text(text);
      if (_hasHighlightRect(assertions, exact)) {
        return exact;
      }
    }
  }
  return null;
}

/// Convenience overload for [TestStepExecutor] call sites.
Finder? stepHighlightFinderForExecutor(
  TestStepExecutor executor,
  TestStep step,
) {
  return stepHighlightFinder(
    tester: executor.tester,
    assertions: executor.assertions,
    step: step,
  );
}

bool _hasHighlightRect(AssertionEngine assertions, Finder finder) {
  return assertions.rectForVisuallyActionable(finder) != null;
}
