import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/parser_value_decoder.dart';
import 'package:yaml/yaml.dart';

/// Parses and validates the nested steps in one test document.
///
/// Keeping recursive step parsing together makes group/optional behavior
/// explicit and leaves the top-level document parser focused on test metadata.
final class TestStepParser {
  static List<TestStep> parseSteps(
    YamlList steps, {
    required String testId,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
  }) {
    final parsed = _parseStepsList(
      steps,
      testId: testId,
      inputs: inputs,
      scenario: scenario,
      scenarioId: scenarioId,
    );
    for (final step in parsed) {
      _validateTestStep(step, testId);
    }
    return parsed;
  }

  static void _validateTestStep(TestStep step, String testId) {
    for (final nested in step.nestedSteps) {
      _validateTestStep(nested, testId);
    }
  }

  static List<TestStep> parseSetupSteps(
    dynamic steps, {
    required String testId,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
  }) {
    final parsed = _parseStepsList(
      steps,
      testId: testId,
      inputs: inputs,
      scenario: scenario,
      scenarioId: scenarioId,
      listName: 'setup',
    );
    for (final step in parsed) {
      _validateSetupStep(step, testId);
    }
    return parsed;
  }

  static void _validateSetupStep(TestStep step, String testId) {
    if (step.type == 'httpRequest') return;
    if (step.type == 'group' || step.type == 'optional') {
      for (final nested in step.nestedSteps) {
        _validateSetupStep(nested, testId);
      }
      return;
    }
    throw EnsembleTestFailure(
      'Test "$testId" setup only supports httpRequest, group, and optional, '
      'but found "${step.type}"',
    );
  }

  static List<TestStep> _parseStepsList(
    dynamic steps, {
    required String testId,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
    String listName = 'steps',
  }) {
    if (steps is! List || steps.isEmpty) {
      throw EnsembleTestFailure(
          'Test "$testId" requires a non-empty "$listName" list');
    }
    final result = <TestStep>[];
    for (var i = 0; i < steps.length; i++) {
      result.add(
        _parseStep(
          steps[i],
          testId: testId,
          index: i,
          inputs: inputs,
          scenario: scenario,
          scenarioId: scenarioId,
        ),
      );
    }
    return result;
  }

  static TestStep _parseStep(
    dynamic step, {
    required String testId,
    int? index,
    required Map<String, dynamic> inputs,
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
    final String type;
    final dynamic argsNode;

    if (step is YamlMap && step.length == 1) {
      type = step.keys.first.toString();
      argsNode = step[type];
    } else if (step is Map && step.length == 1) {
      type = step.keys.first.toString();
      argsNode = step[type];
    } else {
      throw EnsembleTestFailure(
        'Test "$testId" step ${index ?? ''} must be a single-key map '
        '(e.g. expectVisible: {...})',
      );
    }

    final args = _argsFromNode(
      argsNode,
      inputs: inputs,
      scenario: scenario,
      scenarioId: scenarioId,
    );

    List<TestStep> nested = const [];
    if (type == 'group' || type == 'repeat') {
      final stepsNode = args['steps'];
      if (stepsNode is List && stepsNode.isNotEmpty) {
        nested = _parseStepsList(
          stepsNode,
          testId: testId,
          inputs: inputs,
          scenario: scenario,
          scenarioId: scenarioId,
        );
      } else {
        throw EnsembleTestFailure('"$type" requires a non-empty "steps" list');
      }
    } else if (type == 'optional' || type == 'ifVisible') {
      final single = args['step'];
      if (single is YamlMap && single.length == 1) {
        nested = [
          _parseStep(
            single,
            testId: testId,
            inputs: inputs,
            scenario: scenario,
            scenarioId: scenarioId,
          ),
        ];
      } else if (single is Map && single.length == 1) {
        nested = [
          _parseStep(
            single,
            testId: testId,
            inputs: inputs,
            scenario: scenario,
            scenarioId: scenarioId,
          ),
        ];
      } else if (args['steps'] is List && (args['steps'] as List).isNotEmpty) {
        nested = _parseStepsList(
          args['steps'],
          testId: testId,
          inputs: inputs,
          scenario: scenario,
          scenarioId: scenarioId,
        );
      }
    }

    return TestStep(type: type, args: args, nestedSteps: nested);
  }

  static Map<String, dynamic> _argsFromNode(
    dynamic node, {
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
  }) {
    if (node is YamlMap) {
      return ParserValueDecoder.toStringDynamicMap(
        node,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    }
    if (node is Map) {
      return node.map(
        (key, value) => MapEntry(
          key.toString(),
          ParserValueDecoder.unwrap(
            value,
            inputs: inputs,
            scenario: scenario,
            scenarioId: scenarioId,
          ),
        ),
      );
    }
    if (node != null) {
      return {
        'value': ParserValueDecoder.unwrap(
          node,
          inputs: inputs,
          scenario: scenario,
          scenarioId: scenarioId,
        ),
      };
    }
    return {};
  }
}
