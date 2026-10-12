// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Decodes YAML values into the Dart values used by the runner.
///
/// This keeps recursive YAML conversion and placeholder resolution in one
/// small policy object. The document parser only decides which fields to
/// read; it does not need to know how nested values are decoded.
class ParserValueDecoder {
  const ParserValueDecoder._();

  static Map<String, dynamic> toStringDynamicMap(
    dynamic node, {
    required Map<String, dynamic> inputs,
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
    if (node == null) return {};
    if (node is! Map) throw EnsembleTestFailure('Expected a map');
    final out = <String, dynamic>{};
    node.forEach((key, value) {
      out[key.toString()] = unwrap(
        value,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    });
    return out;
  }

  static List<String> toStringList(
    dynamic node, {
    Map<String, dynamic> inputs = const {},
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
    if (node == null) return const [];
    if (node is! Iterable) throw EnsembleTestFailure('Expected a list');
    return node
        .map(
          (value) => unwrap(
            value,
            inputs: inputs,
            scenario: scenario,
            scenarioId: scenarioId,
          ).toString(),
        )
        .toList();
  }

  static List<String> toStringSelectorList(dynamic node) {
    if (node == null) return const [];
    if (node is String) {
      final value = node.trim();
      return value.isEmpty ? const [] : [value];
    }
    return toStringList(node);
  }

  static dynamic unwrap(
    dynamic value, {
    required Map<String, dynamic> inputs,
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
    if (value is Map) {
      return toStringDynamicMap(
        value,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    }
    if (value is Iterable) {
      return value
          .map(
            (item) => unwrap(
              item,
              inputs: inputs,
              scenario: scenario,
              scenarioId: scenarioId,
            ),
          )
          .toList();
    }
    if (value is String) {
      return resolvePlaceholders(
        value,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    }
    return value;
  }

  static dynamic resolvePlaceholders(
    String value, {
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
  }) {
    final exact = RegExp(r'^\$\{(inputs|scenario)\.([A-Za-z0-9_.-]+)\}$')
        .firstMatch(value);
    if (exact != null) {
      return placeholderValue(
        exact.group(1)!,
        exact.group(2)!,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    }
    return value.replaceAllMapped(
      RegExp(r'\$\{(inputs|scenario)\.([A-Za-z0-9_.-]+)\}'),
      (match) => placeholderValue(
        match.group(1)!,
        match.group(2)!,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      ).toString(),
    );
  }

  static dynamic placeholderValue(
    String namespace,
    String key, {
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
  }) {
    if (namespace == 'inputs') {
      if (!inputs.containsKey(key)) {
        throw EnsembleTestFailure(
          'Missing CLI input "$key". Pass it with --input $key=value.',
        );
      }
      return inputs[key];
    }
    if (scenarioId == null && scenario.isEmpty) {
      return '\${scenario.$key}';
    }
    if (!scenario.containsKey(key)) {
      throw EnsembleTestFailure(
        'Missing scenario value "$key"'
        '${scenarioId != null ? ' in scenario "$scenarioId"' : ''}.',
      );
    }
    return scenario[key];
  }
}
