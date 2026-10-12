import 'package:ensemble_test_runner/mocks/mock_composition.dart';

import 'package:ensemble_test_runner/discovery/asset_string_loader.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';

/// Resolves suite, test, and step mock layers during plan construction.
///
/// Kept separate from the planner so dependency ordering and mock composition
/// remain independently testable and the planning facade stays small.
class TestMockResolver {
  static Future<List<TestStep>> resolveStepMocks({
    required String assetPath,
    required List<TestStep> steps,
    required AssetStringLoader assetLoader,
  }) async {
    final resolved = <TestStep>[];
    for (final step in steps) {
      final mocks = await _mocksForStep(
        assetPath: assetPath,
        step: step,
        assetLoader: assetLoader,
      );
      final nestedSteps = await resolveStepMocks(
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
    required AssetStringLoader assetLoader,
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
    return mergedMocksFor(
      assetPath: assetPath,
      mockFiles: parsed.files,
      inlineMocks: parsed.inline,
      assetLoader: assetLoader,
    );
  }

  static Future<TestMocks> mergedMocksFor({
    required String assetPath,
    List<String> suiteMockFiles = const [],
    Map<String, dynamic> suiteInlineMocks = const {},
    required List<String> mockFiles,
    required Map<String, dynamic> inlineMocks,
    required AssetStringLoader assetLoader,
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
    required AssetStringLoader assetLoader,
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
    } on AssetLoadException {
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
    required AssetStringLoader assetLoader,
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
}
