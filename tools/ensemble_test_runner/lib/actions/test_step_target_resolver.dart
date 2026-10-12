import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolves the widget target described by a test step.
///
/// Target resolution is shared by actions, assertions, and wait operations.
/// Keeping the target rules in one small service prevents those paths from
/// drifting as locator support evolves.
typedef TargetFinderResolver = Finder Function(
  ElementTarget target, {
  bool requireInteractive,
  bool allowEmpty,
  bool allowOffscreen,
});

class TestStepTargetResolver {
  final AssertionEngine assertions;
  final TargetFinderResolver? Function() resolveTargetFinder;

  const TestStepTargetResolver({
    required this.assertions,
    required this.resolveTargetFinder,
  });

  String requireId(TestStep step) {
    final id = step.args['id']?.toString();
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('Step "${step.type}" requires "id"');
    }
    return id;
  }

  Finder finderForStep(
    TestStep step, {
    bool requireInteractive = true,
    bool allowEmpty = false,
    bool allowOffscreen = false,
  }) =>
      finderForInput(
        step,
        requireInteractive: requireInteractive,
        allowEmpty: allowEmpty,
        allowOffscreen: allowOffscreen,
      );

  Finder finderForInput(
    OperationInput operation, {
    bool requireInteractive = true,
    bool allowEmpty = false,
    bool allowOffscreen = false,
  }) =>
      finderForTarget(
        targetForInput(operation),
        operationName: operation.operationName,
        requireInteractive: requireInteractive,
        allowEmpty: allowEmpty,
        allowOffscreen: allowOffscreen,
      );

  Finder finderForTargetArgs(
    Map<String, dynamic> args, {
    String operationName = 'ifVisible',
    bool requireInteractive = true,
    bool allowEmpty = false,
    bool allowOffscreen = false,
  }) =>
      finderForTarget(
        ElementTarget.fromOperationArgs(args),
        operationName: operationName,
        requireInteractive: requireInteractive,
        allowEmpty: allowEmpty,
        allowOffscreen: allowOffscreen,
      );

  Finder finderForTarget(
    ElementTarget target, {
    required String operationName,
    bool requireInteractive = true,
    bool allowEmpty = false,
    bool allowOffscreen = false,
  }) {
    final resolve = resolveTargetFinder();
    final needsExactResolution =
        target.locator != null || target.usesSnapshotElement;
    if (resolve != null &&
        (needsExactResolution || requireInteractive || allowEmpty)) {
      // The session resolver validates ambiguity and preserves occurrence or
      // snapshot identity, including simple testId targets. Falling back to a
      // key finder here can match several widgets and fail later in
      // ensureVisible with an unhelpful StateError.
      return resolve(
        target,
        requireInteractive: requireInteractive,
        allowEmpty: allowEmpty,
        allowOffscreen: allowOffscreen,
      );
    }
    if (needsExactResolution) {
      throw EnsembleTestFailure(
        'Operation "$operationName" requires a session target resolver.',
      );
    }
    final id = target.testId;
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure(
        'Operation "$operationName" requires "id" or "target"',
      );
    }
    return assertions.finderForId(id, skipOffstage: requireInteractive);
  }

  ElementTarget targetForStep(TestStep step) {
    return targetForInput(step);
  }

  ElementTarget targetForInput(OperationInput operation) {
    final args = Map<String, dynamic>.from(operation.arguments);
    final target = ElementTarget.fromOperationArgs(args);
    if (target.testId != null ||
        target.usesSnapshotElement ||
        target.locator != null) {
      return target;
    }
    final itemId = args['itemId']?.toString();
    return itemId == null || itemId.isEmpty
        ? target
        : ElementTarget(testId: itemId);
  }

  String descriptionFor(TestStep step) => descriptionForInput(step);

  String descriptionForInput(OperationInput operation) =>
      operation.arguments['id']?.toString() ??
      operation.arguments['itemId']?.toString() ??
      operation.arguments['target']?.toString() ??
      'target';
}
