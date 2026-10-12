import 'package:ensemble_test_runner/actions/runtime_operation_input.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolves gesture inputs and publishes their evidence at the action boundary.
final class TestStepGestureOperations {
  final Finder Function(OperationInput input) finderForInput;
  final Finder Function(String id) finderForId;
  final Future<void> Function(
    Finder finder,
    Offset offset, {
    required Future<void> Function() onBeforeDrag,
  }) dragFinder;
  final Future<void> Function(OperationInput input) emitEvidenceBoundary;

  const TestStepGestureOperations({
    required this.finderForInput,
    required this.finderForId,
    required this.dragFinder,
    required this.emitEvidenceBoundary,
  });

  Future<void> drag(OperationInput input) async {
    final target = _target(input);
    await _dispatch(
      input,
      target: target,
      offset: Offset(
        (input.arguments['dx'] as num?)?.toDouble() ?? 0,
        (input.arguments['dy'] as num?)?.toDouble() ?? -100,
      ),
      name: 'drag',
    );
  }

  Future<void> swipe(OperationInput input) async {
    final target = _swipeTarget(input);
    final offset = switch (input.arguments['direction']?.toString() ?? 'left') {
      'right' => const Offset(300, 0),
      'up' => const Offset(0, 300),
      'down' => const Offset(0, -300),
      _ => const Offset(-300, 0),
    };
    await _dispatch(input, target: target, offset: offset, name: 'swipe');
  }

  Future<void> pullToRefresh(OperationInput input) async {
    await _dispatch(
      input,
      target: _swipeTarget(input),
      offset: const Offset(0, 300),
      name: 'pullToRefresh',
    );
  }

  Finder _target(OperationInput input) {
    if (_hasStructuredTarget(input)) return finderForInput(input);
    return finderForId(RuntimeOperationInput.requiredTarget(input));
  }

  Finder _swipeTarget(OperationInput input) {
    if (_hasStructuredTarget(input)) return finderForInput(input);
    final id = input.arguments['id']?.toString();
    return id == null ? find.byType(Scrollable).first : finderForId(id);
  }

  bool _hasStructuredTarget(OperationInput input) =>
      input.arguments['target'] is Map || input.arguments['bounds'] is Map;

  Future<void> _dispatch(
    OperationInput input, {
    required Finder target,
    required Offset offset,
    required String name,
  }) async {
    if (target.evaluate().isEmpty) {
      throw EnsembleTestFailure('$name: target element was not found');
    }
    await dragFinder(
      target,
      offset,
      onBeforeDrag: () => emitEvidenceBoundary(input),
    );
  }
}
