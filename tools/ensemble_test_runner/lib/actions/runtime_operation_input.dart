import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';

/// Validates the common target and required-name inputs at the dispatch edge.
final class RuntimeOperationInput {
  const RuntimeOperationInput._();

  static String requiredTarget(OperationInput step) {
    final id = step.arguments['id']?.toString();
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('Step "${step.operationName}" requires "id"');
    }
    return id;
  }

  static String required(OperationInput step, String operation) {
    final value =
        step.arguments['name']?.toString() ?? step.arguments['key']?.toString();
    if (value == null) {
      throw EnsembleTestFailure(
        '$operation requires "${operation.startsWith('expectApi') ? 'name' : 'key'}"',
      );
    }
    return value;
  }

  static List<String> stringList(dynamic value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];

  static String targetDescription(OperationInput step) =>
      step.arguments['id']?.toString() ??
      step.arguments['target']?.toString() ??
      'target';
}
