import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:ensemble_test_runner/discovery/ensemble_test_discovery.dart';
import 'package:ensemble_test_runner/mocks/mock_composition.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:yaml/yaml.dart';

typedef _AssetStringLoader = Future<String> Function(String assetPath);

/// A parsed `*.test.yaml` file with its asset path.
class EnsembleTestDefinition {
  final String assetPath;
  final EnsembleTestCase testCase;

  const EnsembleTestDefinition({
    required this.assetPath,
    required this.testCase,
  });
}

/// Topologically sorted test run order (each test id appears once).
class EnsembleTestExecutionPlan {
  final List<EnsembleTestDefinition> ordered;
  final EnsembleTestConfig config;

  const EnsembleTestExecutionPlan({
    required this.ordered,
    this.config = const EnsembleTestConfig(),
  });
}

class EnsembleTestSelection {
  final Set<String> ids;
  final Set<String> features;
  final Set<String> tags;
  final Set<String> paths;

  const EnsembleTestSelection({
    this.ids = const {},
    this.features = const {},
    this.tags = const {},
    this.paths = const {},
  });

  bool get isEmpty =>
      ids.isEmpty && features.isEmpty && tags.isEmpty && paths.isEmpty;
}

/// Builds a dependency-ordered execution plan for all declarative tests.
class EnsembleTestExecutionPlanner {
  /// Discovers assets, parses every file, validates graph, returns run order.
  static Future<EnsembleTestExecutionPlan> build({
    EnsembleTestAppTarget? target,
    EnsembleTestSelection selection = const EnsembleTestSelection(),
    Map<String, dynamic> inputs = const {},
  }) async {
    final resolvedTarget =
        target ?? await EnsembleTestDiscovery.loadAppTarget();
    final paths = await EnsembleTestDiscovery.findTestYamlAssets(
      resolvedTarget.testsAssetPrefix,
    );
    final config = await EnsembleTestDiscovery.loadTestConfig(
      resolvedTarget.testsAssetPrefix,
    );
    if (paths.isEmpty) {
      throw EnsembleTestFailure(
        'No declarative tests found. Add *.test.yaml files under '
        '${resolvedTarget.testsAssetPrefix}',
      );
    }

    final byId = <String, EnsembleTestDefinition>{};
    for (final path in paths) {
      final content = await rootBundle.loadString(path);
      final definitions = await _parseDefinitionsFromAsset(
        path,
        content,
        inputs: inputs,
        services: config.services,
        suiteMockFiles: config.mockFiles,
        suiteInlineMocks: config.inlineMocks,
        suiteInitialState: config.initialState,
        suiteDevices: config.devices,
      );
      for (final definition in definitions) {
        final existing = byId[definition.testCase.id];
        if (existing != null) {
          throw EnsembleTestFailure(
            'Duplicate test id "${definition.testCase.id}" in '
            '${existing.assetPath} and $path',
          );
        }
        byId[definition.testCase.id] = definition;
      }
    }

    final selectedById = _applySelection(byId, selection);

    for (final def in selectedById.values) {
      final session = def.testCase.session;
      if (session != null && !selectedById.containsKey(session)) {
        throw EnsembleTestFailure(
          'Test "${def.testCase.id}" in ${def.assetPath} references unknown '
          'session "$session"',
        );
      }
    }

    final ordered = _topologicalSort(selectedById);
    return EnsembleTestExecutionPlan(ordered: ordered, config: config);
  }

  /// Exposed for unit tests only.
  @visibleForTesting
  static Future<List<EnsembleTestDefinition>> parseDefinitionsForTest(
    String path,
    String content, {
    Map<String, dynamic> inputs = const {},
    List<TestServiceConfig> services = const [],
    List<String> suiteMockFiles = const [],
    Map<String, dynamic> suiteInlineMocks = const {},
    Map<String, dynamic> suiteInitialState = const {},
    List<TestDeviceTarget> suiteDevices = const [],
    Future<String> Function(String assetPath)? assetLoader,
  }) {
    return _parseDefinitionsFromAsset(
      path,
      content,
      inputs: inputs,
      services: services,
      suiteMockFiles: suiteMockFiles,
      suiteInlineMocks: suiteInlineMocks,
      suiteInitialState: suiteInitialState,
      suiteDevices: suiteDevices,
      assetLoader: assetLoader ?? _rootBundleAssetLoader,
    );
  }

