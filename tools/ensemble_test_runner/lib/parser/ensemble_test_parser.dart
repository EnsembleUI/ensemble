import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:yaml/yaml.dart';

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

  static EnsembleTestCase parseString(
    String content, {
    String? sourcePath,
    Map<String, dynamic> inputs = const {},
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
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

    return _parseTestCase(
      doc,
      sourcePath: sourcePath,
      inputs: inputs,
      scenario: scenario,
      scenarioId: scenarioId,
    );
  }

  static EnsembleTestCase _parseTestCase(
    YamlMap map, {
    String? sourcePath,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
  }) {
    final unsupportedKeys = _unsupportedTestRootKeys(map);
    if (unsupportedKeys.isNotEmpty) {
      throw EnsembleTestFailure(
        'Unsupported root key${unsupportedKeys.length == 1 ? '' : 's'} '
        '${unsupportedKeys.map((key) => '"$key"').join(', ')} in *.test.yaml file.',
      );
    }
    if (_hasYamlKey(map, 'mocks') &&
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

    if (!hasStartScreen) {
      throw EnsembleTestFailure(
        'Test "$id" must have "startScreen"',
      );
    }

    final setupNode = map['setup'];
    final setupSteps = setupNode == null
        ? const <TestStep>[]
        : _parseSetupSteps(
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

    return EnsembleTestCase(
      id: id,
      sourcePath: sourcePath,
      type: map['type']?.toString(),
      feature: map['feature']?.toString(),
      tags: _toStringList(map['tags']),
      description: map['description']?.toString(),
      owner: map['owner']?.toString(),
      priority: map['priority']?.toString(),
      parallel: map['parallel'] == false ? false : true,
      retry: _optionalNonNegativeInt(
        map['retry'],
        fallback: 0,
        fieldName: '$id.retry',
      ),
      startScreen: hasStartScreen ? startScreen : null,
      startScreenInputs: _toStringDynamicMap(
        map['startScreenInputs'],
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      ),
      session: hasSession ? session : null,
      mockFiles: parsedMocks.files,
      inlineMocks: parsedMocks.inline,
      scenarios: _parseScenarios(map['scenarios'], inputs: inputs),
      initialState: _toStringDynamicMap(
        map['initialState'],
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      ),
      setupSteps: setupSteps,
      steps: _parseSteps(
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
        inline: _toStringDynamicMap(
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
      final value = _unwrapYaml(
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
    const allowedKeys = {
      'services',
      'screenshots',
      'performance',
      'timers',
      'dumpTree',
      'logApiCalls',
      'logStorage',
    };
    for (final key in node.keys) {
      if (!allowedKeys.contains(key)) {
        throw EnsembleTestFailure(
          'Unsupported test config key "$key". Supported keys: '
          '${allowedKeys.join(', ')}',
        );
      }
    }

    final servicesNode = node['services'];
    final screenshotsNode = node['screenshots'];
    final performanceNode = node['performance'];
    final timersNode = node['timers'];
    final dumpTreeNode = node['dumpTree'];
    final logApiCallsNode = node['logApiCalls'];
    final logStorageNode = node['logStorage'];
    if (servicesNode != null && servicesNode is! YamlList) {
      throw EnsembleTestFailure('"services" must be a list');
    }
    if (screenshotsNode != null && screenshotsNode is! YamlMap) {
      throw EnsembleTestFailure('"screenshots" must be a map');
    }
    if (performanceNode != null && performanceNode is! YamlMap) {
      throw EnsembleTestFailure('"performance" must be a map');
    }
    if (timersNode != null && timersNode is! YamlMap) {
      throw EnsembleTestFailure('"timers" must be a map');
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
      services: _parseServices(servicesNode),
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
      timers: timersNode == null
          ? const TimerRewriteConfig()
          : TimerRewriteConfig(
              enabled: timersNode['enabled'] == true,
              maxStartAfterSeconds: _optionalNonNegativeInt(
                timersNode['maxStartAfterSeconds'],
                fallback: 1,
                fieldName: 'timers.maxStartAfterSeconds',
              ),
              maxRepeatIntervalSeconds: _optionalNonNegativeInt(
                timersNode['maxRepeatIntervalSeconds'],
                fallback: 1,
                fieldName: 'timers.maxRepeatIntervalSeconds',
              ),
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

  static int _optionalNonNegativeInt(
    dynamic value, {
    required int fallback,
    required String fieldName,
  }) {
    if (value == null) return fallback;
    final parsed = value is int ? value : int.tryParse(value.toString());
    if (parsed == null || parsed < 0) {
      throw EnsembleTestFailure('"$fieldName" must be a non-negative integer');
    }
    return parsed;
  }

  static List<TestServiceConfig> _parseServices(dynamic node) {
    if (node == null) return const [];
    final services = <TestServiceConfig>[];
    final names = <String>{};
    for (final item in node as YamlList) {
      if (item is! YamlMap) {
        throw EnsembleTestFailure('Each service must be a map');
      }
      const allowedKeys = {
        'name',
        'command',
        'url',
        'arguments',
        'workingDirectory',
        'environment',
        'readyUrl',
        'readyTimeoutMs',
      };
      for (final key in item.keys) {
        if (!allowedKeys.contains(key)) {
          throw EnsembleTestFailure(
            'Unsupported service key "$key". Supported keys: '
            '${allowedKeys.join(', ')}',
          );
        }
      }

      final name = item['name']?.toString();
      final command = item['command']?.toString();
      if (name == null || name.isEmpty) {
        throw EnsembleTestFailure('Each service requires "name"');
      }
      if (!names.add(name)) {
        throw EnsembleTestFailure('Duplicate service name "$name"');
      }
      if (command == null || command.isEmpty) {
        throw EnsembleTestFailure('Service "$name" requires "command"');
      }

      final argumentsNode = item['arguments'];
      if (argumentsNode != null && argumentsNode is! YamlList) {
        throw EnsembleTestFailure(
          'Service "$name" "arguments" must be a list',
        );
      }
      final environmentNode = item['environment'];
      if (environmentNode != null && environmentNode is! YamlMap) {
        throw EnsembleTestFailure(
          'Service "$name" "environment" must be a map',
        );
      }
      final timeout = item['readyTimeoutMs'];
      if (timeout != null && (timeout is! int || timeout <= 0)) {
        throw EnsembleTestFailure(
          'Service "$name" "readyTimeoutMs" must be a positive integer',
        );
      }

      services.add(
        TestServiceConfig(
          name: name,
          command: command,
          url: item['url']?.toString(),
          arguments: argumentsNode == null
              ? const []
              : argumentsNode.map<String>((value) => value.toString()).toList(),
          workingDirectory: item['workingDirectory']?.toString(),
          environment: environmentNode == null
              ? const {}
              : {
                  for (final entry in environmentNode.entries)
                    entry.key.toString(): entry.value.toString(),
                },
          readyUrl: item['readyUrl']?.toString(),
          readyTimeoutMs: timeout as int? ?? 10000,
        ),
      );
    }
    return services;
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
      final vars = _toStringDynamicMap(
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

  static List<TestStep> _parseSteps(
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

  static List<TestStep> _parseSetupSteps(
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
      return _toStringDynamicMap(
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
          _unwrapYaml(
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
        'value': _unwrapYaml(
          node,
          inputs: inputs,
          scenario: scenario,
          scenarioId: scenarioId,
        ),
      };
    }
    return {};
  }

  static Map<String, dynamic> _toStringDynamicMap(
    dynamic node, {
    required Map<String, dynamic> inputs,
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
    if (node == null) return {};
    if (node is! YamlMap) {
      throw EnsembleTestFailure('Expected a map');
    }
    final out = <String, dynamic>{};
    node.forEach((key, value) {
      out[key.toString()] = _unwrapYaml(
        value,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    });
    return out;
  }

  static List<String> _toStringList(
    dynamic node, {
    Map<String, dynamic> inputs = const {},
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
    if (node == null) return const [];
    if (node is! Iterable) {
      throw EnsembleTestFailure('Expected a list');
    }
    return node
        .map(
          (value) => _unwrapYaml(
            value,
            inputs: inputs,
            scenario: scenario,
            scenarioId: scenarioId,
          ).toString(),
        )
        .toList();
  }

  static dynamic _unwrapYaml(
    dynamic value, {
    required Map<String, dynamic> inputs,
    Map<String, dynamic> scenario = const {},
    String? scenarioId,
  }) {
    if (value is YamlMap) {
      return _toStringDynamicMap(
        value,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    }
    if (value is YamlList) {
      return value
          .map(
            (item) => _unwrapYaml(
              item,
              inputs: inputs,
              scenario: scenario,
              scenarioId: scenarioId,
            ),
          )
          .toList();
    }
    if (value is String) {
      return _resolvePlaceholders(
        value,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    }
    return value;
  }

  static dynamic _resolvePlaceholders(
    String value, {
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> scenario,
    String? scenarioId,
  }) {
    final exact = RegExp(r'^\$\{(inputs|scenario)\.([A-Za-z0-9_.-]+)\}$')
        .firstMatch(value);
    if (exact != null) {
      return _placeholderValue(
        exact.group(1)!,
        exact.group(2)!,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      );
    }

    return value.replaceAllMapped(
      RegExp(r'\$\{(inputs|scenario)\.([A-Za-z0-9_.-]+)\}'),
      (match) => _placeholderValue(
        match.group(1)!,
        match.group(2)!,
        inputs: inputs,
        scenario: scenario,
        scenarioId: scenarioId,
      ).toString(),
    );
  }

  static dynamic _placeholderValue(
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

  static bool _hasYamlKey(YamlMap map, String key) {
    return map.keys.any((candidate) => candidate.toString() == key);
  }

  static List<String> _unsupportedTestRootKeys(YamlMap map) {
    const supported = {
      'id',
      'type',
      'feature',
      'tags',
      'description',
      'owner',
      'priority',
      'parallel',
      'retry',
      'startScreen',
      'startScreenInputs',
      'session',
      'initialState',
      'setup',
      'mocks',
      'scenarios',
      'steps',
    };
    return map.keys
        .map((key) => key.toString())
        .where((key) => !supported.contains(key))
        .toList();
  }
}
