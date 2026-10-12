// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/cli/test_entry_validator.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Prepares app-owned dependencies and asset declarations for a test run.
///
/// This keeps pubspec parsing and rewriting out of [TestAppPatcher], whose
/// responsibility is to coordinate temporary file mutations and restoration.
class AppDependencyConfigurator {
  AppDependencyConfigurator({
    required this.appDir,
    String? testsDirRelative,
  }) : _explicitTestsDir = testsDirRelative {
    if (testsDirRelative != null) {
      TestEntryValidator.validateRelativePath(testsDirRelative);
    }
  }

  final String appDir;
  final String? _explicitTestsDir;
  var _testsDirResolved = false;
  String? _resolvedTestsDir;
  var _testAssetsResolved = false;
  List<String>? _resolvedTestAssetLines;

  String? get testsDirRelative {
    if (!_testsDirResolved) {
      _resolvedTestsDir = _resolveTestsDirRelative();
      _testsDirResolved = true;
    }
    final resolved = _resolvedTestsDir;
    if (resolved != null) {
      // The configured path is stable for the run, but its filesystem target
      // may change. Recheck symlinks before every read or write boundary.
      TestEntryValidator.validatePathWithinRoot(
        root: appDir,
        relativePath: resolved,
      );
    }
    return resolved;
  }

  String? _resolveTestsDirRelative() {
    final explicit = _explicitTestsDir;
    if (explicit != null) {
      final normalized = p.split(p.normalize(explicit)).join('/');
      TestEntryValidator.validatePathWithinRoot(
        root: appDir,
        relativePath: normalized,
      );
      return normalized;
    }

    final configFile = File(p.join(appDir, 'ensemble', 'ensemble-config.yaml'));
    if (!configFile.existsSync()) return null;

    final dynamic config = loadYaml(configFile.readAsStringSync());
    if (config is! YamlMap) return null;
    final definitions = config['definitions'];
    if (definitions is! YamlMap) return null;
    final local = definitions['local'];
    if (local is! YamlMap) return null;

    final appPath = local['path']?.toString();
    if (appPath == null || appPath.isEmpty) return null;
    final testsPath = p.posix.join(_withoutTrailingSlash(appPath), 'tests');
    TestEntryValidator.validatePathWithinRoot(
      root: appDir,
      relativePath: testsPath,
    );
    return testsPath;
  }

  bool get hasTestsOnDisk {
    final testsDir = testsDirRelative;
    if (testsDir == null) return false;
    return _testAssetLines(testsDir) != null;
  }

  String activate(String content, {required ExecutionMode mode}) {
    var updated = content;
    final testsDir = testsDirRelative;
    if (testsDir != null) {
      final testAssetLines = _testAssetLines(testsDir);
      if (testAssetLines != null) {
        updated = _activateTestAssets(updated, testsDir, testAssetLines);
      }
    }
    if (mode == ExecutionMode.integration) {
      updated = _activateIntegrationDependency(updated);
    }
    return updated;
  }

  /// Returns `null` when the directory has no test definition to activate.
  /// The same recursive scan serves the early availability check and collects
  /// asset folders, so patching does not walk the test tree twice.
  List<String>? _testAssetLines(String testsDirRelative) {
    if (_testAssetsResolved) return _resolvedTestAssetLines;

    final testsDir = Directory(p.join(appDir, testsDirRelative));
    final dirs = <String>{_withTrailingSlash(testsDirRelative)};
    var hasTests = false;
    if (testsDir.existsSync()) {
      for (final entity
          in testsDir.listSync(recursive: true, followLinks: false)) {
        if (entity.path.endsWith('.test.yaml')) hasTests = true;
        if (entity is! File) continue;
        final dir = p.dirname(p.relative(entity.path, from: appDir));
        dirs.add(_withTrailingSlash(p.split(dir).join('/')));
      }
    }
    if (!hasTests) return null;
    final sortedDirs = dirs.toList()
      ..sort((a, b) {
        final depthCompare = '/'.allMatches(a).length.compareTo(
              '/'.allMatches(b).length,
            );
        return depthCompare == 0 ? a.compareTo(b) : depthCompare;
      });
    _resolvedTestAssetLines = sortedDirs.map(assetLineFor).toList();
    _testAssetsResolved = true;
    return _resolvedTestAssetLines;
  }

  static String assetLineFor(String testsDirRelative) =>
      '    - ${_withTrailingSlash(testsDirRelative)}';

  static String _activateIntegrationDependency(String content) {
    if (RegExp(r'^\s{2}integration_test\s*:', multiLine: true)
        .hasMatch(content)) {
      return content;
    }
    const dependency = '  integration_test:\n    sdk: flutter\n';
    const marker = 'dev_dependencies:\n';
    if (content.contains(marker)) {
      return content.replaceFirst(marker, '$marker$dependency');
    }
    final flutterIndex = content.indexOf('\nflutter:');
    if (flutterIndex >= 0) {
      return '${content.substring(0, flutterIndex)}\n'
          'dev_dependencies:\n$dependency'
          '${content.substring(flutterIndex)}';
    }
    return '$content\ndev_dependencies:\n$dependency';
  }

  static String _activateTestAssets(
    String content,
    String testsDirRelative,
    List<String> testAssetLines,
  ) {
    final normalizedTestsDir = _withTrailingSlash(testsDirRelative);
    final testsAssetLine = assetLineFor(normalizedTestsDir);
    final missingLines = testAssetLines
        .where(
          (line) =>
              !content.contains(line) && !content.contains(line.trimLeft()),
        )
        .toList();
    if (missingLines.isEmpty) return content;
    final insertion = missingLines.join('\n');

    if (content.contains(testsAssetLine)) {
      return content.replaceFirst(
          testsAssetLine, '$testsAssetLine\n$insertion');
    }

    final localAppLine =
        '    - ${_withTrailingSlash(p.posix.dirname(_withoutTrailingSlash(normalizedTestsDir)))}\n';
    if (content.contains(localAppLine)) {
      return content.replaceFirst(localAppLine, '$localAppLine$insertion\n');
    }

    const ensembleDirLine = '    - ensemble/\n';
    if (content.contains(ensembleDirLine)) {
      return content.replaceFirst(
        ensembleDirLine,
        '$ensembleDirLine$insertion\n',
      );
    }

    const assetsMarker = '\n  assets:\n';
    if (content.contains(assetsMarker)) {
      return content.replaceFirst(assetsMarker, '$assetsMarker$insertion\n');
    }

    final emptyAssets =
        RegExp(r'^([ \t]*)assets:\s*\[\s*\]\s*$', multiLine: true);
    final emptyMatch = emptyAssets.firstMatch(content);
    if (emptyMatch != null) {
      final indent = emptyMatch.group(1) ?? '  ';
      final itemIndent = '$indent  ';
      final expanded = '$indent'
          'assets:\n'
          '${missingLines.map((line) => line.startsWith(itemIndent) ? line : '$itemIndent${line.trimLeft()}').join('\n')}\n';
      return content.replaceFirst(emptyMatch.group(0)!, expanded);
    }

    throw StateError(
      'Could not patch pubspec.yaml assets: add a flutter.assets section.',
    );
  }

  static String _withTrailingSlash(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  static String _withoutTrailingSlash(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}