  static Future<List<EnsembleTestDefinition>> _parseDefinitionsFromAsset(
    String path,
    String content, {
    required Map<String, dynamic> inputs,
    List<TestServiceConfig> services = const [],
    List<String> suiteMockFiles = const [],
    Map<String, dynamic> suiteInlineMocks = const {},
    Map<String, dynamic> suiteInitialState = const {},
    List<TestDeviceTarget> suiteDevices = const [],
    _AssetStringLoader assetLoader = _rootBundleAssetLoader,
  }) async {
    final resolvedContent = _resolveServicePlaceholders(content, services);
    if (loadYaml(resolvedContent) == null) {
      return const [];
    }

    final base = EnsembleTestParser.parseString(
      resolvedContent,
      sourcePath: path,
      inputs: inputs,
    );
    final List<EnsembleTestDefinition> definitions;
    if (base.scenarios.isEmpty) {
      final mocks = await _mergedMocksFor(
        assetPath: path,
        suiteMockFiles: suiteMockFiles,
        suiteInlineMocks: suiteInlineMocks,
        mockFiles: base.mockFiles,
        inlineMocks: base.inlineMocks,
        assetLoader: assetLoader,
      );
      final steps = await _resolveStepMocks(
        assetPath: path,
        steps: base.steps,
        assetLoader: assetLoader,
      );
      definitions = [
        EnsembleTestDefinition(
          assetPath: path,
          testCase: _withRuntimeFields(
            base,
            id: base.id,
            startScreen: base.startScreen,
            session: base.session,
            mocks: mocks,
            steps: steps,
            initialState: mergedInitialState(
              suiteInitialState,
              base.initialState,
            ),
          ),
        ),
      ];
    } else {
      definitions = <EnsembleTestDefinition>[];
      for (final scenario in base.scenarios) {
        final parsed = EnsembleTestParser.parseString(
          resolvedContent,
          sourcePath: path,
          inputs: inputs,
          scenario: scenario.vars,
          scenarioId: scenario.id,
        );
        final parsedScenario = parsed.scenarios.firstWhere(
          (item) => item.id == scenario.id,
          orElse: () => scenario,
        );
        final id = '${base.id}[${scenario.id}]';
        final mocks = await _mergedMocksFor(
          assetPath: path,
          suiteMockFiles: suiteMockFiles,
          suiteInlineMocks: suiteInlineMocks,
          mockFiles: parsed.mockFiles,
          inlineMocks: parsed.inlineMocks,
          assetLoader: assetLoader,
        );
        final steps = await _resolveStepMocks(
          assetPath: path,
          steps: parsed.steps,
          assetLoader: assetLoader,
        );

        definitions.add(
          EnsembleTestDefinition(
            assetPath: path,
            testCase: _withRuntimeFields(
              parsed,
              id: id,
              description: parsedScenario.description ?? parsed.description,
              startScreen: parsed.startScreen,
              session: parsed.session,
              mocks: mocks,
              steps: steps,
              initialState: mergedInitialState(
                suiteInitialState,
                parsed.initialState,
              ),
            ),
          ),
        );
      }
    }

    return expandDeviceMatrix(definitions, suiteDevices);
  }

  /// Expands each definition once per suite `devices` entry.
  @visibleForTesting
  static List<EnsembleTestDefinition> expandDeviceMatrix(
    List<EnsembleTestDefinition> definitions,
    List<TestDeviceTarget> devices,
  ) {
    if (devices.isEmpty) return definitions;

    final expanded = <EnsembleTestDefinition>[];
    for (final definition in definitions) {
      final test = definition.testCase;
      for (final device in devices) {
        final multi = devices.length > 1;
        expanded.add(
          EnsembleTestDefinition(
            assetPath: definition.assetPath,
            testCase: _withRuntimeFields(
              test,
              id: multi ? '${test.id}[${device.id}]' : test.id,
              startScreen: test.startScreen,
              session: !multi || test.session == null
                  ? test.session
                  : '${test.session}[${device.id}]',
              mocks: test.mocks,
              steps: test.steps,
              initialState: _withDeviceLocale(test.initialState, device),
              startScreenInputs: test.startScreenInputs,
              deviceTarget: device,
              screenshotSheetId: multi
                  ? test.resolvedScreenshotSheetId
                  : test.screenshotSheetId,
            ),
          ),
        );
      }
    }
    return expanded;
  }

