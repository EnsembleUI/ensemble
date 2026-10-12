import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/models/test_document_keys.dart';
import 'package:ensemble_test_runner/parser/test_config_document_parser.dart';
import 'package:ensemble_test_runner/parser/parser_value_decoder.dart';
import 'package:ensemble_test_runner/parser/test_step_parser.dart';
import 'package:yaml/yaml.dart';

/// Parses test cases and suite configuration from test documents.
///
/// The parser is useful for tooling that wants to validate or inspect test
/// definitions without starting Flutter. Runtime execution is provided by
/// [runEnsembleTests].
class EnsembleTestParser {
  /// Loads a test file from disk.
  static Future<EnsembleTestCase> parseFile(
    String path, {
    Map<String, dynamic> inputs = const {},
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw EnsembleTestFailure('Test file not found: $path');
    }
    return parseString(
      await file.readAsString(),
      sourcePath: path,
      inputs: inputs,
      scenario: scenario,
      scenarioId: scenarioId,
    );
  }

  /// Parses one `*.test.yaml` document from [content].
  static EnsembleTestCase parseString(
    String content, {
    String? sourcePath,
    Map<String, dynamic> inputs = const {},
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
    return RunnerBenchmark.sync('parser', 'parseString', () {
      return parseDecodedDocument(
        loadYaml(content),
        sourcePath: sourcePath,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    });
  }

  /// Parses an already decoded YAML document. Suite planning uses this to
  /// reuse the document decoded for metadata-based selection.
  static EnsembleTestCase parseDocument(
    YamlMap doc, {
    String? sourcePath,
    Map<String, dynamic> inputs = const {},
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
    List<TestScenario>? parsedScenarios,
  }) =>
      parseDecodedDocument(
        doc,
        sourcePath: sourcePath,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
        parsedScenarios: parsedScenarios,
      );

  /// Parses a previously decoded document, validating its root before use.
  /// This lets selection and expansion share the same decoded tree even when
  /// service substitution changes the source text.
  static EnsembleTestCase parseDecodedDocument(
    dynamic doc, {
    String? sourcePath,
    Map<String, dynamic> inputs = const {},
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
    List<TestScenario>? parsedScenarios,
  }) {
    if (doc is! YamlMap) {
      throw EnsembleTestFailure(
          'Invalid test file${sourcePath != null ? ' ($sourcePath)' : ''}: root must be a map');
    }
    if (doc.containsKey('tests')) {
      throw EnsembleTestFailure(
        'Each *.test.yaml file defines one test at the root — remove the "tests" '
        'wrapper and put id, startScreen, and steps at the top level.',
      );
    }

    return _parseTestCase(
      doc,
      sourcePath: sourcePath,
      inputs: inputs,
      scenario: scenario,
      scenarioId: scenarioId,
      parsedScenarios: parsedScenarios,
    );
  }

  static EnsembleTestCase _parseTestCase(
    YamlMap map, {
    String? sourcePath,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
    List<TestScenario>? parsedScenarios,
  }) {
    final unsupportedKeys = TestDocumentKeys.unsupportedRootKeys(map.keys);
    if (unsupportedKeys.isNotEmpty) {
      throw EnsembleTestFailure(
        'Unsupported root key${unsupportedKeys.length == 1 ? '' : 's'} '
        '${unsupportedKeys.map((key) => '"$key"').join(', ')} in *.test.yaml file.',
      );
    }
    if (_hasDocumentKey(map, 'mocks') &&
        map['mocks'] is! YamlList &&
        map['mocks'] is! YamlMap) {
      throw EnsembleTestFailure(
        'Root-level "mocks" must be either a list of .mock.json files or an '
        'inline map of API mock responses.',
      );
    }

    final id = map['id']?.toString();
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('Each test must have an "id"');
    }

    final startScreen = map['startScreen']?.toString();
    final hasStartScreen = startScreen != null && startScreen.isNotEmpty;
    final session = map['session']?.toString();
    final hasSession = session != null && session.isNotEmpty;
    final profiles = ParserValueDecoder.toStringSelectorList(map['profiles']);

    final setupNode = map['setup'];
    final setupSteps = setupNode == null
        ? const <TestStep>[]
        : TestStepParser.parseSetupSteps(
            setupNode,
            testId: id,
            inputs: inputs,
            scenario: scenario,
            scenarioId: scenarioId,
          );

    final stepsNode = map['steps'];
    if (stepsNode is! YamlList || stepsNode.isEmpty) {
      throw EnsembleTestFailure(
          'Test "$id" must have a non-empty "steps" list');
    }
    final parsedMocks = parseMocksNode(
      map['mocks'],
      testId: id,
      inputs: inputs,
      scenario: scenario,
      scenarioId: scenarioId,
    );

    final scenarios =
        parsedScenarios ?? _parseScenarios(map['scenarios'], inputs: inputs);
    String? scenarioDescription;
    if (scenarioId != null) {
      for (final item in scenarios) {
        if (item.id == scenarioId) {
          scenarioDescription = item.description;
          break;
        }
      }
    }

    return EnsembleTestCase(
      id: id,
      sourcePath: sourcePath,
      type: map['type']?.toString(),
      feature: map['feature']?.toString(),
      tags: ParserValueDecoder.toStringList(map['tags']),
      description: map['description']?.toString(),
      owner: map['owner']?.toString(),
      priority: map['priority']?.toString(),
      parallel: map['parallel'] == false ? false : true,
      retry: TestConfigDocumentParser.optionalNonNegativeInt(
        map['retry'],
        fallback: 0,
        fieldName: '$id.retry',
      ),
      startScreen: hasStartScreen ? startScreen : null,
      startScreenInputs: ParserValueDecoder.toStringDynamicMap(
        map['startScreenInputs'],
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      ),
      session: hasSession ? session : null,
      profiles: profiles,
      scenarioId: scenarioId,
      scenarioDescription: scenarioDescription,
      mockFiles: parsedMocks.files,
      inlineMocks: parsedMocks.inline,
      scenarios: scenarios,
      initialState: ParserValueDecoder.toStringDynamicMap(
        map['initialState'],
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      ),
      setupSteps: setupSteps,
      steps: TestStepParser.parseSteps(
        stepsNode,
        testId: id,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      ),
    );
  }

  static ({List<String> files, Map<String, dynamic> inline}) parseMocksNode(
    dynamic node, {
    required String testId,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
  }) {
    if (node == null) return (files: const [], inline: const {});
    if (node is YamlMap) {
      return (
        files: const [],
        inline: ParserValueDecoder.toStringDynamicMap(
          node,
          inputs: inputs,
          scenario: scenario,
          scenarioId: scenarioId,
        ),
      );
    }
    if (node is Map) {
      return (
        files: const [],
        inline: Map<String, dynamic>.from(node),
      );
    }
    if (node is! List) {
      throw EnsembleTestFailure(
        'Test "$testId" mocks must be a list of .mock.json files/inline maps '
        'or an inline API mock map.',
      );
    }

    final files = <String>[];
    final inline = <String, dynamic>{};
    for (final entry in node) {
      final value = ParserValueDecoder.unwrap(
        entry,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
      if (value is String) {
        files.add(value);
      } else if (value is Map) {
        inline.addAll(Map<String, dynamic>.from(value));
      } else {
        throw EnsembleTestFailure(
          'Test "$testId" mocks entries must be .mock.json file paths or '
          'inline API mock maps.',
        );
      }
    }
    return (files: files, inline: inline);
  }

  /// Parses one suite `tests/config.yaml` document from [content].
  static EnsembleTestConfig parseConfigString(
    String content, {
    String? sourcePath,
  }) {
    return RunnerBenchmark.sync('parser', 'parseConfigString', () {
      if (content.trim().isEmpty) return const EnsembleTestConfig();
      final dynamic doc = loadYaml(content);
      if (doc == null) return const EnsembleTestConfig();
      if (doc is! YamlMap) {
        throw EnsembleTestFailure(
          'Invalid test config${sourcePath != null ? ' ($sourcePath)' : ''}: root must be a map',
        );
      }
      return TestConfigDocumentParser.parse(
        doc,
        parseMocks: parseMocksNode,
      );
    });
  }

  static List<TestScenario> _parseScenarios(
    dynamic node, {
    required Map<String, dynamic> inputs,
  }) {
    if (node == null) return const [];
    if (node is! YamlList) {
      throw EnsembleTestFailure('"scenarios" must be a list');
    }
    final scenarios = <TestScenario>[];
    final ids = <String>{};
    for (final item in node) {
      if (item is! YamlMap) {
        throw EnsembleTestFailure('Each scenario must be a map');
      }
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        throw EnsembleTestFailure('Each scenario must have an "id"');
      }
      if (!ids.add(id)) {
        throw EnsembleTestFailure('Duplicate scenario id "$id"');
      }
      final vars = ParserValueDecoder.toStringDynamicMap(
        item['vars'],
        inputs: inputs,
        scenario: const {},
        scenarioId: id,
      );
      scenarios.add(
        TestScenario(
          id: id,
          description: item['description']?.toString(),
          vars: vars,
        ),
      );
    }
    return scenarios;
  }

  static bool _hasDocumentKey(YamlMap map, String key) {
    return map.keys.any((candidate) => candidate.toString() == key);
  }
}
