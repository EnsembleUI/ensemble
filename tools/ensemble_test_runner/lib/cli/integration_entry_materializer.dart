import 'package:ensemble_test_runner/cli/file_mutation_journal.dart';
import 'package:ensemble_test_runner/cli/integration_entry_generator.dart';
import 'package:ensemble_test_runner/cli/test_entry_validator.dart';
import 'package:path/path.dart' as p;

/// Materializes a generated integration entry and records its file mutations.
///
/// The patcher owns the journal lifetime and cleanup policy; this boundary
/// owns only the temporary integration directory and generated file write.
final class IntegrationEntryMaterializer {
  const IntegrationEntryMaterializer._();

  /// Plans and validates the generated path before the patcher starts writing.
  static PreparedIntegrationEntry? prepare({
    required String appDir,
    required String sourceRelativePath,
    required String source,
    required String Function() packageName,
    required bool sourceHasApplicationEntry,
  }) {
    final generated = IntegrationEntryGenerator.generate(
      sourceRelativePath: sourceRelativePath,
      source: source,
      packageName: packageName,
      sourceHasApplicationEntry: sourceHasApplicationEntry,
    );
    if (generated == null) return null;

    TestEntryValidator.validatePathWithinRoot(
      root: appDir,
      relativePath: generated.relativePath,
    );
    return PreparedIntegrationEntry(generated);
  }

  /// Writes a prevalidated entry and registers it with the patch transaction.
  static MaterializedIntegrationEntry? materialize({
    required PreparedIntegrationEntry? prepared,
    required String appDir,
    required FileMutationJournal mutations,
  }) {
    final generated = prepared?.generated;
    if (generated == null) return null;
    final destination = p.join(appDir, generated.relativePath);
    mutations.createDirectory(p.dirname(destination));
    mutations.write(destination, generated.contents, optional: true);
    return MaterializedIntegrationEntry(
      relativePath: generated.relativePath,
    );
  }
}

final class PreparedIntegrationEntry {
  const PreparedIntegrationEntry(this.generated);

  final GeneratedIntegrationEntry generated;
}

final class MaterializedIntegrationEntry {
  const MaterializedIntegrationEntry({
    required this.relativePath,
  });

  final String relativePath;
}
