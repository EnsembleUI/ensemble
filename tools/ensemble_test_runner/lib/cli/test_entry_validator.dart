import 'dart:io';

import 'package:ensemble_test_runner/cli/entry_source_transformer.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:path/path.dart' as p;

/// Validates a configured test entry before [TestAppPatcher] mutates files.
///
/// The validator is deliberately side-effect free: it only reads the entry and
/// returns its source so the patcher can reuse that read during generation.
final class TestEntryValidator {
  const TestEntryValidator._();

  static void validateRelativePath(String value) {
    final normalized = p.normalize(value);
    if (value.trim().isEmpty ||
        p.isAbsolute(value) ||
        normalized == '..' ||
        normalized.startsWith('${p.separator}..${p.separator}') ||
        normalized.startsWith('..${p.separator}')) {
      throw StateError('Path must remain inside the application: $value');
    }
  }

  /// Reads an optional entry only after its application-relative path has
  /// passed the same symlink confinement check as configured entries.
  static String? readOptionalEntrySource({
    required String appDir,
    required String relativePath,
  }) {
    validatePathWithinRoot(root: appDir, relativePath: relativePath);
    final entry = File(p.join(appDir, relativePath));
    return entry.existsSync() ? entry.readAsStringSync() : null;
  }

  /// Rejects application-relative paths that escape through an existing
  /// symbolic link. Lexical `..` checks alone do not protect a write such as
  /// `integration_test/entry.dart` when `integration_test` points elsewhere.
  static void validatePathWithinRoot({
    required String root,
    required String relativePath,
  }) {
    validateRelativePath(relativePath);
    final rootPath = Directory(root).resolveSymbolicLinksSync();
    var current = rootPath;
    for (final component in p.split(p.normalize(relativePath))) {
      if (component.isEmpty || component == p.current) continue;
      current = p.join(current, component);
      final type = FileSystemEntity.typeSync(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        try {
          current = Link(current).resolveSymbolicLinksSync();
        } on FileSystemException catch (error) {
          throw StateError(
            'Path contains an unresolved symbolic link: $relativePath '
            '(${error.message})',
          );
        }
      }
      final fromRoot = p.relative(current, from: rootPath);
      if (p.isAbsolute(fromRoot) ||
          fromRoot == '..' ||
          fromRoot.startsWith('..${p.separator}')) {
        throw StateError(
            'Path must remain inside the application: $relativePath');
      }
    }
  }

  static String? validate({
    required File entry,
    required bool usesApplicationEntry,
    required ExecutionMode mode,
    required String configuredPath,
    required String activePath,
  }) {
    if (!entry.existsSync()) {
      if (usesApplicationEntry) {
        throw StateError('Application test entry not found: $activePath');
      }
      return null;
    }

    final content = entry.readAsStringSync();
    final expectedCalls = switch ((usesApplicationEntry, mode)) {
      (true, ExecutionMode.integration) => [
          ...EntrySourceTransformer.applicationWidgetEntryPoints,
          ...EntrySourceTransformer.applicationIntegrationEntryPoints,
        ],
      (true, _) => EntrySourceTransformer.applicationWidgetEntryPoints,
      (false, ExecutionMode.integration) =>
        EntrySourceTransformer.ensembleIntegrationEntryPoints,
      _ => EntrySourceTransformer.ensembleWidgetEntryPoints,
    };
    if (EntrySourceTransformer.entryPointCallsAny(content, expectedCalls)) {
      return content;
    }

    final requiredCalls =
        usesApplicationEntry && mode == ExecutionMode.integration
            ? 'runApplicationTests() or runApplicationIntegrationTests()'
            : '${expectedCalls.first}()';
    throw StateError('$configuredPath must call $requiredCalls.');
  }

  /// Validates all source paths before the patcher starts its file transaction.
  ///
  /// Keeping this preflight as one operation ensures every caller applies the
  /// same root-boundary checks before reading an entry or mutating the pubspec.
  static String? validateForPatching({
    required String appDir,
    required File entry,
    required bool usesApplicationEntry,
    required ExecutionMode mode,
    required String configuredPath,
    required String activePath,
  }) {
    validatePathWithinRoot(root: appDir, relativePath: 'pubspec.yaml');
    validatePathWithinRoot(root: appDir, relativePath: configuredPath);
    return validate(
      entry: entry,
      usesApplicationEntry: usesApplicationEntry,
      mode: mode,
      configuredPath: configuredPath,
      activePath: activePath,
    );
  }
}
