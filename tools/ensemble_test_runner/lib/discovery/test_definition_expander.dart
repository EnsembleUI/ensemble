import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:yaml/yaml.dart';

import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/discovery/asset_string_loader.dart';
import 'package:ensemble_test_runner/discovery/test_mock_resolver.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';

/// Expands parsed test documents into runnable definitions.
///
/// This boundary owns profile, scenario, mock, initial-state, and device
/// expansion. Planning and graph ordering stay in [EnsembleTestExecutionPlanner].
class TestDefinitionExpander {
  static Future<List<EnsembleTestDefinition>> parse(
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
    AssetStringLoader assetLoader = _unavailableAssetLoader,
    dynamic parsedDocument,
  }) async {
    return await RunnerBenchmark.async('planner', 'parseDefinitionsFromAsset',
        () async {
      final resolvedContent = _resolveServicePlaceholders(content, services);
      final canReuseDocument =
          parsedDocument != null && resolvedContent == content;
      final decodedDocument =
          canReuseDocument ? parsedDocument : loadYaml(resolvedContent);
      if (decodedDocument == null) {
        return const [];
      }

      final base = EnsembleTestParser.parseDecodedDocument(
        decodedDocument,
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
          final mocks = await TestMockResolver.mergedMocksFor(
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
          final steps = await TestMockResolver.resolveStepMocks(
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
          // Selection already decoded this document to inspect its metadata.
          // Reuse that immutable YAML tree while expanding scenarios so a
          // selected file is decoded once regardless of its scenario count.
          final parsed = EnsembleTestParser.parseDecodedDocument(
            decodedDocument,
            sourcePath: path,
            inputs: inputs,
            scenario: scenario.vars,
            scenarioId: scenario.id,
            parsedScenarios: base.scenarios,
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
            final mocks = await TestMockResolver.mergedMocksFor(
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
            final steps = await TestMockResolver.resolveStepMocks(
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
    });
  }

  /// Expands each definition once per suite `devices` entry.
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
  /// `storage`, `secureStorage`, `keychain`, and `env`.
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
    for (final key in const ['storage', 'secureStorage', 'keychain', 'env']) {
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

  static Future<String> _unavailableAssetLoader(String assetPath) {
    throw AssetLoadException(assetPath);
  }
}
