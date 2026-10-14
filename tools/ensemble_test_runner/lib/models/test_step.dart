/// Runtime representation of one executable test step.
library;

import 'package:ensemble_test_runner/src/core/operation_input.dart';

/// Mock configuration attached to a test case.
/// API mocks attached to a test after profile and suite composition.
class TestMocks {
  final Map<String, MockAPIResponse> apis;

  const TestMocks({this.apis = const {}});
}

/// Mock API response returned by the test HTTP provider.
/// A deterministic API response used by the test provider.
///
/// [responses] can provide a sequence of responses for repeated calls, and
/// [delayMs] simulates server latency while preserving the API loading state.
class MockAPIResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, dynamic>? headers;
  final int? delayMs;
  final List<MockAPIResponse> responses;

  const MockAPIResponse({
    this.statusCode = 200,
    this.body,
    this.headers,
    this.delayMs,
    this.responses = const [],
  });
}

/// Single executable step from a declarative test file.
class TestStep implements OperationInput {
  /// test step key (e.g. `expectVisible`, `group`).
  final String type;
  final Map<String, dynamic> args;
  final TestMocks mocks;

  /// Nested steps for control-flow step types such as `group` and `repeat`.
  final List<TestStep> nestedSteps;

  @override
  String get operationName => type;

  @override
  Map get arguments => args;

  const TestStep({
    required this.type,
    required this.args,
    this.mocks = const TestMocks(),
    this.nestedSteps = const [],
  });

  factory TestStep.fromJson(Map<String, dynamic> json) {
    final entries = json.entries
        .where((entry) => entry.key != 'steps')
        .toList(growable: false);
    if (entries.length != 1) {
      throw const FormatException('Serialized TestStep must contain one step.');
    }
    final entry = entries.single;
    final rawArgs = entry.value;
    return TestStep(
      type: entry.key,
      args: rawArgs is Map
          ? Map<String, dynamic>.from(rawArgs)
          : <String, dynamic>{'value': rawArgs},
      nestedSteps: (json['steps'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => TestStep.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        type: args,
        if (nestedSteps.isNotEmpty)
          'steps': nestedSteps.map((s) => s.toJson()).toList(),
      };
}
