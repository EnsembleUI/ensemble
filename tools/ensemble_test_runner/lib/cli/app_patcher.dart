import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/cli/file_mutation_journal.dart';
import 'package:ensemble_test_runner/cli/app_platform_support.dart';
import 'package:ensemble_test_runner/cli/app_dependency_configurator.dart';
import 'package:ensemble_test_runner/cli/integration_entry_materializer.dart';
import 'package:ensemble_test_runner/cli/test_entry_generator.dart';
import 'package:ensemble_test_runner/cli/test_entry_validator.dart';
import 'package:path/path.dart' as p;

/// Temporarily wires [appDir] to run declarative tests, then restores files.
class TestAppPatcher {
  TestAppPatcher(
    String appDir, {
    String? testsDirRelative,
    String? testEntryRelativePath,
  })  : appDir = p.normalize(p.absolute(appDir)),
        _explicitTestEntry = testEntryRelativePath {
    _dependencyConfigurator = AppDependencyConfigurator(
      appDir: this.appDir,
      testsDirRelative: testsDirRelative,
    );
    if (testEntryRelativePath != null) {
      TestEntryValidator.validateRelativePath(testEntryRelativePath);
    }
  }

  final String appDir;
  late final AppDependencyConfigurator _dependencyConfigurator;
  final String? _explicitTestEntry;

  bool get usesApplicationEntry => _explicitTestEntry != null;

  static const testEntryRelativePath = 'test/ensemble_tests.dart';
  static const integrationTestEntryRelativePath =
      'integration_test/ensemble_tests.dart';

  final FileMutationJournal _mutations = FileMutationJournal();
  bool _enabled = false;
  ExecutionMode _mode = ExecutionMode.widget;
  String? _generatedIntegrationEntryRelativePath;

  bool get pubspecChanged => _mutations.contains(_pubspecPath);

  late final AppPlatformSupport _platformSupport = AppPlatformSupport(
    appDir: appDir,
    rewriteIfChanged: _rewriteIfChanged,
  );

  String? get testsDirRelative => _dependencyConfigurator.testsDirRelative;

  String? get testsDirPath {
    final relative = testsDirRelative;
    if (relative == null) return null;
    return p.join(appDir, relative);
  }

  bool get hasTestsOnDisk => _dependencyConfigurator.hasTestsOnDisk;

  String get _pubspecPath => p.join(appDir, 'pubspec.yaml');

  /// User-owned or generated entry on disk. Never the temporary integration
  /// adapter written beside a widget-mode host file.
  String get configuredEntryRelativePath =>
      _explicitTestEntry ??
      (_mode == ExecutionMode.integration
          ? integrationTestEntryRelativePath
          : testEntryRelativePath);

  /// Path passed to `flutter test`. Host widget entries in integration mode
  /// run from a generated file under `integration_test/` so Flutter wires the
  /// native plugin.
  String get activeEntryRelativePath =>
      _generatedIntegrationEntryRelativePath ?? configuredEntryRelativePath;

  String get _testEntryPath => p.join(appDir, configuredEntryRelativePath);
  String get _testDirPath => p.dirname(_testEntryPath);

