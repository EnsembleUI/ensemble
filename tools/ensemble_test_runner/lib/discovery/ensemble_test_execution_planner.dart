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

/// Filters applied while building an execution plan.
class EnsembleTestSelection {
  final Set<String> ids;
  final Set<String> exactIds;
  final Set<String> features;
  final Set<String> profiles;
  final Set<String> tags;
  final Set<String> paths;

  const EnsembleTestSelection({
    this.ids = const {},
    this.exactIds = const {},
    this.features = const {},
    this.profiles = const {},
    this.tags = const {},
    this.paths = const {},
  });

  bool get isEmpty =>
      ids.isEmpty &&
      exactIds.isEmpty &&
      features.isEmpty &&
      profiles.isEmpty &&
      tags.isEmpty &&
      paths.isEmpty;
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
    final assetContents = <String, String>{};
    for (final path in paths) {
      assetContents[path] = await rootBundle.loadString(path);
    }
    return _buildFromResolvedAssets(
      assetContents: assetContents,
      config: config,
      selection: selection,
      inputs: inputs,
    );
  }

  @visibleForTesting
  static Future<EnsembleTestExecutionPlan> buildForTest({
    required Map<String, String> assetContents,
    EnsembleTestConfig config = const EnsembleTestConfig(),
    EnsembleTestSelection selection = const EnsembleTestSelection(),
    Map<String, dynamic> inputs = const {},
    Future<String> Function(String assetPath)? assetLoader,
  }) {
    return _buildFromResolvedAssets(
      assetContents: assetContents,
      config: config,
      selection: selection,
      inputs: inputs,
      assetLoader: assetLoader ?? _rootBundleAssetLoader,
    );
  }

  static Future<EnsembleTestExecutionPlan> _buildFromResolvedAssets({
    required Map<String, String> assetContents,
    required EnsembleTestConfig config,
    required EnsembleTestSelection selection,
    required Map<String, dynamic> inputs,
    _AssetStringLoader assetLoader = _rootBundleAssetLoader,
  }) async {
    final paths = assetContents.keys.toList()..sort();
    final selectionWithExpandedProfiles = _expandProfileGroupSelection(
      selection,
      config.profileGroups,
    );

    if (selectionWithExpandedProfiles.isEmpty) {
      final byId = <String, EnsembleTestDefinition>{};
      for (final path in paths) {
        final content = assetContents[path]!;
        final definitions = await _parseDefinitionsFromAsset(
          path,
          content,
          inputs: inputs,
          services: config.services,
          suiteDefaultProfile: config.defaultProfile,
          suiteMockFiles: config.mockFiles,
          suiteInlineMocks: config.inlineMocks,
          suiteInitialState: config.initialState,
          suiteProfiles: config.profiles,
          suiteProfileGroups: config.profileGroups,
          suiteDevices: config.devices,
          assetLoader: assetLoader,
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

      final ordered = _topologicalSort(byId);
      return EnsembleTestExecutionPlan(ordered: ordered, config: config);
    }

    final previewById = <String, EnsembleTestDefinition>{};
    for (final path in paths) {
      final content = assetContents[path]!;
      final definitions = _previewDefinitionsFromAsset(path, content);
      for (final definition in definitions) {
        final existing = previewById[definition.testCase.id];
        if (existing != null) {
          throw EnsembleTestFailure(
            'Duplicate test id "${definition.testCase.id}" in '
            '${existing.assetPath} and $path',
          );
        }
        previewById[definition.testCase.id] = definition;
      }
    }

    final previewSelection = EnsembleTestSelection(
      ids: selectionWithExpandedProfiles.ids,
      features: selectionWithExpandedProfiles.features,
      tags: selectionWithExpandedProfiles.tags,
      paths: selectionWithExpandedProfiles.paths,
    );
    final selectedPreviewById = previewSelection.isEmpty
        ? previewById
        : _applySelection(previewById, previewSelection);

    final selectedAssetPaths = selectedPreviewById.values
        .map((definition) => definition.assetPath)
        .toSet();
    final selectedIds = selectedPreviewById.keys.toSet();
    final parsedById = <String, EnsembleTestDefinition>{};
    final selectedById = <String, EnsembleTestDefinition>{};
    for (final path in selectedAssetPaths) {
      final content = assetContents[path]!;
      final definitions = await _parseDefinitionsFromAsset(
        path,
        content,
        inputs: inputs,
        services: config.services,
        suiteDefaultProfile: config.defaultProfile,
        suiteMockFiles: config.mockFiles,
        suiteInlineMocks: config.inlineMocks,
        suiteInitialState: config.initialState,
        suiteProfiles: config.profiles,
        suiteProfileGroups: config.profileGroups,
        suiteDevices: config.devices,
        assetLoader: assetLoader,
      );
      for (final definition in definitions) {
        if (selectionWithExpandedProfiles.exactIds.isEmpty &&
            !_idBelongsToSelection(definition.testCase.id, selectedIds)) {
          continue;
        }
        if (!_matchesProfileSelection(
          definition.testCase,
          selectionWithExpandedProfiles,
        )) {
          continue;
        }
        final existing = parsedById[definition.testCase.id];
        if (existing != null) {
          throw EnsembleTestFailure(
            'Duplicate test id "${definition.testCase.id}" in '
            '${existing.assetPath} and $path',
          );
        }
        parsedById[definition.testCase.id] = definition;
      }
    }

    if (selectionWithExpandedProfiles.exactIds.isNotEmpty) {
      selectedById.addAll(
        _applyExactIdSelection(
          parsedById,
          selectionWithExpandedProfiles.exactIds,
        ),
      );
    } else {
      selectedById.addAll(parsedById);
    }

    if (selectedById.isEmpty) {
      throw EnsembleTestFailure(
        'No tests remained after applying selection '
        '(check device matrix vs --id/--path filters)',
      );
    }

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

  /// Parses one test asset into fully expanded definitions.
  static Future<List<EnsembleTestDefinition>> parseDefinitionsForTest(
    String path,
    String content, {
    Map<String, dynamic> inputs = const {},
    List<TestServiceConfig> services = const [],
    String? suiteDefaultProfile,
    List<String> suiteMockFiles = const [],
    Map<String, dynamic> suiteInlineMocks = const {},
    Map<String, dynamic> suiteInitialState = const {},
    Map<String, TestProfile> suiteProfiles = const {},
    Map<String, List<String>> suiteProfileGroups = const {},
    List<TestDeviceTarget> suiteDevices = const [],
    Future<String> Function(String assetPath)? assetLoader,
  }) {
    return _parseDefinitionsFromAsset(
      path,
      content,
      inputs: inputs,
      services: services,
      suiteDefaultProfile: suiteDefaultProfile,
      suiteMockFiles: suiteMockFiles,
      suiteInlineMocks: suiteInlineMocks,
      suiteInitialState: suiteInitialState,
      suiteProfiles: suiteProfiles,
      suiteProfileGroups: suiteProfileGroups,
      suiteDevices: suiteDevices,
      assetLoader: assetLoader ?? _rootBundleAssetLoader,
    );
  }

  static List<EnsembleTestDefinition> _previewDefinitionsFromAsset(
    String path,
    String content,
  ) {
    final dynamic doc = loadYaml(content);
    if (doc == null) return const [];
    if (doc is! YamlMap) {
      throw EnsembleTestFailure(
        'Invalid test file ($path): root must be a map',
      );
    }

    final id = doc['id']?.toString();
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('Each test must have an "id"');
    }

    final feature = doc['feature']?.toString();
    final tags = _yamlStringList(doc['tags']);
    final sessionValue = doc['session']?.toString();
    final session =
        sessionValue == null || sessionValue.isEmpty ? null : sessionValue;
    final scenarios = doc['scenarios'];
    if (scenarios is YamlList && scenarios.isNotEmpty) {
      return [
        for (final entry in scenarios)
          if (entry is YamlMap)
            EnsembleTestDefinition(
              assetPath: path,
              testCase: EnsembleTestCase(
                id: '$id[${entry['id']}]',
                sourcePath: path,
                feature: feature,
                tags: tags,
                session: session,
                steps: const [],
              ),
            ),
      ];
    }

    return [
      EnsembleTestDefinition(
        assetPath: path,
        testCase: EnsembleTestCase(
          id: id,
          sourcePath: path,
          feature: feature,
          tags: tags,
          session: session,
          steps: const [],
        ),
      ),
    ];
  }

  static List<String> _yamlStringList(dynamic node) {
    if (node is! YamlList) return const [];
    return node
        .map((item) => item?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static Future<List<EnsembleTestDefinition>> _parseDefinitionsFromAsset(
    String path,
    String content, {
    required Map<String, dynamic> inputs,
    List<TestServiceConfig> services = const [],
    String? suiteDefaultProfile,
    List<String> suiteMockFiles = const [],
    Map<String, dynamic> suiteInlineMocks = const {},
    Map<String, dynamic> suiteInitialState = const {},
    Map<String, TestProfile> suiteProfiles = const {},
    Map<String, List<String>> suiteProfileGroups = const {},
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
    final definitions = <EnsembleTestDefinition>[];
    if (base.scenarios.isEmpty) {
      final profileSelections = _profileSelectionsFor(
        base,
        suiteDefaultProfile: suiteDefaultProfile,
        profiles: suiteProfiles,
        profileGroups: suiteProfileGroups,
      );
      final multiProfile = profileSelections.length > 1;
      for (final selection in profileSelections) {
        final profile = selection.profile;
        final id = multiProfile ? '${base.id}[${selection.name}]' : base.id;
        final mocks = await _mergedMocksFor(
          assetPath: path,
          suiteMockFiles: _mergedProfileMockFiles(suiteMockFiles, profile),
          suiteInlineMocks: _mergedProfileInlineMocks(
            suiteInlineMocks,
            profile,
          ),
          mockFiles: base.mockFiles,
          inlineMocks: base.inlineMocks,
          assetLoader: assetLoader,
        );
        final steps = await _resolveStepMocks(
          assetPath: path,
          steps: base.steps,
          assetLoader: assetLoader,
        );
        definitions.add(
          EnsembleTestDefinition(
            assetPath: path,
            testCase: _withRuntimeFields(
              base,
              id: id,
              startScreen: base.startScreen,
              session: multiProfile && base.session != null
                  ? '${base.session}[${selection.name}]'
                  : base.session,
              profile: selection.name,
              mocks: mocks,
              steps: steps,
              initialState: mergedInitialState(
                _mergedProfileInitialState(suiteInitialState, profile),
                base.initialState,
              ),
            ),
          ),
        );
      }
    } else {
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
        final profileSelections = _profileSelectionsFor(
          parsed,
          suiteDefaultProfile: suiteDefaultProfile,
          profiles: suiteProfiles,
          profileGroups: suiteProfileGroups,
        );
        final multiProfile = profileSelections.length > 1;
        for (final selection in profileSelections) {
          final profile = selection.profile;
          final scenarioId = '${base.id}[${scenario.id}]';
          final id =
              multiProfile ? '$scenarioId[${selection.name}]' : scenarioId;
          final mocks = await _mergedMocksFor(
            assetPath: path,
            suiteMockFiles: _mergedProfileMockFiles(suiteMockFiles, profile),
            suiteInlineMocks: _mergedProfileInlineMocks(
              suiteInlineMocks,
              profile,
            ),
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
                session: multiProfile && parsed.session != null
                    ? '${parsed.session}[${selection.name}]'
                    : parsed.session,
                profile: selection.name,
                scenarioId: scenario.id,
                scenarioDescription: parsedScenario.description,
                mocks: mocks,
                steps: steps,
                initialState: mergedInitialState(
                  _mergedProfileInitialState(suiteInitialState, profile),
                  parsed.initialState,
                ),
              ),
            ),
          );
        }
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
              scenarioId: test.scenarioId,
              scenarioDescription: test.scenarioDescription,
              // One screenshot sheet per device run (not a shared multi-device
              // sheet). resolvedScreenshotSheetId falls back to the expanded id.
              screenshotSheetId: test.screenshotSheetId,
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
    String? profile,
    String? scenarioId,
    String? scenarioDescription,
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
      profile: profile ?? test.profile,
      profiles: test.profiles,
      scenarioId: scenarioId ?? test.scenarioId,
      scenarioDescription: scenarioDescription ?? test.scenarioDescription,
      mockFiles: test.mockFiles,
      inlineMocks: test.inlineMocks,
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

  static List<({String? name, TestProfile? profile})> _profileSelectionsFor(
    EnsembleTestCase test, {
    required String? suiteDefaultProfile,
    required Map<String, TestProfile> profiles,
    required Map<String, List<String>> profileGroups,
  }) {
    final names = _profileNamesFor(
      test,
      suiteDefaultProfile: suiteDefaultProfile,
      profileGroups: profileGroups,
    );
    if (names.isEmpty) {
      return const [(name: null, profile: null)];
    }

    final selections = <({String name, TestProfile profile})>[];
    for (final name in names) {
      final profile = profiles[name];
      if (profile == null) {
        throw EnsembleTestFailure(
          'Test "${test.id}" references unknown profile "$name". '
          'Define it under tests/config.yaml profiles.definitions.',
        );
      }
      selections.add((name: name, profile: profile));
    }
    return selections;
  }

  static List<String> _profileNamesFor(
    EnsembleTestCase test, {
    required String? suiteDefaultProfile,
    required Map<String, List<String>> profileGroups,
  }) {
    final selectors = test.profiles.isNotEmpty
        ? test.profiles
        : [if (suiteDefaultProfile != null) suiteDefaultProfile];
    return [
      for (final selector in selectors)
        if (profileGroups.containsKey(selector))
          ..._profilesForGroup(
            selector,
            profileGroups,
            testId: test.id,
          )
        else
          selector,
    ];
  }

  static List<String> _profilesForGroup(
    String group,
    Map<String, List<String>> profileGroups, {
    required String testId,
  }) {
    final profiles = profileGroups[group];
    if (profiles == null) {
      throw EnsembleTestFailure(
        'Test "$testId" references unknown profile group "$group". '
        'Define it under tests/config.yaml profiles.groups.',
      );
    }
    return profiles;
  }

  static List<String> _mergedProfileMockFiles(
    List<String> suiteMockFiles,
    TestProfile? profile,
  ) {
    if (profile == null) return suiteMockFiles;
    return [
      ...suiteMockFiles,
      ...profile.mockFiles,
    ];
  }

  static Map<String, dynamic> _mergedProfileInlineMocks(
    Map<String, dynamic> suiteInlineMocks,
    TestProfile? profile,
  ) {
    if (profile == null || profile.inlineMocks.isEmpty) {
      return suiteInlineMocks;
    }
    return {
      ...suiteInlineMocks,
      ...profile.inlineMocks,
    };
  }

  static Map<String, dynamic> _mergedProfileInitialState(
    Map<String, dynamic> suiteInitialState,
    TestProfile? profile,
  ) {
    if (profile == null) return suiteInitialState;
    return mergedInitialState(suiteInitialState, profile.initialState);
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
        resolveAssetPath: _resolveMockAssetPath,
      );
      MockComposition.mergeApiMaps(
        into,
        resolved,
        sourceLabel: _resolveMockAssetPath(fromAssetPath, mockFilePath),
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
        resolveAssetPath: _resolveMockAssetPath,
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
      incoming[entry.key.toString()] =
          MockComposition.deepCopy(entry.value) as Map<String, dynamic>;
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

  static String _resolveMockAssetPath(
    String fromAssetPath,
    String relativePath,
  ) {
    if (relativePath.startsWith('/')) return relativePath.substring(1);
    final normalized = _normalizeRelativePath(relativePath);
    if (normalized.startsWith('mocks/')) {
      final testsRoot = _testsRootForAsset(fromAssetPath);
      if (testsRoot != null) {
        return _resolveAssetPath('$testsRoot/config.yaml', normalized);
      }
    }
    return _resolveAssetPath(fromAssetPath, relativePath);
  }

  static String _normalizeRelativePath(String path) {
    final segments = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else {
        segments.add(part);
      }
    }
    return segments.join('/');
  }

  static String? _testsRootForAsset(String assetPath) {
    const marker = '/tests/';
    final markerIndex = assetPath.indexOf(marker);
    if (markerIndex == -1) return null;
    return assetPath.substring(0, markerIndex + marker.length - 1);
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

  static bool _idBelongsToSelection(String testId, Set<String> selectedIds) {
    if (selectedIds.contains(testId)) return true;
    for (final selectedId in selectedIds) {
      // Preview selection uses base ids / scenario ids; full parse may expand
      // them with a device suffix (e.g. home → home[android_nl]).
      if (testId.startsWith('$selectedId[')) return true;
    }
    return false;
  }

  static bool _matchesSelection(
    EnsembleTestDefinition def,
    EnsembleTestSelection selection,
  ) {
    final test = def.testCase;
    final idMatches = selection.ids.isNotEmpty &&
        selection.ids.any(
          (id) =>
              test.id == id ||
              test.id.startsWith('$id[') ||
              id.startsWith('${test.id}['),
        );
    final featureMatches = selection.features.isNotEmpty &&
        selection.features.contains(test.feature);
    final profileMatches = selection.profiles.isNotEmpty &&
        _matchesProfileSelection(test, selection);
    final tagMatches = selection.tags.isNotEmpty &&
        test.tags.any((tag) => selection.tags.contains(tag));
    final pathMatches = selection.paths.isNotEmpty &&
        selection.paths.any((path) => def.assetPath.contains(path));
    return idMatches ||
        featureMatches ||
        profileMatches ||
        tagMatches ||
        pathMatches;
  }

  static bool _matchesProfileSelection(
    EnsembleTestCase test,
    EnsembleTestSelection selection,
  ) {
    if (selection.profiles.isEmpty) return true;
    final profile = test.profile;
    if (profile != null && selection.profiles.contains(profile)) return true;
    return test.profiles.any((profile) => selection.profiles.contains(profile));
  }

  static EnsembleTestSelection _expandProfileGroupSelection(
    EnsembleTestSelection selection,
    Map<String, List<String>> profileGroups,
  ) {
    if (selection.profiles.isEmpty || profileGroups.isEmpty) return selection;
    final expanded = <String>{};
    for (final profile in selection.profiles) {
      expanded.add(profile);
      final group = profileGroups[profile];
      if (group != null) expanded.addAll(group);
    }
    return EnsembleTestSelection(
      ids: selection.ids,
      features: selection.features,
      profiles: expanded,
      tags: selection.tags,
      paths: selection.paths,
      exactIds: selection.exactIds,
    );
  }

  static Map<String, EnsembleTestDefinition> _applyExactIdSelection(
    Map<String, EnsembleTestDefinition> byId,
    Set<String> exactIds,
  ) {
    final selectedIds = <String>{};

    void includeWithDependencies(String id) {
      final definition = byId[id];
      if (definition == null) {
        throw EnsembleTestFailure('Selected test "$id" was not found.');
      }
      if (!selectedIds.add(id)) return;
      final session = definition.testCase.session;
      if (session != null) includeWithDependencies(session);
    }

    for (final id in exactIds) {
      includeWithDependencies(id);
    }

    return {
      for (final id in byId.keys)
        if (selectedIds.contains(id)) id: byId[id]!,
    };
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
