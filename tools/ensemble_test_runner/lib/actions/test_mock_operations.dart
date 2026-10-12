import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/models/test_step.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart'
    show resolvedMocksKey;

/// Decodes mock definitions from either authored steps or compiled inputs.
abstract final class TestMockOperations {
  static TestMocks decode(OperationInput input) {
    if (input is TestStep) return input.mocks;

    final raw = input.arguments[resolvedMocksKey];
    if (raw is! Map) return const TestMocks();
    return TestMocks(
      apis: {
        for (final entry in raw.entries)
          entry.key.toString(): _decodeResponse(entry.value),
      },
    );
  }

  static MockAPIResponse _decodeResponse(Object? raw) {
    if (raw is! Map) {
      throw FormatException('Invalid resolved mock response: $raw');
    }
    final responses = raw['responses'];
    return MockAPIResponse(
      statusCode: raw['statusCode'] as int? ?? 200,
      body: _mutableCopy(raw['body']),
      headers: raw['headers'] is Map
          ? Map<String, dynamic>.from(_mutableCopy(raw['headers']) as Map)
          : null,
      delayMs: raw['delayMs'] as int?,
      responses: responses is List
          ? responses.map(_decodeResponse).toList(growable: false)
          : const [],
    );
  }

  static Object? _mutableCopy(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _mutableCopy(entry.value),
      };
    }
    if (value is List) return value.map(_mutableCopy).toList();
    return value;
  }
}
