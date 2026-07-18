import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:ensemble_test_runner/discovery/ensemble_test_discovery.dart';
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
      final prereq = def.testCase.prerequisite;
      if (prereq != null && !selectedById.containsKey(prereq)) {
        throw EnsembleTestFailure(
          'Test "${def.testCase.id}" in ${def.assetPath} references unknown '
          'prerequisite "$prereq"',
        );
      }
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
    Future<String> Function(String assetPath)? assetLoader,
  }) {
    return _parseDefinitionsFromAsset(
      path,
      content,
      inputs: inputs,
      services: services,
      assetLoader: assetLoader ?? _rootBundleAssetLoader,
    );
  }

  static Future<List<EnsembleTestDefinition>> _parseDefinitionsFromAsset(
    String path,
    String content, {
    required Map<String, dynamic> inputs,
    List<TestServiceConfig> services = const [],
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
    if (base.scenarios.isEmpty) {
      final mocks = await _mergedMocksFor(
        assetPath: path,
        mockFiles: base.mockFiles,
        inlineMocks: base.inlineMocks,
        assetLoader: assetLoader,
      );
      return [
        EnsembleTestDefinition(
          assetPath: path,
          testCase: _withRuntimeFields(
            base,
            id: base.id,
            startScreen: base.startScreen,
            prerequisite: base.prerequisite,
            session: base.session,
            mocks: mocks,
          ),
        ),
      ];
    }

    final definitions = <EnsembleTestDefinition>[];
    String? previousScenarioId;
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
      final prerequisite = parsed.prerequisite == null
          ? null
          : previousScenarioId ?? parsed.prerequisite;
      final mocks = await _mergedMocksFor(
        assetPath: path,
        mockFiles: parsed.mockFiles,
        inlineMocks: parsed.inlineMocks,
        assetLoader: assetLoader,
      );

      definitions.add(
        EnsembleTestDefinition(
          assetPath: path,
          testCase: _withRuntimeFields(
            parsed,
            id: id,
            description: parsedScenario.description ?? parsed.description,
            startScreen:
                parsed.prerequisite == null ? parsed.startScreen : null,
            prerequisite: prerequisite,
            session: parsed.session,
            mocks: mocks,
          ),
        ),
      );
      previousScenarioId = id;
    }
    return definitions;
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
    String? prerequisite,
    String? session,
    required TestMocks mocks,
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
      startScreenInputs: test.startScreenInputs,
      prerequisite: prerequisite,
      session: session,
      mockFiles: test.mockFiles,
      scenarios: test.scenarios,
      initialState: test.initialState,
      setupSteps: test.setupSteps,
      mocks: mocks,
      steps: test.steps,
    );
  }

  static Future<TestMocks> _mergedMocksFor({
    required String assetPath,
    required List<String> mockFiles,
    required Map<String, dynamic> inlineMocks,
    required _AssetStringLoader assetLoader,
  }) async {
    final apis = <String, MockAPIResponse>{};
    for (final file in mockFiles) {
      final fileMocks = await _loadMockFile(
        assetPath,
        file,
        assetLoader: assetLoader,
      );
      apis.addAll(fileMocks.apis);
    }
    apis.addAll(
      _parseMockApisMap(
        inlineMocks,
        sourceLabel: assetPath,
      ).apis,
    );
    return TestMocks(apis: apis);
  }

  static Future<TestMocks> _loadMockFile(
    String testAssetPath,
    String mockFilePath, {
    required _AssetStringLoader assetLoader,
  }) async {
    final assetPath = _resolveAssetPath(testAssetPath, mockFilePath);
    final content = await _loadRequiredAsset(
      assetPath,
      'Mock file "$mockFilePath" referenced by $testAssetPath was not found.',
      assetLoader: assetLoader,
    );
    if (!assetPath.endsWith('.mock.json')) {
      throw EnsembleTestFailure(
        'Mock file "$mockFilePath" must be a .mock.json file.',
      );
    }

    final dynamic doc = _parseMockFileDocument(content, assetPath);
    if (doc == null) return const TestMocks();
    if (doc is! Map) {
      throw EnsembleTestFailure('Mock file "$assetPath" root must be a map');
    }

    return _parseMockApisMap(
      Map<dynamic, dynamic>.from(doc),
      sourceLabel: assetPath,
    );
  }

  static TestMocks _parseMockApisMap(
    Map<dynamic, dynamic> doc, {
    required String sourceLabel,
  }) {
    final apis = <String, MockAPIResponse>{};
    for (final entry in doc.entries) {
      if (entry.value is! Map) {
        throw EnsembleTestFailure(
          'Mock for API "${entry.key}" in "$sourceLabel" must be a map',
        );
      }
      apis[entry.key.toString()] = _parseLayerMockApiResponse(
        Map<dynamic, dynamic>.from(entry.value as Map),
        layerAssetPath: sourceLabel,
        apiName: entry.key.toString(),
      );
    }
    return TestMocks(apis: apis);
  }

  static dynamic _parseMockFileDocument(String content, String assetPath) {
    try {
      return jsonDecode(content);
    } on FormatException catch (error) {
      throw EnsembleTestFailure(
        'Mock file "$assetPath" is not valid JSON: ${error.message}',
      );
    }
  }

  static MockAPIResponse _parseLayerMockApiResponse(
    Map<dynamic, dynamic> map, {
    required String layerAssetPath,
    required String apiName,
  }) {
    if (map.isEmpty) {
      throw EnsembleTestFailure(
        'API mock "$apiName" in "$layerAssetPath" must include a response',
      );
    }
    final unknownKeys = map.keys
        .map((key) => key.toString())
        .where(
          (key) => !const {
            'statusCode',
            'body',
            'headers',
            'delayMs',
            'responses',
          }.contains(key),
        )
        .toList();
    if (unknownKeys.isNotEmpty) {
      throw EnsembleTestFailure(
        'API mock "$apiName" in "$layerAssetPath" has unsupported keys: '
        '${unknownKeys.join(", ")}. Use direct JSON shape: '
        '{"statusCode": 200, "body": ...}.',
      );
    }

    final responses = map['responses'];
    if (responses != null) {
      if (responses is! List || responses.isEmpty) {
        throw EnsembleTestFailure(
          'API mock "$apiName" in "$layerAssetPath" responses must be a non-empty list',
        );
      }
      return MockAPIResponse(
        responses: [
          for (final entry in responses)
            if (entry is Map)
              _parseLayerMockApiResponse(
                Map<dynamic, dynamic>.from(entry),
                layerAssetPath: layerAssetPath,
                apiName: apiName,
              )
            else
              throw EnsembleTestFailure(
                'API mock "$apiName" in "$layerAssetPath" responses entries must be objects',
              ),
        ],
      );
    }

    return MockAPIResponse(
      statusCode: map['statusCode'] as int? ?? 200,
      body: map.containsKey('body') ? _unwrapJsonValue(map['body']) : null,
      headers: map['headers'] is Map
          ? Map<String, dynamic>.from(
              _unwrapJsonValue(map['headers']) as Map,
            )
          : null,
      delayMs: map['delayMs'] as int?,
    );
  }

  static dynamic _unwrapJsonValue(dynamic value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _unwrapJsonValue(entry.value),
      };
    }
    if (value is List) {
      return value.map(_unwrapJsonValue).toList();
    }
    return value;
  }

  static Future<String> _loadRequiredAsset(
    String assetPath,
    String missingMessage, {
    required _AssetStringLoader assetLoader,
  }) async {
    try {
      return await assetLoader(assetPath);
    } on FlutterError {
      throw EnsembleTestFailure(missingMessage);
    }
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
        if (test?.prerequisite != null) test!.prerequisite!,
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

  /// IDs that participate in a shared session (`prerequisite` chain).
  static Set<String> _sessionConnectedIds(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    final connected = <String>{};
    for (final def in byId.values) {
      final prereq = def.testCase.prerequisite;
      if (prereq == null) continue;
      connected.add(def.testCase.id);
      connected.add(prereq);
    }
    var expanded = true;
    while (expanded) {
      expanded = false;
      for (final def in byId.values) {
        final prereq = def.testCase.prerequisite;
        if (prereq != null &&
            connected.contains(prereq) &&
            connected.add(def.testCase.id)) {
          expanded = true;
        }
      }
    }
    return connected;
  }

  /// Kahn's algorithm: edge from test → its prerequisite (prereq runs first).
  ///
  /// Tests with [EnsembleTestCase.hasStartScreen] that are not in a prerequisite
  /// chain run **after** the chain so [EnsembleTestHarness.loadScreen] does not
  /// reset the session for continuation tests.
  static List<EnsembleTestDefinition> _topologicalSort(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    final sessionConnected = _sessionConnectedIds(byId);
    final inDegree = <String, int>{};
    final dependents = <String, List<String>>{};

    for (final id in byId.keys) {
      inDegree[id] = 0;
      dependents[id] = [];
    }

    for (final entry in byId.entries) {
      final test = entry.value.testCase;
      final dependencies = <String>[
        if (test.prerequisite != null) test.prerequisite!,
        if (test.session != null) test.session!,
      ];
      for (final dependency in dependencies) {
        inDegree[entry.key] = (inDegree[entry.key] ?? 0) + 1;
        dependents[dependency]!.add(entry.key);
      }
    }

    bool sessionChainComplete(List<String> ordered) {
      if (sessionConnected.isEmpty) return true;
      return sessionConnected.every(ordered.contains);
    }

    bool canSchedule(String id, List<String> ordered) {
      if (inDegree[id] != 0) return false;
      if (sessionConnected.contains(id)) return true;
      return sessionChainComplete(ordered);
    }

    final ready = <String>[];
    for (final id in byId.keys) {
      if (canSchedule(id, const [])) ready.add(id);
    }
    ready.sort((a, b) => byId[a]!.assetPath.compareTo(byId[b]!.assetPath));

    final orderedIds = <String>[];
    while (ready.isNotEmpty) {
      ready.sort((a, b) => byId[a]!.assetPath.compareTo(byId[b]!.assetPath));
      final id = ready.removeAt(0);
      orderedIds.add(id);
      for (final dependent in dependents[id]!) {
        inDegree[dependent] = inDegree[dependent]! - 1;
        if (inDegree[dependent] == 0 && canSchedule(dependent, orderedIds)) {
          ready.add(dependent);
        }
      }
      for (final candidate in byId.keys) {
        if (!orderedIds.contains(candidate) &&
            !ready.contains(candidate) &&
            canSchedule(candidate, orderedIds)) {
          ready.add(candidate);
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