  static Map<String, dynamic> _withDeviceLocale(
    Map<String, dynamic> initialState,
    TestDeviceTarget device,
  ) {
    final locale = device.locale?.trim();
    if (locale == null || locale.isEmpty) {
      return Map<String, dynamic>.from(initialState);
    }
    return mergedInitialState(
      initialState,
      {
        'env': {'APP_LOCALE': locale},
      },
    );
  }

  static String _resolveServicePlaceholders(
    String content,
    List<TestServiceConfig> services,
  ) {
    final urls = {
      for (final service in services)
        if (service.url != null && service.url!.isNotEmpty)
          service.name: service.url!,
    };
    final resolved = content.replaceAllMapped(
      RegExp(r'\$\{services\.([^.}]+)\.url\}'),
      (match) {
        final name = match.group(1)!;
        final url = urls[name];
        if (url == null) {
          throw EnsembleTestFailure(
            'Test references service "$name" without a configured url.',
          );
        }
        return url;
      },
    );
    final unsupported = RegExp(r'\$\{services\.([^}]+)\}').firstMatch(resolved);
    if (unsupported != null) {
      throw EnsembleTestFailure(
        'Unsupported service value "${unsupported.group(0)}". '
        'Use \${services.<name>.url}.',
      );
    }
    return resolved;
  }

  static EnsembleTestCase _withRuntimeFields(
    EnsembleTestCase test, {
    required String id,
    String? description,
    String? startScreen,
    String? session,
    required TestMocks mocks,
    required List<TestStep> steps,
    Map<String, dynamic>? initialState,
    Map<String, dynamic>? startScreenInputs,
    TestDeviceTarget? deviceTarget,
    String? screenshotSheetId,
  }) {
    return EnsembleTestCase(
      id: id,
      sourcePath: test.sourcePath,
      type: test.type,
      feature: test.feature,
      tags: test.tags,
      description: description ?? test.description,
      owner: test.owner,
      priority: test.priority,
      parallel: test.parallel,
      retry: test.retry,
      startScreen: startScreen,
      startScreenInputs: startScreenInputs ?? test.startScreenInputs,
      session: session,
      mockFiles: test.mockFiles,
      scenarios: test.scenarios,
      initialState: initialState ?? test.initialState,
      setupSteps: test.setupSteps,
      mocks: mocks,
      steps: steps,
      deviceTarget: deviceTarget ?? test.deviceTarget,
      screenshotSheetId: screenshotSheetId ?? test.screenshotSheetId,
    );
  }

  /// Suite [initialState] is the base; test values override per key within
  /// `storage`, `keychain`, and `env`.
  @visibleForTesting
  static Map<String, dynamic> mergedInitialState(
    Map<String, dynamic> suite,
    Map<String, dynamic> test,
  ) {
    if (suite.isEmpty) return test;
    if (test.isEmpty) return Map<String, dynamic>.from(suite);

    Map<String, dynamic> section(String key) {
      final suiteSection = _asStringKeyedMap(suite[key]);
      final testSection = _asStringKeyedMap(test[key]);
      if (suiteSection.isEmpty && testSection.isEmpty) {
        return const <String, dynamic>{};
      }
      return <String, dynamic>{...suiteSection, ...testSection};
    }

    final merged = <String, dynamic>{};
    for (final key in const ['storage', 'keychain', 'env']) {
      final value = section(key);
      if (value.isNotEmpty) {
        merged[key] = value;
      }
    }
    return merged;
  }

