import 'package:path/path.dart' as p;

import 'entry_source_transformer.dart';
import 'test_entry_generator.dart';

/// Builds a temporary integration entry while leaving its source entry intact.
/// Callers own backup, writing, and cleanup of the generated file.
final class IntegrationEntryGenerator {
  const IntegrationEntryGenerator._();

  /// Returns `null` when the configured entry already is a valid integration
  /// entry in `integration_test/` and needs no generated wrapper.
  static GeneratedIntegrationEntry? generate({
    required String sourceRelativePath,
    required String source,
    required String Function() packageName,
    required bool sourceHasApplicationEntry,
  }) {
    final sourcePath = sourceRelativePath.replaceAll('\\', '/');
    final alreadyInIntegrationDirectory =
        p.posix.split(p.posix.normalize(sourcePath)).first ==
            'integration_test';
    if (alreadyInIntegrationDirectory && sourceHasApplicationEntry) {
      return null;
    }

    final destinationPath = alreadyInIntegrationDirectory
        ? EntrySourceTransformer.applicationIntegrationAdapterRelativePath(
            sourcePath,
          )
        : p.posix.join('integration_test', p.posix.basename(sourcePath));
    final contents = sourceHasApplicationEntry && !alreadyInIntegrationDirectory
        ? EntrySourceTransformer.applicationIntegrationWrapperContents(
            sourcePath,
          )
        : _adapt(source, sourcePath, destinationPath, packageName());
    return GeneratedIntegrationEntry(
      relativePath: destinationPath,
      contents: contents,
    );
  }

  static String _adapt(
    String source,
    String sourcePath,
    String destinationPath,
    String packageName,
  ) {
    final relocated = EntrySourceTransformer.relocateDartImports(
      source: source,
      fromRelative: sourcePath,
      toRelative: destinationPath,
    );
    return TestEntryGenerator.adaptIntegrationEntry(relocated, packageName);
  }
}

final class GeneratedIntegrationEntry {
  const GeneratedIntegrationEntry({
    required this.relativePath,
    required this.contents,
  });

  final String relativePath;
  final String contents;
}
