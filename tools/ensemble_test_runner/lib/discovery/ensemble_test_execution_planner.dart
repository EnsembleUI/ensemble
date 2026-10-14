import 'package:ensemble_test_runner/src/benchmark_measurement.dart';

import 'package:ensemble_test_runner/discovery/asset_string_loader.dart';
import 'package:ensemble_test_runner/discovery/execution_plan_graph.dart';
import 'package:ensemble_test_runner/discovery/test_definition_expander.dart';
import 'package:ensemble_test_runner/discovery/test_definition_preview.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:yaml/yaml.dart';

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
  /// Parses supplied test assets, expands definitions, validates dependencies,
  /// and returns the dependency-ordered suite plan.
  static Future<EnsembleTestExecutionPlan> buildForTest({
    required Map<String, String> assetContents,
    EnsembleTestConfig config = const EnsembleTestConfig(),
    EnsembleTestSelection selection = const EnsembleTestSelection(),
    Map<String, dynamic> inputs = const {},
    AssetStringLoader? assetLoader,
  }) {
    return buildFromAssets(
      assetContents: assetContents,
      config: config,
      selection: selection,
      inputs: inputs,
      assetLoader: assetLoader ?? _unavailableAssetLoader,
    );
  }

  /// Builds a plan from resolved assets supplied by a host process.
  ///
  /// The CLI uses this boundary to compile the same selected definitions
  /// before dispatching workers, while providing a filesystem-backed loader
  /// for referenced mock assets.
  static Future<EnsembleTestExecutionPlan> buildFromAssets({
    required Map<String, String> assetContents,
    EnsembleTestConfig config = const EnsembleTestConfig(),
    EnsembleTestSelection selection = const EnsembleTestSelection(),
    Map<String, dynamic> inputs = const {},
    AssetStringLoader? assetLoader,
    Map<String, dynamic>? decodedDocuments,
  }) {
    return _buildFromResolvedAssets(
      assetContents: assetContents,
      config: config,
      selection: selection,
      inputs: inputs,
      assetLoader: assetLoader ?? _unavailableAssetLoader,
      decodedDocuments: decodedDocuments,
    );
  }

  static Future<EnsembleTestExecutionPlan> _buildFromResolvedAssets({
    required Map<String, String> assetContents,
    required EnsembleTestConfig config,
    required EnsembleTestSelection selection,
    required Map<String, dynamic> inputs,
    AssetStringLoader assetLoader = _unavailableAssetLoader,
    Map<String, dynamic>? decodedDocuments,
  }) async {
    return await RunnerBenchmark.async('planner', 'buildFromResolvedAssets',
        () async {
      final paths = assetContents.keys.toList()..sort();
      final selectionWithExpandedProfiles =
          ExecutionPlanGraph.expandProfileGroupSelection(
        selection,
        config.profileGroups,
      );

      // Decode each unchanged asset once at the planning boundary. The parser
      // can consume this immutable YAML tree directly, so the common
      // unfiltered suite path avoids a second document decode pass per file. Assets
      // containing service placeholders still fall back to parsing the
      // substituted source below.
      final decodedDocumentByPath = <String, dynamic>{};
      final parsedDocumentByPath = <String, YamlMap>{};
      for (final path in paths) {
        final decoded =
            decodedDocuments != null && decodedDocuments.containsKey(path)
                ? decodedDocuments[path]
                : loadYaml(assetContents[path]!);
        if (decodedDocuments == null || !decodedDocuments.containsKey(path)) {
          RunnerBenchmark.count('documentsDecoded', 1);
        }
        decodedDocumentByPath[path] = decoded;
        if (decoded is YamlMap) {
          parsedDocumentByPath[path] = decoded;
        }
      }

      if (selectionWithExpandedProfiles.isEmpty) {
        final byId = <String, EnsembleTestDefinition>{};
        for (final path in paths) {
          final content = assetContents[path]!;
          final definitions = await parseDefinitionsForTest(
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
            parsedDocument: parsedDocumentByPath[path],
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

        final ordered = ExecutionPlanGraph.topologicalSort(byId);
        return EnsembleTestExecutionPlan(ordered: ordered, config: config);
      }

      final previewById = <String, EnsembleTestDefinition>{};
      for (final path in paths) {
        final previews = TestDefinitionPreview.fromDocument(
          path,
          decodedDocumentByPath[path],
        );
        final definitions = previews
            .map((preview) => EnsembleTestDefinition(
                  assetPath: preview.assetPath,
                  testCase: preview.testCase,
                ))
            .toList(growable: false);
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
          : ExecutionPlanGraph.applySelection(previewById, previewSelection);

      final selectedAssetPaths = selectedPreviewById.values
          .map((definition) => definition.assetPath)
          .toSet();
      final selectedIds = selectedPreviewById.keys.toSet();
      final parsedById = <String, EnsembleTestDefinition>{};
      final selectedById = <String, EnsembleTestDefinition>{};
      for (final path in selectedAssetPaths) {
        final content = assetContents[path]!;
        final definitions = await parseDefinitionsForTest(
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
          parsedDocument: parsedDocumentByPath[path],
        );
        for (final definition in definitions) {
          if (selectionWithExpandedProfiles.exactIds.isEmpty &&
              !ExecutionPlanGraph.idBelongsToSelection(
                  definition.testCase.id, selectedIds)) {
            continue;
          }
          if (!ExecutionPlanGraph.matchesProfileSelection(
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
          ExecutionPlanGraph.applyExactIdSelection(
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

      final ordered = ExecutionPlanGraph.topologicalSort(selectedById);
      return EnsembleTestExecutionPlan(ordered: ordered, config: config);
    });
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
    AssetStringLoader? assetLoader,
    YamlMap? parsedDocument,
  }) {
    return TestDefinitionExpander.parse(
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
      assetLoader: assetLoader ?? _unavailableAssetLoader,
      parsedDocument: parsedDocument,
    );
  }

  static Future<String> _unavailableAssetLoader(String assetPath) {
    throw AssetLoadException(assetPath);
  }

  /// Expands each definition once per suite [devices] entry.
  static List<EnsembleTestDefinition> expandDeviceMatrix(
    List<EnsembleTestDefinition> definitions,
    List<TestDeviceTarget> devices,
  ) =>
      TestDefinitionExpander.expandDeviceMatrix(definitions, devices);

  /// Suite state is the base; test values override values by section.
  static Map<String, dynamic> mergedInitialState(
    Map<String, dynamic> suite,
    Map<String, dynamic> test,
  ) =>
      TestDefinitionExpander.mergedInitialState(suite, test);

  /// Exposed for unit tests only.
  static List<String> orderIdsForTest(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    return ExecutionPlanGraph.topologicalSort(byId)
        .map((d) => d.testCase.id)
        .toList();
  }

  static List<String> selectAndOrderIdsForTest(
    Map<String, EnsembleTestDefinition> byId,
    EnsembleTestSelection selection,
  ) {
    return ExecutionPlanGraph.topologicalSort(
            ExecutionPlanGraph.applySelection(byId, selection))
        .map((d) => d.testCase.id)
        .toList();
  }
}
