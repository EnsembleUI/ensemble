import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:yaml/yaml.dart';

import 'entry_source_transformer.dart';
import 'test_app_entry_templates.dart';

/// Produces the source for runner-owned entry files without touching disk.
///
/// [TestAppPatcher] remains responsible for deciding whether a file is owned,
/// backing it up, writing it, and restoring it after the run.
final class TestEntryGenerator {
  const TestEntryGenerator._();

  /// Reads a package name from the pubspec text already loaded by the patcher.
  static String packageNameFromPubspec(String content) {
    final dynamic document = loadYaml(content);
    if (document is! YamlMap || document['name'] is! String) {
      throw StateError('Could not read package name from pubspec.yaml');
    }
    return document['name'] as String;
  }

  static String generate({
    required ExecutionMode mode,
    required String packageName,
    String? widgetEntrySource,
  }) {
    if (mode != ExecutionMode.integration) {
      return TestAppEntryTemplates.testEntryContentsFor(packageName);
    }

    if (widgetEntrySource != null) {
      return adaptIntegrationEntry(widgetEntrySource, packageName);
    }

    return TestAppEntryTemplates.integrationTestEntryContentsFor(packageName);
  }

  /// Adapts an entry or returns the default integration entry when it has no
  /// supported test-runner entry point.
  static String adaptIntegrationEntry(String source, String packageName) {
    final adapted = EntrySourceTransformer.adaptEntryForIntegration(source);
    return adapted ??
        TestAppEntryTemplates.integrationTestEntryContentsFor(packageName);
  }
}