  static Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is! Map) return const <String, dynamic>{};
    return <String, dynamic>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  static Future<List<TestStep>> _resolveStepMocks({
    required String assetPath,
    required List<TestStep> steps,
    required _AssetStringLoader assetLoader,
  }) async {
    final resolved = <TestStep>[];
    for (final step in steps) {
      final mocks = await _mocksForStep(
        assetPath: assetPath,
        step: step,
        assetLoader: assetLoader,
      );
      final nestedSteps = await _resolveStepMocks(
        assetPath: assetPath,
        steps: step.nestedSteps,
        assetLoader: assetLoader,
      );
      resolved.add(
        TestStep(
          type: step.type,
          args: step.args,
          mocks: mocks,
          nestedSteps: nestedSteps,
        ),
      );
    }
    return resolved;
  }

  static Future<TestMocks> _mocksForStep({
    required String assetPath,
    required TestStep step,
    required _AssetStringLoader assetLoader,
  }) async {
    if (step.type != 'mocks') return const TestMocks();
    final node = step.args.length == 1 && step.args.containsKey('value')
        ? step.args['value']
        : step.args;
    final parsed = EnsembleTestParser.parseMocksNode(
      node,
      testId: assetPath,
      inputs: const {},
      scenario: const {},
    );
    return _mergedMocksFor(
      assetPath: assetPath,
      mockFiles: parsed.files,
      inlineMocks: parsed.inline,
      assetLoader: assetLoader,
    );
  }

  static Future<TestMocks> _mergedMocksFor({
    required String assetPath,
    List<String> suiteMockFiles = const [],
    Map<String, dynamic> suiteInlineMocks = const {},
    required List<String> mockFiles,
    required Map<String, dynamic> inlineMocks,
    required _AssetStringLoader assetLoader,
  }) async {
    final raw = <String, Map<String, dynamic>>{};
    for (final file in suiteMockFiles) {
      await _mergeMockFile(
        into: raw,
        fromAssetPath: assetPath,
        mockFilePath: file,
        assetLoader: assetLoader,
      );
    }
    await _mergeInlineMocks(
      into: raw,
      inlineMocks: suiteInlineMocks,
      sourceLabel: 'tests/config.yaml',
      fromAssetPath: assetPath,
      assetLoader: assetLoader,
    );
    for (final file in mockFiles) {
      await _mergeMockFile(
        into: raw,
        fromAssetPath: assetPath,
        mockFilePath: file,
        assetLoader: assetLoader,
      );
    }
    await _mergeInlineMocks(
      into: raw,
      inlineMocks: inlineMocks,
      sourceLabel: assetPath,
      fromAssetPath: assetPath,
      assetLoader: assetLoader,
    );
    return TestMocks(
      apis: MockComposition.toMockApis(raw, sourceLabel: assetPath),
    );
  }

  static Future<void> _mergeMockFile({
    required Map<String, Map<String, dynamic>> into,
    required String fromAssetPath,
    required String mockFilePath,
    required _AssetStringLoader assetLoader,
  }) async {
    try {
      final resolved = await MockComposition.resolveFile(
        testAssetPath: fromAssetPath,
        mockFilePath: mockFilePath,
        assetLoader: assetLoader,
        resolveAssetPath: _resolveAssetPath,
      );
      MockComposition.mergeApiMaps(
        into,
        resolved,
        sourceLabel: _resolveAssetPath(fromAssetPath, mockFilePath),
      );
    } on FlutterError {
      throw EnsembleTestFailure(
        'Mock file "$mockFilePath" referenced by $fromAssetPath was not found.',
      );
    }
  }

  static Future<void> _mergeInlineMocks({
    required Map<String, Map<String, dynamic>> into,
    required Map<String, dynamic> inlineMocks,
    required String sourceLabel,
    required String fromAssetPath,
    required _AssetStringLoader assetLoader,
  }) async {
    if (inlineMocks.isEmpty) return;

    // `$extends` must be resolved in isolation first, then layered onto [into].
    // `$merge` without `$extends` patches APIs already present in [into]
    // (suite/test/file layers loaded earlier in this merge).
    if (inlineMocks.containsKey(MockComposition.extendsKey)) {
      final resolved = await MockComposition.resolveDocument(
        Map<dynamic, dynamic>.from(inlineMocks),
        sourceLabel: sourceLabel,
        testAssetPath: fromAssetPath,
        assetLoader: assetLoader,
        resolveAssetPath: _resolveAssetPath,
      );
      MockComposition.mergeApiMaps(
        into,
        resolved,
        sourceLabel: sourceLabel,
      );
      return;
    }

    final incoming = <String, Map<String, dynamic>>{};
    for (final entry in inlineMocks.entries) {
      if (entry.value is! Map) {
        throw EnsembleTestFailure(
          'Mock for API "${entry.key}" in "$sourceLabel" must be a map',
        );
      }
      incoming[entry.key.toString()] = MockComposition.deepCopy(entry.value)
          as Map<String, dynamic>;
    }
    MockComposition.mergeApiMaps(
      into,
      incoming,
      sourceLabel: sourceLabel,
    );
  }

  static Future<String> _rootBundleAssetLoader(String assetPath) {
    return rootBundle.loadString(assetPath);
  }

  static String _resolveAssetPath(String fromAssetPath, String relativePath) {
    if (relativePath.startsWith('/')) return relativePath.substring(1);
    final segments = fromAssetPath.split('/')..removeLast();
    for (final part in relativePath.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else {
        segments.add(part);
      }
    }
    return segments.join('/');
  }

  static Map<String, EnsembleTestDefinition> _applySelection(
    Map<String, EnsembleTestDefinition> byId,
    EnsembleTestSelection selection,
  ) {
    if (selection.isEmpty) return byId;

    final selectedIds = byId.entries
        .where((entry) => _matchesSelection(entry.value, selection))
        .map((entry) => entry.key)
        .toSet();
    if (selectedIds.isEmpty) {
      throw EnsembleTestFailure(
          'No tests matched the provided selection flags');
    }

    void includeDependencies(String id) {
      final test = byId[id]?.testCase;
      final dependencies = <String>[
        if (test?.session != null) test!.session!,
      ];
      for (final dependency in dependencies) {
        if (!byId.containsKey(dependency)) {
          throw EnsembleTestFailure(
            'Selected test "$id" references unknown dependency "$dependency"',
          );
        }
        if (selectedIds.add(dependency)) includeDependencies(dependency);
      }
    }

    for (final id in selectedIds.toList()) {
      includeDependencies(id);
    }

    return {
      for (final id in byId.keys)
        if (selectedIds.contains(id)) id: byId[id]!,
    };
  }

  static bool _matchesSelection(
    EnsembleTestDefinition def,
    EnsembleTestSelection selection,
  ) {
    final test = def.testCase;
    final idMatches = selection.ids.isNotEmpty &&
        selection.ids.any(
          (id) => test.id == id || test.id.startsWith('$id['),
        );
    final featureMatches = selection.features.isNotEmpty &&
        selection.features.contains(test.feature);
    final tagMatches = selection.tags.isNotEmpty &&
        test.tags.any((tag) => selection.tags.contains(tag));
    final pathMatches = selection.paths.isNotEmpty &&
        selection.paths.any((path) => def.assetPath.contains(path));
    return idMatches || featureMatches || tagMatches || pathMatches;
  }

  /// Kahn's algorithm: edge from test → its session producer.
  static List<EnsembleTestDefinition> _topologicalSort(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    final inDegree = <String, int>{};
    final dependents = <String, List<String>>{};

    for (final id in byId.keys) {
      inDegree[id] = 0;
      dependents[id] = [];
    }

    for (final entry in byId.entries) {
      final test = entry.value.testCase;
      final dependencies = <String>[
        if (test.session != null) test.session!,
      ];
      for (final dependency in dependencies) {
        inDegree[entry.key] = (inDegree[entry.key] ?? 0) + 1;
        dependents[dependency]!.add(entry.key);
      }
    }

    final ready = <String>[];
    for (final id in byId.keys) {
      if (inDegree[id] == 0) ready.add(id);
    }
    ready.sort((a, b) => byId[a]!.assetPath.compareTo(byId[b]!.assetPath));

    final orderedIds = <String>[];
    while (ready.isNotEmpty) {
      ready.sort((a, b) => byId[a]!.assetPath.compareTo(byId[b]!.assetPath));
      final id = ready.removeAt(0);
      orderedIds.add(id);
      for (final dependent in dependents[id]!) {
        inDegree[dependent] = inDegree[dependent]! - 1;
        if (inDegree[dependent] == 0) {
          ready.add(dependent);
        }
      }
    }

    if (orderedIds.length != byId.length) {
      throw EnsembleTestFailure(
        'Circular test dependency among tests: '
        '${byId.keys.where((id) => !orderedIds.contains(id)).join(", ")}',
      );
    }

    return orderedIds.map((id) => byId[id]!).toList();
  }

  /// Exposed for unit tests only.
  @visibleForTesting
  static List<String> orderIdsForTest(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    return _topologicalSort(byId).map((d) => d.testCase.id).toList();
  }

  @visibleForTesting
  static List<String> selectAndOrderIdsForTest(
    Map<String, EnsembleTestDefinition> byId,
    EnsembleTestSelection selection,
  ) {
    return _topologicalSort(_applySelection(byId, selection))
        .map((d) => d.testCase.id)
        .toList();
  }
}
