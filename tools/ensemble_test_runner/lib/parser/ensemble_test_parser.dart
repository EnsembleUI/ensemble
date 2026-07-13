import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:yaml/yaml.dart';

class EnsembleTestParser {
  /// Loads a test file from disk.
  static Future<EnsembleTestCase> parseFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw EnsembleTestFailure('Test file not found: $path');
    }
    return parseString(await file.readAsString(), sourcePath: path);
  }

  static EnsembleTestCase parseString(String content, {String? sourcePath}) {
    final dynamic doc = loadYaml(content);
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

    return _parseTestCase(doc, sourcePath: sourcePath);
  }

  static EnsembleTestCase _parseTestCase(YamlMap map, {String? sourcePath}) {
    if (map.containsKey('options')) {
      throw EnsembleTestFailure(
        'Root-level "options" is no longer supported in *.test.yaml files. '
        'Move shared screenshots/performance settings to tests/config.yaml.',
      );
    }

    final id = map['id']?.toString();
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('Each test must have an "id"');
    }

    final startScreen = map['startScreen']?.toString();
    final hasStartScreen = startScreen != null && startScreen.isNotEmpty;
    final prerequisite = map['prerequisite']?.toString();
    final hasPrerequisite = prerequisite != null && prerequisite.isNotEmpty;

    if (hasStartScreen && hasPrerequisite) {
      throw EnsembleTestFailure(
        'Test "$id" must have either "startScreen" or "prerequisite", not both',
      );
    }
    if (!hasStartScreen && !hasPrerequisite) {
      throw EnsembleTestFailure(
        'Test "$id" must have either "startScreen" or "prerequisite"',
      );
    }

    final stepsNode = map['steps'];
    if (stepsNode is! YamlList || stepsNode.isEmpty) {
      throw EnsembleTestFailure(
          'Test "$id" must have a non-empty "steps" list');
    }

    return EnsembleTestCase(
      id: id,
      sourcePath: sourcePath,
      type: map['type']?.toString(),
      feature: map['feature']?.toString(),
      tags: _toStringList(map['tags']),
      description: map['description']?.toString(),
      owner: map['owner']?.toString(),
      priority: map['priority']?.toString(),
      startScreen: hasStartScreen ? startScreen : null,
      prerequisite: hasPrerequisite ? prerequisite : null,
      initialState: _toStringDynamicMap(map['initialState']),
      mocks: _parseMocks(map['mocks']),
      steps: _parseSteps(stepsNode, testId: id),
    );
  }

  static EnsembleTestConfig parseConfigString(
    String content, {
    String? sourcePath,
  }) {
    if (content.trim().isEmpty) return const EnsembleTestConfig();
    final dynamic doc = loadYaml(content);
    if (doc == null) return const EnsembleTestConfig();
    if (doc is! YamlMap) {
      throw EnsembleTestFailure(
        'Invalid test config${sourcePath != null ? ' ($sourcePath)' : ''}: root must be a map',
      );
    }
    return _parseConfig(doc);
  }

  static EnsembleTestConfig _parseConfig(YamlMap node) {
    final screenshotsNode = node['screenshots'];
    final performanceNode = node['performance'];
    final dumpTreeNode = node['dumpTree'];
    final logApiCallsNode = node['logApiCalls'];
    final logStorageNode = node['logStorage'];
    if (screenshotsNode != null && screenshotsNode is! YamlMap) {
      throw EnsembleTestFailure('"screenshots" must be a map');
    }
    if (performanceNode != null && performanceNode is! YamlMap) {
      throw EnsembleTestFailure('"performance" must be a map');
    }
    if (dumpTreeNode != null && dumpTreeNode is! YamlMap) {
      throw EnsembleTestFailure('"dumpTree" must be a map');
    }
    if (logApiCallsNode != null && logApiCallsNode is! YamlMap) {
      throw EnsembleTestFailure('"logApiCalls" must be a map');
    }
    if (logStorageNode != null && logStorageNode is! YamlMap) {
      throw EnsembleTestFailure('"logStorage" must be a map');
    }

    return EnsembleTestConfig(
      screenshots: screenshotsNode == null
          ? const ScreenshotConfig()
          : ScreenshotConfig(
              enabled: screenshotsNode['enabled'] == true,
              platform: screenshotsNode['platform']?.toString() ?? 'ios',
              model: screenshotsNode['model']?.toString() ?? 'iPhone 15 Pro',
              includeSteps: _toStringList(screenshotsNode['includeSteps']),
              excludeSteps: _toStringList(screenshotsNode['excludeSteps']),
            ),
      performance: performanceNode == null
          ? const PerformanceConfig()
          : PerformanceConfig(
              enabled: performanceNode['enabled'] == true,
            ),
      dumpTree: dumpTreeNode == null
          ? const DumpTreeConfig()
          : DumpTreeConfig(
              enabled: dumpTreeNode['enabled'] == true,
            ),
      logApiCalls: logApiCallsNode == null
          ? const LogApiCallsConfig()
          : LogApiCallsConfig(
              enabled: logApiCallsNode['enabled'] == true,
            ),
      logStorage: logStorageNode == null
          ? const LogStorageConfig()
          : LogStorageConfig(
              enabled: logStorageNode['enabled'] == true,
              key: logStorageNode['key']?.toString(),
            ),
    );
  }

  static TestMocks _parseMocks(dynamic node) {
    if (node == null) return const TestMocks();
    if (node is! YamlMap) {
      throw EnsembleTestFailure('"mocks" must be a map');
    }

    final apisNode = node['apis'];
    if (apisNode == null) return const TestMocks();
    if (apisNode is! YamlMap) {
      throw EnsembleTestFailure('"mocks.apis" must be a map');
    }

    final apis = <String, MockAPIResponse>{};
    apisNode.forEach((key, value) {
      if (value is! YamlMap) {
        throw EnsembleTestFailure('Mock for API "$key" must be a map');
      }
      apis[key.toString()] = _parseMockApiResponse(value);
    });

    return TestMocks(apis: apis);
  }

  static MockAPIResponse _parseMockApiResponse(YamlMap map) {
    final response = map['response'];
    if (response is! YamlMap) {
      throw EnsembleTestFailure('API mock must include a "response" map');
    }

    return MockAPIResponse(
      statusCode: response['statusCode'] as int? ?? 200,
      body: _unwrapYaml(response['body']),
      headers: response['headers'] is YamlMap
          ? _toStringDynamicMap(response['headers'])
          : null,
      delayMs: map['delayMs'] as int?,
    );
  }

  static List<TestStep> _parseSteps(YamlList steps, {required String testId}) =>
      _parseStepsList(steps, testId: testId);

  static List<TestStep> _parseStepsList(dynamic steps,
      {required String testId}) {
    if (steps is! List || steps.isEmpty) {
      throw EnsembleTestFailure(
          'Test "$testId" requires a non-empty "steps" list');
    }
    final result = <TestStep>[];
    for (var i = 0; i < steps.length; i++) {
      result.add(_parseStep(steps[i], testId: testId, index: i));
    }
    return result;
  }

  static TestStep _parseStep(dynamic step,
      {required String testId, int? index}) {
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

    final args = _argsFromNode(argsNode);

    List<TestStep> nested = const [];
    if (type == 'group' || type == 'repeat') {
      final stepsNode = args['steps'];
      if (stepsNode is List && stepsNode.isNotEmpty) {
        nested = _parseStepsList(stepsNode, testId: testId);
      } else {
        throw EnsembleTestFailure('"$type" requires a non-empty "steps" list');
      }
    } else if (type == 'optional' || type == 'ifVisible') {
      final single = args['step'];
      if (single is YamlMap && single.length == 1) {
        nested = [_parseStep(single, testId: testId)];
      } else if (single is Map && single.length == 1) {
        nested = [_parseStep(single, testId: testId)];
      } else if (args['steps'] is List && (args['steps'] as List).isNotEmpty) {
        nested = _parseStepsList(args['steps'], testId: testId);
      }
    }

    return TestStep(type: type, args: args, nestedSteps: nested);
  }

  static Map<String, dynamic> _argsFromNode(dynamic node) {
    if (node is YamlMap) {
      return _toStringDynamicMap(node);
    }
    if (node is Map) {
      return node.map(
        (key, value) => MapEntry(key.toString(), _unwrapYaml(value)),
      );
    }
    if (node != null) {
      return {'value': _unwrapYaml(node)};
    }
    return {};
  }

  static Map<String, dynamic> _toStringDynamicMap(dynamic node) {
    if (node == null) return {};
    if (node is! YamlMap) {
      throw EnsembleTestFailure('Expected a map');
    }
    final out = <String, dynamic>{};
    node.forEach((key, value) {
      out[key.toString()] = _unwrapYaml(value);
    });
    return out;
  }

  static List<String> _toStringList(dynamic node) {
    if (node == null) return const [];
    if (node is! Iterable) {
      throw EnsembleTestFailure('Expected a list');
    }
    return node.map((value) => value.toString()).toList();
  }

  static dynamic _unwrapYaml(dynamic value) {
    if (value is YamlMap) {
      return _toStringDynamicMap(value);
    }
    if (value is YamlList) {
      return value.map(_unwrapYaml).toList();
    }
    return value;
  }
}
