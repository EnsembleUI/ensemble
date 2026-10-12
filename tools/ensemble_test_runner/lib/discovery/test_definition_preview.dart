import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:yaml/yaml.dart';

/// Extracts only the metadata needed to select tests before full parsing.
///
/// This boundary deliberately does not expand mocks, profiles, devices, or
/// steps. It lets the planner inspect a file once and defer expensive parsing
/// until the file has survived selection.
abstract final class TestDefinitionPreview {
  static List<EnsembleTestDefinitionPreview> fromDocument(
    String path,
    dynamic document,
  ) {
    if (document == null) return const [];
    if (document is! YamlMap) {
      throw EnsembleTestFailure(
        'Invalid test file ($path): root must be a map',
      );
    }

    final id = document['id']?.toString();
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('Each test must have an "id"');
    }

    final feature = document['feature']?.toString();
    final tags = _stringList(document['tags']);
    final sessionValue = document['session']?.toString();
    final session =
        sessionValue == null || sessionValue.isEmpty ? null : sessionValue;
    final scenarios = document['scenarios'];
    if (scenarios is YamlList && scenarios.isNotEmpty) {
      return [
        for (final entry in scenarios)
          if (entry is YamlMap)
            EnsembleTestDefinitionPreview(
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
      EnsembleTestDefinitionPreview(
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

  static List<String> _stringList(dynamic node) {
    if (node is! YamlList) return const [];
    return node
        .map((item) => item?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
  }
}

/// Lightweight preview used while filtering files before full parsing.
class EnsembleTestDefinitionPreview {
  final String assetPath;
  final EnsembleTestCase testCase;

  const EnsembleTestDefinitionPreview({
    required this.assetPath,
    required this.testCase,
  });
}