  /// Temporarily wires the app for declarative tests.
  ///
  /// Validates prerequisites before mutating files. On any failure, every
  /// touched file is restored and created files are deleted — even when
  /// [enable] never reached the success path.
  ///
  /// [targetPlatform] is the selected device platform (`ios` / `android`).
  /// iOS deployment require/fix runs only for integration mode when this is
  /// `'ios'`. Null (widget mode / no device) skips the iOS gate.
  void enable({
    ExecutionMode mode = ExecutionMode.widget,
    String? targetPlatform,
    bool fixIosDeploymentTarget = false,
  }) {
    if (_enabled) return;
    _mode = mode;

    try {
      final existingEntrySource = TestEntryValidator.validateForPatching(
        appDir: appDir,
        entry: File(_testEntryPath),
        usesApplicationEntry: usesApplicationEntry,
        mode: mode,
        configuredPath: configuredEntryRelativePath,
        activePath: activeEntryRelativePath,
      );

      // Integration generation may adapt the widget entry when there is no
      // configured integration entry. Validate and read this optional source
      // during preflight, before dependency configuration mutates the pubspec.
      final widgetEntrySource = !usesApplicationEntry &&
              mode == ExecutionMode.integration &&
              existingEntrySource == null
          ? TestEntryValidator.readOptionalEntrySource(
              appDir: appDir,
              relativePath: testEntryRelativePath,
            )
          : null;

      final pubspec = File(_pubspecPath).readAsStringSync();
      if (!usesApplicationEntry && existingEntrySource == null) {
        _mutations.captureValidatedContents(
          _testEntryPath,
          null,
        );
      }

      // The pubspec source is already in memory for dependency activation.
      // Reuse it when generating an entry instead of reopening the same file.
      String? resolvedPackageName;
      String packageName() => resolvedPackageName ??=
          TestEntryGenerator.packageNameFromPubspec(pubspec);
      final preparedIntegrationEntry =
          usesApplicationEntry && mode == ExecutionMode.integration
              ? IntegrationEntryMaterializer.prepare(
                  appDir: appDir,
                  sourceRelativePath: configuredEntryRelativePath,
                  source: existingEntrySource!,
                  packageName: packageName,
                  sourceHasApplicationEntry: true,
                )
              : null;
      final activated = _dependencyConfigurator.activate(pubspec, mode: mode);
      if (activated != pubspec) {
        _mutations.writeValidated(
          _pubspecPath,
          activated,
          originalContents: pubspec,
        );
      }

      if (!usesApplicationEntry) {
        final testEntryExisted = existingEntrySource != null;

        if (!testEntryExisted) {
          _mutations.createDirectory(_testDirPath);
          _mutations.writeValidated(
            _testEntryPath,
            TestEntryGenerator.generate(
              mode: mode,
              packageName: packageName(),
              widgetEntrySource: mode == ExecutionMode.widget
                  ? existingEntrySource
                  : widgetEntrySource,
            ),
            originalContents: null,
          );
        }
      } else if (mode == ExecutionMode.integration) {
        _materializeApplicationIntegrationEntry(preparedIntegrationEntry);
      }

      _platformSupport.prepareForTestRun(
        mode: mode,
        targetPlatform: targetPlatform,
        fixIosDeploymentTarget: fixIosDeploymentTarget,
      );

      _enabled = true;
    } catch (_) {
      _rollbackMutations();
      rethrow;
    }
  }

  /// Restores every file touched by a successful [enable].
  void restore() {
    return RunnerBenchmark.sync('cli', 'restore', () {
      if (!_enabled) return;
      _rollbackMutations();
    });
  }

  /// Rolls back backups and deletes created files regardless of [_enabled].
  void _rollbackMutations() {
    final restoreEntry =
        !usesApplicationEntry && _mutations.contains(_testEntryPath);
    _mutations.restoreAll([
      if (restoreEntry) _testEntryPath,
      _pubspecPath,
    ]);
    _enabled = false;
    _mode = ExecutionMode.widget;
    _generatedIntegrationEntryRelativePath = null;
  }

  /// Writes an `integration_test/` entry so Flutter detects the native plugin.
  ///
  /// The user-owned `--test-entry` is never rewritten. Host entries that call
  /// [runApplicationTests] (which selects the binding from the CLI
  /// dart-define) get a thin wrapper. Older entries that only call
  /// The declarative entry is adapted the same way.
  void _materializeApplicationIntegrationEntry(
    PreparedIntegrationEntry? prepared,
  ) {
    final materialized = IntegrationEntryMaterializer.materialize(
      appDir: appDir,
      prepared: prepared,
      mutations: _mutations,
    );
    if (materialized == null) return;
    _generatedIntegrationEntryRelativePath = materialized.relativePath;
  }

  void _rewriteIfChanged(File file, String Function(String content) rewrite) {
    TestEntryValidator.validatePathWithinRoot(
      root: appDir,
      relativePath: p.relative(file.path, from: appDir),
    );
    _mutations.rewriteIfChanged(file, rewrite);
  }
}
